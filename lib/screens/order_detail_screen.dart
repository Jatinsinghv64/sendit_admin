import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../models/order.dart';
import '../models/services/admin_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  String _selectedStatus = '';
  final List<String> _statuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == widget.order.status) return;

    final adminService = Provider.of<AdminService>(context, listen: false);
    await adminService.updateOrderStatus(widget.order.id, _selectedStatus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${widget.order.id} status updated to $_selectedStatus')),
      );
      // Optional: Navigate back or update the local order object (for this simple example, we rely on the stream to update the list)
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy - hh:mm a').format(widget.order.createdAt.toDate());

    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.order.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer ID: ${widget.order.userId}', style: const TextStyle(fontSize: 16)),
                    Text('Placed On: $formattedDate', style: const TextStyle(fontSize: 16)),
                    Text('Source: ${widget.order.source.toUpperCase()}', style: const TextStyle(fontSize: 16)),
                    Text('Payment: ${widget.order.paymentMethod.toUpperCase()}', style: const TextStyle(fontSize: 16)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('₹${widget.order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status Update Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      value: _selectedStatus,
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedStatus = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedStatus == widget.order.status ? null : _updateStatus,
                        child: const Text('Save Status'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Item Details
            const Text('Items Ordered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...widget.order.items.map((item) {
              return ListTile(
                title: Text(item['name']),
                subtitle: Text('Qty: ${item['quantity']}'),
                trailing: Text('₹${(item['price'] * item['quantity']).toStringAsFixed(2)}'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}