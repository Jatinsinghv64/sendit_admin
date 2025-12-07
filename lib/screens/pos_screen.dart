import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/product.dart';
import '../models/services/admin_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, dynamic> _cart = {};
  String _paymentMethod = 'cash';
  List<Product> _allProducts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Provider.of<AdminService>(context, listen: false).getInventory().listen((products) {
      if (mounted) setState(() => _allProducts = products);
    });
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]['quantity']++;
      } else {
        _cart[product.id] = {
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': 1,
        };
      }
    });
  }

  void _decrementCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]['quantity'] > 1) {
          _cart[productId]['quantity']--;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  Future<void> _processSale(double total) async {
    if (total == 0 || _cart.isEmpty) return;
    setState(() => _isLoading = true);

    final adminService = Provider.of<AdminService>(context, listen: false);

    // FIX: Cast dynamic map values to strong typed List
    final List<Map<String, dynamic>> itemsList = _cart.values.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();

    try {
      await adminService.createPosOrder(
        items: itemsList,
        total: total,
        paymentMethod: _paymentMethod,
      );

      // Print Receipt
      await _printReceipt(itemsList, total);

      if (mounted) {
        setState(() {
          _cart.clear();
          _paymentMethod = 'cash';
          _searchCtrl.clear();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sale Completed!")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sale Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var products = _allProducts;
    if (_searchCtrl.text.isNotEmpty) {
      products = products.where((p) => p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();
    }

    return Scaffold(
      body: Row(
        children: [
          // Left: Product Catalog
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Search Product...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchCtrl.clear())),
                    ),
                    onChanged: (val) => setState((){}),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isOOS = product.stock['availableQty'] <= 0;
                      return GestureDetector(
                        onTap: isOOS ? null : () => _addToCart(product),
                        child: Card(
                          color: isOOS ? Colors.grey[200] : Colors.white,
                          child: Column(
                            children: [
                              Expanded(
                                child: product.thumbnailUrl.isNotEmpty
                                    ? Image.network(product.thumbnailUrl, fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 50, color: Colors.grey),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text("₹${product.price}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    if(isOOS) const Text("OOS", style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right: Cart
          Container(
            width: 350,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.indigo,
                  width: double.infinity,
                  child: const Text("Current Bill", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _cart.values.toList()[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text("₹${item['price']} x ${item['quantity']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _decrementCart(item['productId'])),
                            Text("${item['quantity']}"),
                            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => _addToCart(_allProducts.firstWhere((p) => p.id == item['productId']))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Total Payable", style: TextStyle(fontSize: 16)),
                        Text("₹${_cart.values.fold(0.0, (sum, i) => sum + (i['price']*i['quantity'])).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 20),
                      Row(children: [
                        _paymentChip('cash', Icons.money),
                        const SizedBox(width: 10),
                        _paymentChip('upi', Icons.qr_code),
                      ]),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _cart.isEmpty || _isLoading ? null : () => _processSale(_cart.values.fold(0.0, (sum, i) => sum + (i['price']*i['quantity']))),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("COMPLETE SALE"),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _paymentChip(String method, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: _paymentMethod == method ? Colors.indigo.withOpacity(0.1) : Colors.white,
              border: Border.all(color: _paymentMethod == method ? Colors.indigo : Colors.grey),
              borderRadius: BorderRadius.circular(8)
          ),
          child: Icon(icon, color: _paymentMethod == method ? Colors.indigo : Colors.grey),
        ),
      ),
    );
  }

  Future<void> _printReceipt(List<Map<String, dynamic>> items, double total) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
              children: [
                pw.Text('SendIt Grocery', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                pw.Divider(),
                ...items.map((e) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [pw.Text("${e['quantity']} x ${e['name']}", style: const pw.TextStyle(fontSize: 10)), pw.Text("${e['price']*e['quantity']}", style: const pw.TextStyle(fontSize: 10))]
                )),
                pw.Divider(),
                pw.Text('Total: $total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ]
          );
        }
    ));
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}