import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:senditadmin/models/order.dart';
import 'package:senditadmin/models/services/admin_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: StreamBuilder<List<Order>>(
        stream: adminService.getOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];
          final totalOrders = orders.length;
          final pendingOrders = orders.where((o) => o.status == 'pending').length;
          final totalSales = orders
              .where((o) => o.status == 'delivered')
              .fold(0.0, (sum, item) => sum + item.total);

          final posOrders = orders.where((o) => o.source == 'pos').length;
          final appOrders = orders.where((o) => o.source == 'app').length;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.3,
              children: [
                _buildMetricCard('Total Orders', totalOrders.toString(), Icons.receipt_long, Colors.blue),
                _buildMetricCard('Pending Orders', pendingOrders.toString(), Icons.pending_actions, Colors.orange),
                _buildMetricCard('Total Sales', '₹${totalSales.toStringAsFixed(2)}', Icons.monetization_on, Colors.green),
                _buildMetricCard('POS / App', '$posOrders / $appOrders', Icons.store, Colors.purple),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 30),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}