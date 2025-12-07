import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String userId;
  final List<Map<String, dynamic>> items;
  final double total;
  final String status; // 'pending', 'processing', 'shipped', 'delivered', 'cancelled'
  final String paymentMethod;
  final Timestamp createdAt;
  final String source; // 'app' or 'pos'

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.source,
  });

  factory Order.fromMap(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      userId: data['userId'] ?? 'WALK-IN-CUSTOMER',
      // Safely cast the list of items
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList(),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      source: data['source'] ?? 'app',
    );
  }
}