import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../models/order.dart';
import '../models/services/admin_service.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  String _selectedStatus = 'all'; // Default to 'all' to show something initially
  final List<String> _statuses = ['all', 'pending', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: _selectedStatus,
              dropdownColor: Colors.white,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedStatus = newValue;
                  });
                }
              },
              items: _statuses.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.toUpperCase()),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: adminService.getOrders(statusFilter: _selectedStatus),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No orders found with status: $_selectedStatus'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _buildOrderTile(context, orders[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, Order order) {
    final formattedDate = DateFormat('MMM d, hh:mm a').format(order.createdAt.toDate());
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
          );
        },
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.receipt, color: statusColor),
        ),
        title: Text('Order #${order.id.substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('₹${order.total.toStringAsFixed(2)} • ${order.items.length} Items\n$formattedDate'),
        trailing: Chip(
          label: Text(order.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
          backgroundColor: statusColor,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.red;
      case 'processing': return Colors.orange;
      case 'shipped': return Colors.blue;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }
}