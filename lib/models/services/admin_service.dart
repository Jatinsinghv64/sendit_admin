import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

// Imports
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
  // 1. AUTH & ROLES (RBAC)
  // ==========================================
  Stream<AdminUser?> getCurrentUserStream(String uid) {
    // Points to 'staff' collection for admin privileges
    return _db.collection('staff').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null; // Returns null if not a staff member
      return AdminUser.fromMap(doc.data()!, doc.id);
    });
  }

  // ==========================================
  // 2. CATEGORIES
  // ==========================================

  // Renamed to 'getCategoriesStream' to match the new UI code
  Stream<List<Category>> getCategoriesStream() {
    return _db.collection('categories')
    // Changed from 'updatedAt' to 'name' to ensure docs without timestamps still appear
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
  // 3. PRODUCTS (Inventory)
  // ==========================================

  // Returns ProductSummary for the Data Tables (lighter object)
  Future<List<ProductSummary>> getProductsPage({
    int limit = 500, // Default higher limit for admin view
    DocumentSnapshot? lastDoc,
    String? searchQuery,
  }) async {
    Query query = _db.collection('products').where('isActive', isEqualTo: true);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Requires 'searchKeywords' array in Firestore document
      query = query.where('searchKeywords', arrayContains: searchQuery.toLowerCase());
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    QuerySnapshot snapshot = await query.limit(limit).get();

    return snapshot.docs.map((doc) {
      return ProductSummary.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // Returns full Product details for Editing
  Future<Product?> getProductById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data()!, doc.id);
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

    // Generate keywords for search
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
    // Soft delete by setting isActive to false
    await _db.collection('products').doc(id).update({'isActive': false});
  }

  // ==========================================
  // 4. ORDERS & TRANSACTIONS
  // ==========================================

  Stream<List<Order>> getOrdersStream({String statusFilter = 'all'}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);

    if (statusFilter != 'all') {
      // Ensure status case matches DB (lowercase is safer)
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

  // Robust Transaction for POS to ensure stock isn't negative
  Future<void> processPosTransaction({
    required List<Map<String, dynamic>> items,
    required String userId,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      // 1. Pre-fetch all products involved
      List<DocumentSnapshot> productSnaps = [];
      for (var item in items) {
        productSnaps.add(await transaction.get(_db.collection('products').doc(item['productId'])));
      }

      // 2. Validate and Deduct Stock
      for (int i = 0; i < productSnaps.length; i++) {
        if (!productSnaps[i].exists) throw Exception("Product not found: ${items[i]['productId']}");

        final data = productSnaps[i].data() as Map<String, dynamic>;

        // Handle different data structures for stock (flat 'totalStock' vs nested 'stock.availableQty')
        int currentStock = 0;
        if (data.containsKey('totalStock')) {
          currentStock = (data['totalStock'] as num).toInt();
        } else if (data['stock'] != null && data['stock'] is Map) {
          currentStock = (data['stock']['availableQty'] as num).toInt();
        }

        final requestedQty = items[i]['quantity'] as int;

        if (currentStock < requestedQty) {
          throw Exception("Insufficient stock for ${data['name']}");
        }

        // Apply update based on structure
        if (data.containsKey('totalStock')) {
          transaction.update(productSnaps[i].reference, {
            'totalStock': currentStock - requestedQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(productSnaps[i].reference, {
            'stock.availableQty': currentStock - requestedQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Log the movement
        final logRef = _db.collection('inventory_logs').doc();
        transaction.set(logRef, {
          'productId': productSnaps[i].id,
          'productName': data['name'],
          'action': 'sale_pos',
          'change': -requestedQty,
          'staffId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // 3. Create the Order
      transaction.set(orderRef, {
        'id': orderRef.id, // Explicit ID field often helpful
        'userId': 'POS-WALKIN',
        'staffId': userId,
        'items': items,
        'total': totalAmount,
        'status': 'delivered', // POS is instant
        'source': 'pos',
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Helper
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