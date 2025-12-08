import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../../models/order.dart';
import '../../models/services/admin_service.dart';
import '../../screens/main_admin_wrapper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: StreamBuilder<List<Order>>(
          stream: AdminService().getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data ?? [];

            final double totalRevenue = orders.fold(0.0, (sum, o) => sum + o.total);
            final int pendingOrders = orders.where((o) => o.status == 'pending').length;
            final int delivered = orders.where((o) => o.status == 'delivered').length;
            final int cancelled = orders.where((o) => o.status == 'cancelled').length;

            return RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context, isDesktop),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : 2,
                        childAspectRatio: isDesktop ? 1.5 : 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildStatCard(
                            "Total Revenue",
                            "₹${totalRevenue.toStringAsFixed(0)}",
                            Icons.currency_rupee,
                            Colors.green,
                            Colors.green.shade50
                        ),
                        _buildStatCard(
                            "Pending",
                            "$pendingOrders",
                            Icons.pending_actions,
                            Colors.orange,
                            Colors.orange.shade50
                        ),
                        _buildStatCard(
                            "Delivered",
                            "$delivered",
                            Icons.local_shipping,
                            Colors.indigo,
                            Colors.indigo.shade50
                        ),
                        _buildStatCard(
                            "Cancelled",
                            "$cancelled",
                            Icons.cancel_outlined,
                            Colors.red,
                            Colors.red.shade50
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        "Recent Activity",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ),
                  ),

                  if (orders.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text("No transactions yet", style: TextStyle(color: Colors.grey))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final order = orders[index];
                            return _buildTransactionCard(order);
                          },
                          childCount: orders.take(20).length,
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

  // --- Header Component ---
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  Text("Dashboard", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text("Overview of business performance", style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4338CA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.analytics_outlined, color: Color(0xFF4338CA)),
          ),
        ],
      ),
    );
  }

  // --- Stat Card Component ---
  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Transaction Card Component ---
  Widget _buildTransactionCard(Order order) {
    final bool isPos = order.source == 'pos';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isPos ? Colors.purple.shade50 : Colors.blue.shade50,
          child: Icon(
            isPos ? Icons.storefront : Icons.smartphone_rounded,
            color: isPos ? Colors.purple : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          "Order #${order.id.substring(0, 5).toUpperCase()}",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
        ),
        subtitle: Text(
          "${order.items.length} items • ${order.createdAt.toDate().toString().substring(0, 16)}",
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("₹${order.total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            _buildStatusBadge(order.status),
          ],
        ),
        onTap: () {
          // Add navigation if needed
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bg;
    switch(status.toLowerCase()) {
      case 'delivered': color = Colors.green.shade700; bg = Colors.green.shade50; break;
      case 'pending': color = Colors.orange.shade700; bg = Colors.orange.shade50; break;
      case 'cancelled': color = Colors.red.shade700; bg = Colors.red.shade50; break;
      default: color = Colors.grey.shade700; bg = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
          status.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)
      ),
    );
  }
}