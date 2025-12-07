import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/category.dart';
import '../models/services/admin_service.dart';
import 'add_edit_category_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Cool Grey 100
      body: SafeArea(
        child: StreamBuilder<List<Category>>(
          stream: _service.getCategoriesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allCategories = snapshot.data ?? [];
            final filteredCategories = _filterCategories(allCategories);

            return RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Header
                  SliverToBoxAdapter(
                    child: _buildHeader(allCategories.length),
                  ),

                  // 2. Search Bar
                  SliverToBoxAdapter(
                    child: _buildSearchControl(),
                  ),

                  // 3. Category Grid
                  if (filteredCategories.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text("No categories found", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.65, // Taller to fit controls
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            return _buildCategoryCard(filteredCategories[index]);
                          },
                          childCount: filteredCategories.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(context),
        backgroundColor: const Color(0xFF4338CA),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW CATEGORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  List<Category> _filterCategories(List<Category> categories) {
    if (_searchQuery.isEmpty) return categories;
    return categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
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
              Text(
                "Categories",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              SizedBox(height: 4),
              Text(
                "Manage store sections",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Text(
              "$count Active",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA), fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search categories...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    final Color themeColor = category.color;
    final bool isWhite = category.themeColor == 0xFFFFFFFF;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToAddEdit(context, category: category),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Header
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(color: themeColor.withOpacity(0.1)),
                    if (category.imageUrl.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          category.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => Center(
                            child: Icon(Icons.broken_image, color: Colors.grey.shade300),
                          ),
                        ),
                      )
                    else
                      const Center(child: Icon(Icons.image, color: Colors.grey)),

                    // Edit Indicator
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 14, color: Colors.black87),
                      ),
                    )
                  ],
                ),
              ),

              // 2. Details & Management
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${category.subCategories.length} Sub-categories",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),

                      const Divider(height: 12),

                      // Status Toggle & Delete
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status Switch
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 35,
                                child: Switch(
                                  value: category.isActive,
                                  onChanged: (val) => _toggleStatus(category, val),
                                  activeColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.isActive ? "Active" : "Off",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: category.isActive ? Colors.green : Colors.grey
                                ),
                              ),
                            ],
                          ),

                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDelete(category),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(Category category, bool newStatus) async {
    HapticFeedback.selectionClick();
    await _service.updateCategoryStatus(category.id, newStatus);
  }

  Future<void> _confirmDelete(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text("Are you sure you want to delete '${category.name}'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Category deleted")));
      }
    }
  }

  Future<void> _navigateToAddEdit(BuildContext context, {Category? category}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditCategoryScreen(category: category)),
    );
  }
}