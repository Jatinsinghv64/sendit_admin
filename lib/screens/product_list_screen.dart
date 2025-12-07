import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
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
  final TextEditingController _searchController = TextEditingController();

  List<ProductSummary> _products = [];
  List<ProductSummary> _filteredProducts = [];
  bool _isLoading = true;
  String _activeFilter = 'All'; // 'All', 'Low Stock', 'Out of Stock'

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      // In production, implement pagination.
      // Fetching 500 items is a safe upper bound for a small-medium store.
      final items = await _service.getProductsPage(limit: 500);
      if (mounted) {
        setState(() {
          _products = items;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((p) {
        final matchesSearch = p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query);

        if (!matchesSearch) return false;

        switch (_activeFilter) {
          case 'Low Stock': return p.totalStock > 0 && p.totalStock < 10;
          case 'Out of Stock': return p.totalStock <= 0;
          default: return true;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _products.fold(0.0, (sum, p) => sum + (p.price * p.totalStock));
    final lowStockCount = _products.where((p) => p.totalStock > 0 && p.totalStock < 10).length;
    final outOfStockCount = _products.where((p) => p.totalStock <= 0).length;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Cool Grey 100
      body: SafeArea(
        child: Column(
          children: [
            // 1. Fixed Header
            _buildHeader(context),

            // 2. Scrollable Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchProducts,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // A. Metrics Section (Horizontal Scrollable)
                    SliverToBoxAdapter(
                      child: _buildMetricsSection(totalValue, lowStockCount, outOfStockCount),
                    ),

                    // B. Search & Filters
                    SliverToBoxAdapter(
                      child: _buildSearchAndFilter(context),
                    ),

                    // C. Content List/Table
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredProducts.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text("No products found")),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Bottom padding for FAB
                        sliver: isDesktop
                            ? _buildDesktopTable()
                            : _buildMobileList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(context),
        backgroundColor: const Color(0xFF4338CA),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Inventory", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Text("Manage stock & prices", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          IconButton(
            onPressed: _fetchProducts,
            icon: const Icon(Icons.refresh, color: Color(0xFF4338CA)),
            tooltip: "Refresh Data",
          ),
        ],
      ),
    );
  }

  // --- Metrics ---
  Widget _buildMetricsSection(double totalValue, int lowStock, int outStock) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard("Total Value", "₹${totalValue.toStringAsFixed(0)}", Icons.monetization_on_outlined, Colors.green),
          const SizedBox(width: 12),
          _buildSummaryCard("Low Stock", "$lowStock", Icons.warning_amber_rounded, Colors.orange),
          const SizedBox(width: 12),
          _buildSummaryCard("Out of Stock", "$outStock", Icons.error_outline, Colors.red),
          const SizedBox(width: 12),
          _buildSummaryCard("Total SKUs", "${_products.length}", Icons.qr_code, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // --- Search & Filters ---
  Widget _buildSearchAndFilter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: "Search name or SKU...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips (Scrollable Row to avoid overflow)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Low Stock'),
                const SizedBox(width: 8),
                _buildFilterChip('Out of Stock'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _activeFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _activeFilter = label;
          _applyFilters();
        });
        HapticFeedback.lightImpact();
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF4338CA).withOpacity(0.1),
      checkmarkColor: const Color(0xFF4338CA),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade300),
      ),
    );
  }

  // --- Mobile List View (Card Based) ---
  Widget _buildMobileList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final p = _filteredProducts[index];
          final isOOS = p.totalStock <= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToAddEdit(context, productId: p.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                          image: (p.thumbnailUrl.isNotEmpty)
                              ? DecorationImage(
                              image: NetworkImage(p.thumbnailUrl),
                              fit: BoxFit.cover,
                              onError: (_, __) {}
                          )
                              : null,
                        ),
                        child: p.thumbnailUrl.isEmpty
                            ? const Icon(Icons.image_not_supported, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text("SKU: ${p.sku}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("₹${p.price.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                _buildStatusBadge(p.totalStock),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _filteredProducts.length,
      ),
    );
  }

  // --- Desktop Table View (Data Table) ---
  Widget _buildDesktopTable() {
    return SliverToBoxAdapter(
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800), // Force min width for table
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 30,
              columns: const [
                DataColumn(label: Text("Product")),
                DataColumn(label: Text("SKU")),
                DataColumn(label: Text("Price")),
                DataColumn(label: Text("Stock")),
                DataColumn(label: Text("Actions")),
              ],
              rows: _filteredProducts.map((p) {
                return DataRow(cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade100,
                          image: (p.thumbnailUrl.isNotEmpty)
                              ? DecorationImage(
                              image: NetworkImage(p.thumbnailUrl),
                              fit: BoxFit.cover,
                              onError: (_, __) {}
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  )),
                  DataCell(Text(p.sku, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                  DataCell(Text("₹${p.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(_buildStatusBadge(p.totalStock)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                      onPressed: () => _navigateToAddEdit(context, productId: p.id),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(int stock) {
    Color bg;
    Color text;
    String label;

    if (stock <= 0) {
      bg = Colors.red.shade50;
      text = Colors.red.shade700;
      label = "Out of Stock";
    } else if (stock < 10) {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade700;
      label = "$stock (Low)";
    } else {
      bg = Colors.green.shade50;
      text = Colors.green.shade700;
      label = "$stock Units";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _navigateToAddEdit(BuildContext context, {String? productId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditProductScreen(productId: productId)),
    );
    _fetchProducts();
  }
}