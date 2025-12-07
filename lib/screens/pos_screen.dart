import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
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
          'sku': product.sku,
        });
      }
    });
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 400,
        child: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                // Handle scan logic here (Look up product by SKU)
                Navigator.pop(ctx);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid ?? 'unknown';

      await _service.processTransaction(
        items: _cart,
        userId: userId,
        totalAmount: _total,
        paymentMethod: 'cash',
      );

      if (mounted) {
        setState(() => _cart.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sale Successful"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Terminal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanner,
          )
        ],
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final p = snapshot.data![index];
                    return GestureDetector(
                      onTap: () => _addToCart(p),
                      child: Card(
                        child: Column(
                          children: [
                            Expanded(child: Image.network(p.thumbnailUrl, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image))),
                            Text(p.name, overflow: TextOverflow.ellipsis),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blueGrey,
                    width: double.infinity,
                    child: Text("Total: ₹${_total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 24)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, i) {
                        final item = _cart[i];
                        return ListTile(
                          title: Text(item['name']),
                          subtitle: Text("x${item['quantity']}"),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _cart.removeAt(i))),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                      onPressed: _isLoading ? null : _completeSale,
                      child: _isLoading ? const CircularProgressIndicator() : const Text("PAY NOW", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}