import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart'; // Alias to avoid conflict if necessary

class OrderAlertListener extends StatefulWidget {
  final Widget child;
  const OrderAlertListener({super.key, required this.child});

  @override
  State<OrderAlertListener> createState() => _OrderAlertListenerState();
}

class _OrderAlertListenerState extends State<OrderAlertListener> {
  // Keep track of processed orders so we don't alert twice for the same pending order
  final Set<String> _processedOrderIds = {};
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Listen ONLY to pending orders
    _subscription = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final orderId = doc.id;

          if (!_processedOrderIds.contains(orderId)) {
            _processedOrderIds.add(orderId);

            // Wait a tiny bit to ensure the context is ready if app just launched
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _showNewOrderAlert(orderId, doc.data() as Map<String, dynamic>);
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showNewOrderAlert(String orderId, Map<String, dynamic> data) {
    // TODO: Play Sound here using audioplayers package if you have it installed
    // AudioPlayer().play(AssetSource('sounds/alert.mp3'));

    showDialog(
      context: context,
      barrierDismissible: false, // Force interaction
      builder: (ctx) => _AutoAcceptDialog(
        orderId: orderId,
        orderData: data,
        onAccept: () => _handleAccept(orderId),
      ),
    );
  }

  Future<void> _handleAccept(String orderId) async {
    // 1. Update status to processing
    await AdminService().updateOrderStatus(orderId, 'processing');

    // 2. Find Nearest Rider (Mocking Lat/Lng from order if available, or using defaults)
    // Assuming Order has 'deliveryLocation'. If not, we skip geography for now.
    // For this demo, let's just find ANY available rider.

    if (!mounted) return;

    // Show loading for rider assignment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Looking for nearest rider...")),
    );

    try {
      // Mock coordinates for order (New Delhi center)
      final rider = await AdminService().findNearestRider(28.6139, 77.2090);

      if (rider != null) {
        await AdminService().updateOrderStatus(orderId, 'processing', riderId: rider.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Order assigned to ${rider.name}"), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No riders available! Order accepted but unassigned."), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("Error assigning rider: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AutoAcceptDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final VoidCallback onAccept;

  const _AutoAcceptDialog({
    required this.orderId,
    required this.orderData,
    required this.onAccept,
  });

  @override
  State<_AutoAcceptDialog> createState() => _AutoAcceptDialogState();
}

class _AutoAcceptDialogState extends State<_AutoAcceptDialog> {
  int _secondsRemaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          // Time's up! Auto-accept.
          _timer?.cancel();
          Navigator.of(context).pop(); // Close dialog
          widget.onAccept(); // Trigger logic
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.orderData['total'] ?? 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          const Icon(Icons.notification_important, color: Colors.red, size: 30),
          const SizedBox(width: 10),
          const Text("New Order!", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Order #${widget.orderId.substring(0, 5).toUpperCase()} received."),
          const SizedBox(height: 10),
          Text(
            "Value: ₹$total",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _secondsRemaining / 30,
            backgroundColor: Colors.grey.shade200,
            color: _secondsRemaining < 10 ? Colors.red : Colors.indigo,
          ),
          const SizedBox(height: 8),
          Text(
            "Auto-accepting in $_secondsRemaining seconds...",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Cancel means "Ignore" or "Manual Review later"
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: const Text("View Later", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
            widget.onAccept();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text("ACCEPT NOW"),
        ),
      ],
    );
  }
}