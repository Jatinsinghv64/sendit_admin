import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../app_user.dart';
import '../inventory_model.dart';
import '../product.dart';
import '../category.dart';
import '../order.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // ==========================================
  // 1. AUTH & ROLES
  // ==========================================
  Stream<AdminUser?> getCurrentUserStream(String uid) {
    // This MUST return a Stream (using .snapshots()) to be real-time
    // UPDATED: Listen specifically to the 'staff' collection.
    // If a user exists in Auth but NOT in this collection, doc.exists will be false,
    // causing the app to deny access.
    return _db.collection('staff').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      // Triggers 'fromMap' every time data changes
      return AdminUser.fromMap(doc.data()!, doc.id);
    });
  }

  // ==========================================
  // 2. CATEGORIES
  // ==========================================
  Stream<List<Category>> getCategoriesStream() {
    return _db.collection('categories')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> saveCategory({
    required String name,
    File? imageFile,
    String? id,
    String? existingImageUrl,
    required int themeColor,
    List<SubCategory> subCategories = const [],
  }) async {
    String imageUrl = existingImageUrl ?? '';

    if (imageFile != null) {
      final ref = _storage.ref().child('categories/${_uuid.v4()}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    final data = {
      'name': name,
      'image': imageUrl,
      'isActive': true,
      'themeColor': themeColor,
      'subCategories': subCategories.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('categories').add(data);
    } else {
      await _db.collection('categories').doc(id).update(data);
    }
  }

  Future<void> updateCategoryStatus(String id, bool isActive) async {
    await _db.collection('categories').doc(id).update({'isActive': isActive});
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  // ==========================================
  // 3. PRODUCTS (Inventory)
  // ==========================================
  Future<List<ProductSummary>> getProductsPage({
    int limit = 500,
    DocumentSnapshot? lastDoc,
    String? searchQuery,
  }) async {
    Query query = _db.collection('products').where('isActive', isEqualTo: true);
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where('searchKeywords', arrayContains: searchQuery.toLowerCase());
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    QuerySnapshot snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) {
      return ProductSummary.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<Product?> getProductById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveProduct({required Product product, File? imageFile}) async {
    String thumbnailUrl = product.thumbnailUrl;
    if (imageFile != null) {
      final ref = _storage.ref().child('products/${_uuid.v4()}.jpg');
      await ref.putFile(imageFile);
      thumbnailUrl = await ref.getDownloadURL();
    }
    final keywords = _generateKeywords(product.name);
    final data = product.toMap();
    data['thumbnailUrl'] = thumbnailUrl;
    data['searchKeywords'] = keywords;
    data['isActive'] = true;
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (product.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('products').add(data);
    } else {
      await _db.collection('products').doc(product.id).update(data);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).update({'isActive': false});
  }

  // ==========================================
  // 4. ORDERS & TRANSACTIONS
  // ==========================================
  Stream<List<Order>> getOrdersStream({String statusFilter = 'all'}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);
    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }
    return query.limit(100).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Order.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> processPosTransaction({
    required List<Map<String, dynamic>> items,
    required String userId,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    final orderRef = _db.collection('orders').doc();
    await _db.runTransaction((transaction) async {
      List<DocumentSnapshot> productSnaps = [];
      for (var item in items) {
        productSnaps.add(await transaction.get(_db.collection('products').doc(item['productId'])));
      }
      for (int i = 0; i < productSnaps.length; i++) {
        if (!productSnaps[i].exists) throw Exception("Product not found");
        final data = productSnaps[i].data() as Map<String, dynamic>;
        int currentStock = 0;
        if (data.containsKey('totalStock')) {
          currentStock = (data['totalStock'] as num).toInt();
        } else if (data['stock'] != null && data['stock'] is Map) {
          currentStock = (data['stock']['availableQty'] as num).toInt();
        }
        final requestedQty = items[i]['quantity'] as int;
        if (currentStock < requestedQty) throw Exception("Insufficient stock");

        if (data.containsKey('totalStock')) {
          transaction.update(productSnaps[i].reference, {'totalStock': currentStock - requestedQty});
        } else {
          transaction.update(productSnaps[i].reference, {'stock.availableQty': currentStock - requestedQty});
        }
      }
      transaction.set(orderRef, {
        'id': orderRef.id,
        'userId': 'POS-WALKIN',
        'staffId': userId,
        'items': items,
        'total': totalAmount,
        'status': 'delivered',
        'source': 'pos',
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  List<String> _generateKeywords(String title) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < title.length; i++) {
      temp = temp + title[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }
}