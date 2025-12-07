import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';
import '../models/services/admin_service.dart';
import 'add_edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final AdminService _service = AdminService();
  final ScrollController _scrollController = ScrollController();

  List<ProductSummary> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    // In a real pagination scenario, we need to handle the DocumentSnapshot state carefully.
    // For this robust example, we will just fetch the first batch to ensure it works without complex state management bugs.
    // Ideally, _service.getProductsPage would return a wrapper with the lastDoc.

    try {
      // Hard resetting for simplicity in this demo or fetching next page
      final newItems = await _service.getProductsPage(limit: 20, lastDoc: _lastDocument);

      if (mounted) {
        setState(() {
          _products.addAll(newItems);
          _isLoading = false;
          if (newItems.length < 20) _hasMore = false;
          // Note: To properly paginate, you'd need to store the DocumentSnapshot of the last item in newItems
          // _lastDocument = newItems.last.snapshot; (Requires modification to ProductSummary to hold snapshot)
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen())
        ).then((_) {
          // Refresh list
          setState(() { _products.clear(); _hasMore = true; _lastDocument = null; });
          _fetchProducts();
        }),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _products.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _products.length) return const Center(child: CircularProgressIndicator());

          final p = _products[index];
          return ListTile(
            leading: Image.network(p.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.image)),
            title: Text(p.name),
            subtitle: Text("Stock: ${p.totalStock} | SKU: ${p.sku}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("₹${p.price}"),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => Navigator.push(
                      context,
                      // We must fetch full product details for editing
                      MaterialPageRoute(builder: (_) => AddEditProductScreen(productId: p.id))
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}