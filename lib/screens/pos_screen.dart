import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import '../models/inventory_model.dart';
import '../models/services/admin_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductSummary> _allProducts = [];
  List<ProductSummary> _filteredProducts = [];
  final List<Map<String, dynamic>> _cart = [];

  bool _isLoading = false;
  bool _isInitLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final prods = await _service.getProductsPage(limit: 1000); // Fetch more for POS cache
      if (mounted) {
        setState(() {
          _allProducts = prods;
          _filteredProducts = prods;
          _isInitLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading products: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final name = (p.name ?? '').toLowerCase();
          // Ensure SKU is treated safely
          final sku = p.sku.toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) || sku.contains(searchLower);
        }).toList();
      }
    });
  }

  void _addToCart(ProductSummary product) {
    HapticFeedback.selectionClick();
    final index = _cart.indexWhere((item) => item['productId'] == product.id);

    // Check stock limit in local cart state
    int currentQtyInCart = index >= 0 ? _cart[index]['quantity'] : 0;
    // Safe null check for totalStock
    int stock = product.totalStock ?? 0;

    if (currentQtyInCart >= stock) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max stock reached for this item"), duration: Duration(milliseconds: 500)),
      );
      return;
    }

    setState(() {
      if (index >= 0) {
        _cart[index]['quantity']++;
      } else {
        _cart.add({
          'productId': product.id,
          'name': product.name ?? 'Unknown Item',
          'price': product.price ?? 0.0,
          'quantity': 1,
          'product': product, // Kept for local logic, but must be removed before saving
        });
      }
    });
  }

  void _removeFromCart(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_cart[index]['quantity'] > 1) {
        _cart[index]['quantity']--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  double get _total => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown_staff';

      // CLEANUP: Remove the 'product' object from cart items before sending to Firestore
      // Firestore cannot serialize custom objects like ProductSummary
      final List<Map<String, dynamic>> cleanItems = _cart.map((item) {
        final cleanItem = Map<String, dynamic>.from(item);
        cleanItem.remove('product'); // Remove the custom object
        return cleanItem;
      }).toList();

      await _service.processPosTransaction(
        items: cleanItems,
        userId: userId,
        totalAmount: _total,
        paymentMethod: 'cash',
      );

      if (mounted) {
        setState(() => _cart.clear());
        _showSuccessDialog();
        // Reload inventory to reflect stock changes
        _loadInventory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Transaction Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: const Text("Transaction Complete"),
      content: Text("Payment of ₹${_total.toStringAsFixed(2)} recorded."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Next Customer"),
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT PANEL: Product Catalog
            Expanded(
              flex: 65,
              child: Column(
                children: [
                  _buildCatalogHeader(),
                  Expanded(
                    child: _isInitLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildProductGrid(isDesktop),
                  ),
                ],
              ),
            ),

            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),

            // RIGHT PANEL: Cart & Checkout
            Expanded(
              flex: 35,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildCartHeader(),
                    Expanded(child: _buildCartList()),
                    _buildCheckoutSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Left Panel Widgets ---

  Widget _buildCatalogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("POS Terminal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _filterProducts,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Scan barcode or search product...",
              prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF4338CA)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                _searchController.clear();
                _filterProducts('');
              })
                  : null,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(bool isDesktop) {
    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("No products found", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75, // Taller for better vertical text fit
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(ProductSummary p) {
    final int stock = p.totalStock ?? 0;
    final bool isOOS = stock <= 0;
    final String? imageUrl = p.thumbnailUrl;

    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: isOOS ? null : () => _addToCart(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  image: (imageUrl != null && imageUrl.isNotEmpty)
                      ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    // Add error builder to handle failed image loads
                    onError: (exception, stackTrace) {
                      // This ensures if network image fails, it falls back gracefully visually
                      // (though DecorationImage doesn't support errorBuilder directly in all contexts,
                      //  using a child with error handling is safer for NetworkImage widgets,
                      //  but for DecorationImage we rely on it working or showing the child below)
                    },
                  )
                      : null,
                ),
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300, size: 40)
                    : null, // If image fails to load, the container background shows. Ideally use Image.network with errorBuilder for robust handling.
              ),
            ),

            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.name ?? 'Unknown Product', // Fixed: Null check for name
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹${(p.price ?? 0).toInt()}", // Fixed: Null check for price
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                        ),
                        _buildStockBadge(stock),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    if (stock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
        child: Text("OOS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
      );
    }
    return Text(
      "$stock left",
      style: TextStyle(fontSize: 11, color: stock < 10 ? Colors.orange : Colors.grey.shade500),
    );
  }

  // --- Right Panel Widgets (Cart) ---

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Current Bill", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _cart.clear()),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text("Clear", style: TextStyle(color: Colors.red)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
              child: Icon(Icons.shopping_cart_outlined, size: 32, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text("Cart is empty", style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text("Select items to add", style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _cart.length,
      separatorBuilder: (_,__) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _cart[index];
        final totalItemPrice = item['price'] * item['quantity'];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Qty Controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _removeFromCart(index),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.remove, size: 14)),
                    ),
                    Text(
                      "${item['quantity']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () => _addToCart(item['product']),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add, size: 14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    Text("@ ₹${item['price']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),

              // Total
              Text(
                "₹${totalItemPrice.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Subtotal", style: TextStyle(color: Colors.grey)),
                Text("₹${_total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax (0%)", style: TextStyle(color: Colors.grey)),
                Text("₹0.00", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Payable", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  "₹${_total.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading || _cart.isEmpty ? null : _completeSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("CHARGE CASH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}