import 'package:flutter/material.dart';
import '../models/order.dart'; // Ensure Order model is correct
import '../models/services/admin_service.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Orders")),
      body: StreamBuilder<List<Order>>(
        stream: AdminService().getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!;
          if (orders.isEmpty) return const Center(child: Text("No orders found."));

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text("Order #${o.id.substring(0, 5).toUpperCase()}"),
                  subtitle: Text("${o.status.toUpperCase()} • ${o.items.length} Items"),
                  trailing: Text(
                      "₹${o.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}