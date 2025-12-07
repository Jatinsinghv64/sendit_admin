import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import for FirebaseAuth
import '../models/inventory_model.dart';
import '../models/services/admin_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final AdminService _service = AdminService();
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = false;

  double get _total => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

  void _addToCart(ProductSummary product) {
    final index = _cart.indexWhere((item) => item['productId'] == product.id);
    setState(() {
      if (index >= 0) {
        _cart[index]['quantity']++;
      } else {
        _cart.add({
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': 1,
        });
      }
    });
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 400,
        child: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _lookupProductBySku(barcode.rawValue!);
                Navigator.pop(ctx);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _lookupProductBySku(String sku) async {
    setState(() => _isLoading = true);
    final p = await _service.getProductBySku(sku);
    if (p != null) {
      _addToCart(p);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${p.name}")));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product not found")));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown_staff';

      await _service.processPosTransaction(
        items: _cart,
        userId: userId,
        totalAmount: _total,
        paymentMethod: 'cash',
      );

      if (mounted) {
        setState(() => _cart.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sale Complete!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Terminal"),
        actions: [IconButton(icon: const Icon(Icons.qr_code), onPressed: _openScanner)],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: FutureBuilder<List<ProductSummary>>(
              future: _service.getProductsPage(limit: 50),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final p = snapshot.data![index];
                    return GestureDetector(
                      onTap: () => _addToCart(p),
                      child: Card(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.name, textAlign: TextAlign.center, maxLines: 2),
                            Text("₹${p.price}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, i) {
                        final item = _cart[i];
                        return ListTile(
                          title: Text(item['name']),
                          subtitle: Text("x${item['quantity']}"),
                          trailing: Text("₹${(item['price'] * item['quantity']).toStringAsFixed(1)}"),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.blueGrey[900],
                    width: double.infinity,
                    child: Text("Total: ₹$_total", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeSale,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CHARGE", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}