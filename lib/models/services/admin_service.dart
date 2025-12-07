import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

// Imports
import '../app_user.dart';
import '../inventory_model.dart';
import '../product.dart';
import '../category.dart';
import '../order.dart' as app_model;

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // ==========================================
  // 1. AUTH & ROLES (RBAC) - UPDATED FOR 'STAFF' COLLECTION
  // ==========================================
  Stream<AdminUser?> getCurrentUserStream(String uid) {
    // UPDATED: Now points to 'staff' collection instead of 'users'
    return _db.collection('staff').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null; // Returns null if not a staff member
      return AdminUser.fromMap(doc.data()!, doc.id);
    });
  }

  // ==========================================
  // 2. CATEGORIES
  // ==========================================
  Stream<List<Category>> getCategories() {
    return _db.collection('categories')
        .orderBy('updatedAt', descending: true)
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
  }) async {
    String imageUrl = existingImageUrl ?? '';
    if (imageFile != null) {
      final ref = _storage.ref().child('categories/${_uuid.v4()}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    final data = {
      'name': name,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('categories').add(data);
    } else {
      await _db.collection('categories').doc(id).update(data);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  // ==========================================
  // 3. PRODUCTS (Scalable Pagination)
  // ==========================================

  Future<List<ProductSummary>> getProductsPage({
    int limit = 20,
    DocumentSnapshot? lastDoc,
    String? searchQuery,
  }) async {
    Query query = _db.collection('products').where('isActive', isEqualTo: true);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where('searchKeywords', arrayContains: searchQuery.toLowerCase());
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    QuerySnapshot snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => ProductSummary.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<Product?> getProductById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data()!, doc.id);
  }

  Future<ProductSummary?> getProductBySku(String sku) async {
    final snapshot = await _db.collection('products')
        .where('sku', isEqualTo: sku)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ProductSummary.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  Future<void> saveProduct({
    required Product product,
    File? imageFile,
  }) async {
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

    if (product.id.isEmpty) {
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
  Stream<List<app_model.Order>> getOrdersStream({String statusFilter = 'all'}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);

    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.limit(50).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => app_model.Order.fromMap(doc.data() as Map<String,dynamic>, doc.id)).toList();
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
        final currentStock = data['stock']?['availableQty'] ?? 0;
        final requestedQty = items[i]['quantity'] as int;

        if (currentStock < requestedQty) {
          throw Exception("Insufficient stock for ${data['name']}");
        }

        transaction.update(productSnaps[i].reference, {
          'stock.availableQty': currentStock - requestedQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final logRef = _db.collection('inventory_logs').doc();
        transaction.set(logRef, {
          'productId': productSnaps[i].id,
          'action': 'sale_pos',
          'change': -requestedQty,
          'staffId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(orderRef, {
        'orderId': orderRef.id,
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