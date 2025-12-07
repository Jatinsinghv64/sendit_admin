import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/services/admin_service.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Order Details")),
      body: Column(
        children: [
          ListTile(title: Text("Status: ${order.status.toUpperCase()}")),
          Expanded(
            child: ListView.builder(
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return ListTile(
                  title: Text(item['name'] ?? 'Product'),
                  trailing: Text("x${item['quantity']}"),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                  onPressed: () => AdminService().updateOrderStatus(order.id, 'shipped'),
                  child: const Text("Mark Shipped")
              ),
              ElevatedButton(
                  onPressed: () => AdminService().updateOrderStatus(order.id, 'delivered'),
                  child: const Text("Mark Delivered")
              ),
            ],
          )
        ],
      ),
    );
  }
}