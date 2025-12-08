import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../app_user.dart';
import '../inventory_model.dart';
import '../product.dart';
import '../category.dart';
import '../order.dart';
import '../rider_model.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // ==========================================
  // 1. AUTH & ROLES
  // ==========================================
  Stream<AdminUser?> getCurrentUserStream(String uid) {
    return _db.collection('staff').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
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
  // 3. PRODUCTS
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

  Future<void> updateOrderStatus(String orderId, String newStatus, {String? riderId}) async {
    final data = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (riderId != null) {
      data['assignedRiderId'] = riderId;
    }
    await _db.collection('orders').doc(orderId).update(data);
  }

  // ==========================================
  // 5. RIDER MANAGEMENT
  // ==========================================

  Stream<List<Rider>> getRidersStream() {
    return _db.collection('riders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Rider.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // SAVES RIDER AND CREATES LOGIN IF NEW
  Future<void> saveRider(Rider rider, {String? password}) async {
    String riderId = rider.id;

    // IF NEW RIDER (Empty ID) & Password Provided: Create Firebase Auth User
    if (riderId.isEmpty && password != null && password.isNotEmpty) {
      // Initialize a secondary app so we don't log out the Admin
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp-${_uuid.v4()}', // Unique name
        options: Firebase.app().options,
      );

      try {
        UserCredential cred = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(email: rider.email, password: password);

        riderId = cred.user!.uid; // Use the Auth UID as the Firestore Document ID

        // Optional: Update Display Name in Auth
        await cred.user!.updateDisplayName(rider.name);

      } on FirebaseAuthException catch (e) {
        throw Exception("Auth Error: ${e.message}");
      } finally {
        // Always clean up the secondary app
        await secondaryApp.delete();
      }
    }

    // Prepare data for Firestore
    final data = rider.toMap();

    // Save/Update in Firestore
    if (riderId.isNotEmpty && rider.id.isEmpty) {
      // New Rider: Use the UID generated by Auth as the doc ID
      await _db.collection('riders').doc(riderId).set(data);
    } else if (rider.id.isNotEmpty) {
      // Existing Rider: Update existing doc
      await _db.collection('riders').doc(rider.id).update(data);
    } else {
      // Fallback (Rare): Just add to firestore if something skipped Auth
      await _db.collection('riders').add(data);
    }
  }

  Future<void> deleteRider(String id) async {
    // Note: This only deletes from Firestore.
    // Deleting from Auth requires Cloud Functions (Admin SDK) to be secure.
    await _db.collection('riders').doc(id).delete();
  }

  Future<Rider?> findNearestRider(double orderLat, double orderLng) async {
    final query = await _db.collection('riders')
        .where('status', isEqualTo: 'available')
        .get();

    if (query.docs.isEmpty) return null;

    final riders = query.docs.map((d) => Rider.fromMap(d.data(), d.id)).toList();

    riders.sort((a, b) {
      final distA = _calculateDistance(orderLat, orderLng, a.latitude, a.longitude);
      final distB = _calculateDistance(orderLat, orderLng, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return riders.first;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a));
  }

  // --- Helpers ---
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
        int currentStock = (data['stock'] is Map)
            ? (data['stock']['availableQty'] ?? 0)
            : (data['availableQty'] ?? data['totalStock'] ?? 0);

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