import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/services/admin_service.dart';
import '../models/services/dashboard_screen.dart'; // Updated Dashboard import
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

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        return StreamBuilder<AdminUser?>(
          stream: AdminService().getCurrentUserStream(authSnapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final adminUser = roleSnapshot.data;

            if (adminUser == null) {
              return _buildAccessDenied(context);
            }

            return _ResponsiveAdminLayout(user: adminUser);
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text("Access Denied", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("You do not have staff privileges.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            OutlinedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveAdminLayout extends StatefulWidget {
  final AdminUser user;
  const _ResponsiveAdminLayout({required this.user});

  @override
  State<_ResponsiveAdminLayout> createState() => _ResponsiveAdminLayoutState();
}

class _ResponsiveAdminLayoutState extends State<_ResponsiveAdminLayout> {
  int _selectedIndex = 0;
  bool _isExtended = true;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [];

    // --- RBAC Navigation Logic ---
    if (widget.user.canViewAnalytics) {
      menuItems.add({'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'page': const DashboardScreen()});
    }
    menuItems.add({'icon': Icons.receipt_long_rounded, 'label': 'Orders', 'page': const OrderListScreen()});

    if (widget.user.canManageInventory) {
      menuItems.add({'icon': Icons.inventory_2_rounded, 'label': 'Products', 'page': const ProductListScreen()});
      menuItems.add({'icon': Icons.category_rounded, 'label': 'Categories', 'page': const CategoryListScreen()});
    }

    if (widget.user.canPerformPos) {
      menuItems.add({'icon': Icons.point_of_sale_rounded, 'label': 'POS Terminal', 'page': const PosScreen()});
    }

    if (_selectedIndex >= menuItems.length) _selectedIndex = 0;

    // Use LayoutBuilder to switch between Mobile Drawer and Desktop Sidebar
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (!isDesktop) {
          // Mobile/Tablet View (Bottom Nav or Drawer)
          return Scaffold(
            appBar: AppBar(
              title: Text(menuItems[_selectedIndex]['label']),
              actions: [_buildUserAvatar()],
            ),
            drawer: Drawer(
              child: Column(
                children: [
                  _buildDrawerHeader(),
                  Expanded(
                    child: ListView(
                      children: List.generate(menuItems.length, (index) {
                        return ListTile(
                          leading: Icon(menuItems[index]['icon']),
                          title: Text(menuItems[index]['label']),
                          selected: _selectedIndex == index,
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ),
                  ),
                  _buildLogoutTile(),
                ],
              ),
            ),
            body: menuItems[_selectedIndex]['page'],
          );
        }

        // Desktop View (Permanent Sidebar)
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: _isExtended,
                backgroundColor: Colors.white,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
                leading: Column(
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.local_shipping_rounded, size: 40, color: Theme.of(context).primaryColor),
                    if (_isExtended) ...[
                      const SizedBox(height: 10),
                      const Text("SendIt Admin", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: IconButton(
                        icon: Icon(_isExtended ? Icons.chevron_left : Icons.chevron_right),
                        onPressed: () => setState(() => _isExtended = !_isExtended),
                      ),
                    ),
                  ),
                ),
                destinations: menuItems.map((item) => NavigationRailDestination(
                  icon: Icon(item['icon']),
                  label: Text(item['label']),
                )).toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    // Desktop Top Bar
                    Container(
                      height: 60,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(menuItems[_selectedIndex]['label'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none)),
                              const SizedBox(width: 16),
                              _buildUserAvatar(),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: menuItems[_selectedIndex]['page']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar() {
    return PopupMenuButton(
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'logout', child: Text("Logout")),
      ],
      onSelected: (val) {
        if (val == 'logout') FirebaseAuth.instance.signOut();
      },
      child: CircleAvatar(
        backgroundColor: Colors.indigo.shade50,
        child: Text(widget.user.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: Colors.indigo),
      accountName: Text(widget.user.name),
      accountEmail: Text(widget.user.email),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(widget.user.name[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text("Logout", style: TextStyle(color: Colors.red)),
      onTap: () => FirebaseAuth.instance.signOut(),
    );
  }
}