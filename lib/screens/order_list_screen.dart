import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/services/admin_service.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Orders")),
      body: StreamBuilder<List<Order>>(
        stream: AdminService().getOrdersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;
          if (orders.isEmpty) return const Center(child: Text("No orders found"));

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return ListTile(
                title: Text("Order #${o.id.substring(0,5)}..."),
                subtitle: Text("₹${o.total} • ${o.status}"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
              );
            },
          );
        },
      ),
    );
  }
}