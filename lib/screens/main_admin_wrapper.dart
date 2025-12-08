import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senditadmin/screens/setting_screen.dart';
import '../models/app_user.dart';
import '../models/services/admin_service.dart';
import '../models/services/dashboard_screen.dart';
import 'Login_screen.dart';
import 'RiderManagementScreen.dart';
import 'pos_screen.dart';
import 'product_list_screen.dart';
import 'category_list_screen.dart';
import 'order_list_screen.dart';

class MainAdminWrapper extends StatelessWidget {
  const MainAdminWrapper({super.key});

  static void openDrawer(BuildContext context) {
    context.findAncestorStateOfType<_ResponsiveAdminLayoutState>()?.openDrawer();
  }

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

        final currentUser = authSnapshot.data!;

        return StreamBuilder<AdminUser?>(
          stream: AdminService().getCurrentUserStream(currentUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final adminUser = userSnapshot.data;

            if (adminUser == null) {
              return _buildAccessDenied(context, "User profile not found.", currentUser.uid);
            }

            return _ResponsiveAdminLayout(user: adminUser);
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context, String message, String uid) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text("Access Denied", style: TextStyle(fontSize: 20)),
            OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text("Logout")),
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isExtended = true;

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // --- UPDATED MENU ITEMS ---
    final List<Map<String, dynamic>> menuItems = [];

    if (widget.user.canViewAnalytics) {
      menuItems.add({'icon': Icons.dashboard, 'label': 'Dashboard', 'page': const DashboardScreen()});
    }
    if (widget.user.canViewOrders) {
      menuItems.add({'icon': Icons.receipt, 'label': 'Orders', 'page': const OrderListScreen()});
    }
    if (widget.user.canManageInventory) {
      menuItems.add({'icon': Icons.inventory, 'label': 'Products', 'page': const ProductListScreen()});
      menuItems.add({'icon': Icons.category, 'label': 'Categories', 'page': const CategoryListScreen()});
    }
    // Added Rider Management (assuming anyone with inventory access can also manage riders for now)
    if (widget.user.canManageInventory) {
      menuItems.add({'icon': Icons.motorcycle, 'label': 'Riders', 'page': const RiderManagementScreen()});
    }
    if (widget.user.canPerformPos) {
      menuItems.add({'icon': Icons.point_of_sale, 'label': 'POS', 'page': const PosScreen()});
    }

    if (menuItems.isEmpty) return const Scaffold(body: Center(child: Text("No Access")));
    if (_selectedIndex >= menuItems.length) _selectedIndex = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (!isDesktop) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              child: Column(
                children: [
                  _buildDrawerHeader(),
                  ...menuItems.asMap().entries.map((e) => ListTile(
                    leading: Icon(e.value['icon']),
                    title: Text(e.value['label']),
                    selected: _selectedIndex == e.key,
                    onTap: () {
                      setState(() => _selectedIndex = e.key);
                      Navigator.pop(context);
                    },
                  )),
                  const Spacer(),
                  ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user)))),
                  ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: () => FirebaseAuth.instance.signOut()),
                ],
              ),
            ),
            body: menuItems[_selectedIndex]['page'],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex > 4 ? 0 : _selectedIndex, // Safety check
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              items: menuItems.take(5).map((e) => BottomNavigationBarItem(icon: Icon(e['icon']), label: e['label'])).toList(),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: _isExtended,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                leading: Column(
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.local_shipping, size: 40, color: Theme.of(context).primaryColor),
                    if (_isExtended) const Text("SendIt Admin", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                  ],
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: IconButton(icon: Icon(_isExtended ? Icons.chevron_left : Icons.chevron_right), onPressed: () => setState(() => _isExtended = !_isExtended)),
                    ),
                  ),
                ),
                destinations: menuItems.map((e) => NavigationRailDestination(icon: Icon(e['icon']), label: Text(e['label']))).toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: menuItems[_selectedIndex]['page']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      accountName: Text(widget.user.name),
      accountEmail: Text(widget.user.email),
      currentAccountPicture: CircleAvatar(child: Text(widget.user.name[0])),
    );
  }
}