import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order; // <--- FIX: Hide 'Order' from Firestore
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

// Use relative imports to avoid package naming issues
import '../category.dart';
import '../order.dart';
import '../product.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // --- Utility Functions ---
  Future<String> uploadFile(File file, String path) async {
    final storageRef = _storage.ref().child(path).child(_uuid.v4());
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);
    return await snapshot.ref.getDownloadURL();
  }

  // --- Category Management ---
  Stream<List<Category>> getCategories() {
    return _db.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> saveCategory({required String name, File? imageFile, String? id, String? existingImageUrl}) async {
    String imageUrl = existingImageUrl ?? '';
    if (imageFile != null) {
      imageUrl = await uploadFile(imageFile, 'categories/images');
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

  // --- Product Management ---
  Stream<List<Product>> getProducts() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> saveProduct({
    required Product product,
    File? imageFile,
    String? existingImageUrl,
  }) async {
    String thumbnailUrl = product.thumbnailUrl;
    if (imageFile != null) {
      thumbnailUrl = await uploadFile(imageFile, 'products/thumbnails');
    }
    final data = product.toMap();
    data['thumbnailUrl'] = thumbnailUrl;

    if (product.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('products').add(data);
    } else {
      await _db.collection('products').doc(product.id).update(data);
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }

  // --- Order Management ---
  Stream<List<Order>> getOrders({String statusFilter = 'all'}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);
    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Explicit casting to Map<String, dynamic>
        return Order.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- POS Management ---
  Stream<List<Product>> getInventory() => getProducts();

  Future<void> createPosOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
  }) async {
    final orderId = "POS-${DateTime.now().millisecondsSinceEpoch}";
    await _db.collection('orders').doc(orderId).set({
      'orderId': orderId,
      'userId': 'WALK-IN-CUSTOMER',
      'items': items,
      'subtotal': total,
      'deliveryFee': 0,
      'total': total,
      'addressId': 'STORE_COUNTER',
      'paymentMethod': paymentMethod,
      'status': 'delivered',
      'source': 'pos',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();
    for (var item in items) {
      // Ensure your Product model or Cart logic provides the correct ID here
      final ref = _db.collection('products').doc(item['productId']);
      batch.update(ref, {
        'stock.availableQty': FieldValue.increment(-item['quantity'])
      });
    }
    await batch.commit();
  }
}