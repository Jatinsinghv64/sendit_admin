import 'package:cloud_firestore/cloud_firestore.dart';
import '../inventory_model.dart';
import '../app_user.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. RBAC: Get Current User Role ---
  Stream<AdminUser?> getCurrentUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AdminUser.fromMap(doc.data()!, doc.id);
    });
  }

  // --- 2. Scalable Reads: Pagination ---
  // Replaces "get all products" which crashes with 1000+ items
  Future<List<ProductSummary>> getProductsPage({
    int limit = 20,
    DocumentSnapshot? lastDoc,
    String? searchQuery,
  }) async {
    Query query = _db.collection('products').where('isActive', isEqualTo: true);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Note: Requires "searchKeywords" array in Firestore for each product
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

  // --- 3. Robust Writes: Transactions ---
  // Prevents race conditions (e.g., two people buying the last item)
  Future<void> processTransaction({
    required List<Map<String, dynamic>> items, // {productId, qty, name, price}
    required String userId,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      // A. Read all product docs first (Rule of Firestore Transactions)
      List<DocumentSnapshot> productSnapshots = [];
      for (var item in items) {
        DocumentReference ref = _db.collection('products').doc(item['productId']);
        productSnapshots.add(await transaction.get(ref));
      }

      // B. Validate & Deduct Stock
      for (int i = 0; i < productSnapshots.length; i++) {
        final snapshot = productSnapshots[i];
        final requestedQty = items[i]['quantity'] as int;

        if (!snapshot.exists) {
          throw Exception("Product ${items[i]['name']} not found!");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = data['stock']?['availableQty'] ?? 0;

        if (currentStock < requestedQty) {
          throw Exception("Insufficient stock for ${data['name']}. Available: $currentStock");
        }

        // Update Stock
        transaction.update(snapshot.reference, {
          'stock.availableQty': currentStock - requestedQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Audit Log
        final logRef = _db.collection('inventory_logs').doc();
        transaction.set(logRef, {
          'productId': snapshot.id,
          'action': 'sale',
          'quantityChange': -requestedQty,
          'orderId': orderRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'performedBy': userId,
        });
      }

      // C. Create Order
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
}