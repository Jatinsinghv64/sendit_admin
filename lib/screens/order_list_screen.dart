import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/order.dart';
import '../models/services/admin_service.dart';
import 'order_detail_screen.dart';
import 'main_admin_wrapper.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'All'; // 'All', 'Pending', 'Processing', 'Delivered', 'Cancelled'

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: StreamBuilder<List<Order>>(
          stream: _service.getOrdersStream(statusFilter: 'all'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allOrders = snapshot.data ?? [];
            final filteredOrders = _filterOrders(allOrders);

            return RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                slivers: [
                  // 1. Header Area
                  SliverToBoxAdapter(
                    child: _buildHeader(allOrders.length, isDesktop),
                  ),

                  // 2. Search & Filters
                  SliverToBoxAdapter(
                    child: _buildControls(),
                  ),

                  // 3. Order List
                  if (filteredOrders.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text("No orders found", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final order = filteredOrders[index];
                            return _buildOrderCard(order);
                          },
                          childCount: filteredOrders.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Filtering Logic ---
  List<Order> _filterOrders(List<Order> orders) {
    String query = _searchController.text.toLowerCase();

    return orders.where((order) {
      bool matchesSearch = order.id.toLowerCase().contains(query);
      if (!matchesSearch) return false;

      if (_activeFilter == 'All') return true;
      return order.status.toLowerCase() == _activeFilter.toLowerCase();
    }).toList();
  }

  // --- UI Components ---

  Widget _buildHeader(int totalOrders, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => MainAdminWrapper.openDrawer(context),
                  ),
                ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Orders",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))
                  ),
                  SizedBox(height: 4),
                  Text(
                      "Manage and track customer orders",
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))
                  ),
                ],
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
              "$totalOrders Total",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA), fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search by Order ID...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Processing'),
                const SizedBox(width: 8),
                _buildFilterChip('Delivered'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled'),
              ],
            ),
          ),
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
        });
        HapticFeedback.lightImpact();
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF4338CA),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade300),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildOrderCard(Order order) {
    final isPos = order.source == 'pos';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "#${order.id.substring(0, 6).toUpperCase()}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPos ? Colors.purple.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isPos ? Colors.purple.shade100 : Colors.blue.shade100),
                          ),
                          child: Text(
                            isPos ? "POS" : "APP",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPos ? Colors.purple : Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(order.createdAt.toDate()),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),

                const Divider(height: 24, color: Color(0xFFF3F4F6)),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${order.items.length} Items",
                            style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Total: ₹${order.total.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Tap to view details",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'delivered':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF047857);
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFB45309);
        icon = Icons.schedule;
        break;
      case 'processing':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        icon = Icons.inventory_2_outlined;
        break;
      case 'cancelled':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        text = const Color(0xFF374151);
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg == const Color(0xFFF3F4F6) ? Colors.grey.shade300 : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}