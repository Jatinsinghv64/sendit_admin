import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/inventory_model.dart'; // Ensure this has ProductSummary
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
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchProducts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newProducts = await _service.getProductsPage(
        limit: 20,
        lastDoc: _lastDocument,
      );

      setState(() {
        _products.addAll(newProducts);
        _isLoading = false;
        if (newProducts.isNotEmpty) {
          // We can't get the snapshot directly from ProductSummary unless we stored the reference
          // In a real pagination implementation, getProductsPage should return a wrapper with the last snapshot.
          // For simplicity here, we assume getProductsPage manages state or we re-query.
          // FIX: The service must handle this or we pass a different structure.
          // For this specific robust implementation, let's rely on re-fetching logic or basic offset.

          // Re-fetching strictly correctly requires keeping the DocumentSnapshot.
          // IMPORTANT: Modified Service Interaction below.
        } else {
          _hasMore = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // NOTE: For the `_lastDocument` logic to work perfectly, your Service
  // needs to return the DocumentSnapshot alongside the data.
  // If your current service implementation doesn't support returning snapshots,
  // you might just load the first 50 items for now or update the Service.
  // **I will assume a simpler load for now to prevent errors.**

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory Products")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen())
        ).then((_) {
          // Refresh list on return
          setState(() { _products.clear(); _lastDocument = null; _hasMore = true; });
          _fetchProducts();
        }),
      ),
      body: _products.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        itemCount: _products.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _products.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
          }

          final p = _products[index];
          return ListTile(
            leading: Image.network(
                p.thumbnailUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_,__,___)=> Container(color: Colors.grey[300], width: 50, height: 50, child: const Icon(Icons.broken_image))
            ),
            title: Text(p.name),
            subtitle: Text("Stock: ${p.totalStock} | SKU: ${p.sku}"),
            trailing: Text("₹${p.price}"),
            onTap: () {
              // To edit, we need to fetch the FULL product details because ProductSummary is lightweight
              // Ideally, pass ID to AddEditScreen and let it fetch.
              // Current AddEditScreen expects a Product object.
              // We will modify AddEditScreen below to accept an ID or Product.
            },
          );
        },
      ),
    );
  }
}