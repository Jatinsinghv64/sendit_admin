import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/inventory_model.dart';
import '../models/services/admin_service.dart';

import '../models/services/dashboard_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'category_list_screen.dart';
import 'order_list_screen.dart';

class MainAdminWrapper extends StatelessWidget {
  const MainAdminWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not Authorized")));
    }

    return StreamBuilder<AdminUser?>(
      stream: AdminService().getCurrentUserStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If no user doc found, default to lowest role or show error.
        // For development, you might default to Admin if database is empty.
        final user = snapshot.data ?? AdminUser(uid: uid, email: '', name: 'Staff', role: UserRole.cashier);

        return _buildRoleBasedUI(context, user);
      },
    );
  }

  Widget _buildRoleBasedUI(BuildContext context, AdminUser user) {
    List<Widget> pages = [];
    List<NavigationRailDestination> destinations = [];

    // 1. Dashboard (Admins)
    if (user.canViewAnalytics) {
      pages.add(const DashboardScreen());
      destinations.add(const NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')));
    }

    // 2. Inventory (Managers)
    if (user.canManageInventory) {
      pages.add(const ProductListScreen());
      destinations.add(const NavigationRailDestination(icon: Icon(Icons.inventory), label: Text('Products')));

      pages.add(const CategoryListScreen());
      destinations.add(const NavigationRailDestination(icon: Icon(Icons.category), label: Text('Categories')));
    }

    // 3. Orders (Everyone)
    pages.add(const OrderListScreen());
    destinations.add(const NavigationRailDestination(icon: Icon(Icons.receipt), label: Text('Orders')));

    // 4. POS (Cashiers+)
    if (user.canPerformPos) {
      pages.add(const PosScreen());
      destinations.add(const NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('POS')));
    }

    return _AdminScaffold(pages: pages, destinations: destinations);
  }
}

class _AdminScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<NavigationRailDestination> destinations;
  const _AdminScaffold({required this.pages, required this.destinations});

  @override
  State<_AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<_AdminScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Basic safety check if role changed and index is out of bounds
    if (_selectedIndex >= widget.pages.length) _selectedIndex = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: widget.destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.pages[_selectedIndex]),
        ],
      ),
    );
  }
}