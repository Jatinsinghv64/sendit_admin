import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/inventory_model.dart';
import '../models/services/admin_service.dart';

// Screens
import '../models/services/dashboard_screen.dart';
import 'Login_screen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'category_list_screen.dart';
import 'order_list_screen.dart';

class MainAdminWrapper extends StatelessWidget {
  const MainAdminWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          return const LoginScreen();
        }

        // Fetch Staff Profile from 'staff' collection
        return StreamBuilder<AdminUser?>(
          stream: AdminService().getCurrentUserStream(firebaseUser.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final adminUser = roleSnapshot.data;

            // SECURITY CHECK:
            // If user is authenticated but has no document in 'staff' collection,
            // they are NOT authorized to access the Admin Panel.
            if (adminUser == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        "Access Denied",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Your account is not authorized as Staff.\nPlease contact your administrator.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _AdminLayout(user: adminUser);
          },
        );
      },
    );
  }
}

class _AdminLayout extends StatefulWidget {
  final AdminUser user;
  const _AdminLayout({required this.user});

  @override
  State<_AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<_AdminLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationRailDestination>[];
    final pages = <Widget>[];

    // 1. Dashboard (Admins Only)
    if (widget.user.canViewAnalytics) {
      destinations.add(const NavigationRailDestination(
          icon: Icon(Icons.dashboard), label: Text('Dashboard')
      ));
      pages.add(const DashboardScreen());
    }

    // 2. Inventory (Admins & Managers)
    if (widget.user.canManageInventory) {
      destinations.add(const NavigationRailDestination(
          icon: Icon(Icons.inventory), label: Text('Products')
      ));
      pages.add(const ProductListScreen());

      destinations.add(const NavigationRailDestination(
          icon: Icon(Icons.category), label: Text('Categories')
      ));
      pages.add(const CategoryListScreen());
    }

    // 3. Orders (Everyone)
    destinations.add(const NavigationRailDestination(
        icon: Icon(Icons.receipt), label: Text('Orders')
    ));
    pages.add(const OrderListScreen());

    // 4. POS (Cashiers & Admins)
    if (widget.user.canPerformPos) {
      destinations.add(const NavigationRailDestination(
          icon: Icon(Icons.point_of_sale), label: Text('POS')
      ));
      pages.add(const PosScreen());
    }

    // Safety check
    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.user.name}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: "Logout",
          )
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
            leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(child: Icon(Icons.person)),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}