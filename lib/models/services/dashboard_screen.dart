import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Ensure you have fl_chart in pubspec.yaml
import '../../models/order.dart';
import '../../models/services/admin_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: StreamBuilder<List<Order>>(
        // FIX: Use the correct method name 'getOrdersStream'
        stream: AdminService().getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final orders = snapshot.data ?? [];
          final totalRevenue = orders.fold(0.0, (sum, o) => sum + o.total);
          final pendingOrders = orders.where((o) => o.status == 'pending').length;
          final deliveredOrders = orders.where((o) => o.status == 'delivered').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    _buildSummaryCard(
                        context,
                        "Total Revenue",
                        "₹${totalRevenue.toStringAsFixed(0)}",
                        Colors.green
                    ),
                    const SizedBox(width: 16),
                    _buildSummaryCard(
                        context,
                        "Orders",
                        orders.length.toString(),
                        Colors.blue
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSummaryCard(
                        context,
                        "Pending",
                        pendingOrders.toString(),
                        Colors.orange
                    ),
                    const SizedBox(width: 16),
                    _buildSummaryCard(
                        context,
                        "Delivered",
                        deliveredOrders.toString(),
                        Colors.purple
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Simple Recent Orders List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.take(5).length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return ListTile(
                      title: Text("Order #${order.id.substring(0, 5)}"),
                      subtitle: Text(order.status),
                      trailing: Text("₹${order.total}"),
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}