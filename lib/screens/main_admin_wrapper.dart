import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:senditadmin/screens/setting_screen.dart';
import '../models/app_user.dart';
import '../models/services/admin_service.dart';
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
              // Pass UID to the error screen for debugging (logged to console)
              return _buildAccessDenied(context, "User profile not found in 'staff' collection.", currentUser.uid);
            }

            return _ResponsiveAdminLayout(user: adminUser);
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(BuildContext context, String message, String uid) {
    // Log the ID to the console for the developer
    debugPrint("ACCESS DENIED - REQUIRED FIRESTORE DOC ID: $uid");

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_outlined, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text("Access Denied", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const Text(
                "Please contact your administrator or check the console for the required Document ID.",
                style: TextStyle(fontSize: 12, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              OutlinedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text("Logout"),
              ),
            ],
          ),
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
    // 1. Build Primary Navigation Menu (Bottom Nav / Sidebar)
    final List<Map<String, dynamic>> menuItems = [];

    // Dashboard
    if (widget.user.canViewAnalytics) {
      menuItems.add({
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'page': const DashboardScreen()
      });
    }

    // Orders
    if (widget.user.canViewOrders) {
      menuItems.add({
        'icon': Icons.receipt_long_rounded,
        'label': 'Orders',
        'page': const OrderListScreen()
      });
    }

    // Inventory
    if (widget.user.canManageInventory) {
      menuItems.add({
        'icon': Icons.inventory_2_rounded,
        'label': 'Products',
        'page': const ProductListScreen()
      });
      menuItems.add({
        'icon': Icons.category_rounded,
        'label': 'Categories',
        'page': const CategoryListScreen()
      });
    }

    // POS
    if (widget.user.canPerformPos) {
      menuItems.add({
        'icon': Icons.point_of_sale_rounded,
        'label': 'POS Terminal',
        'page': const PosScreen()
      });
    }

    // 2. Handle Zero Permissions
    if (menuItems.isEmpty) {
      return const Scaffold(body: Center(child: Text("No access.")));
    }

    // 3. Reset Index Safety
    if (_selectedIndex >= menuItems.length) {
      _selectedIndex = 0;
    }

    // 4. Responsive Layout Builder
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        if (!isDesktop) {
          // --- MOBILE LAYOUT ---
          return Scaffold(
            appBar: AppBar(
              title: Text(menuItems[_selectedIndex]['label']),
              // Ensure the drawer icon appears
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            // DRAWER: Contains Profile & Settings ONLY
            drawer: Drawer(
              child: Column(
                children: [
                  _buildDrawerHeader(),
                  // Settings Tile in Drawer
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user))
                      );
                    },
                  ),
                  const Spacer(),
                  _buildLogoutTile(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // BODY: Selected Page
            body: menuItems[_selectedIndex]['page'],
            // BOTTOM NAV: Primary Navigation
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed, // Ensure >3 items show labels
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              items: menuItems.map((item) => BottomNavigationBarItem(
                icon: Icon(item['icon']),
                label: item['label'],
              )).toList(),
            ),
          );
        }

        // --- DESKTOP LAYOUT (Unchanged, Sidebar works best here) ---
        // Add Settings to sidebar for desktop consistency if desired,
        // or keep it separate. I'll add it to the sidebar for desktop UX.
        final desktopMenuItems = List<Map<String, dynamic>>.from(menuItems);
        desktopMenuItems.add({
          'icon': Icons.settings_rounded,
          'label': 'Settings',
          'page': SettingsScreen(user: widget.user)
        });

        // Adjust index for desktop list if we were on a page that exists in mobile but index shifted
        int desktopIndex = _selectedIndex;
        if (desktopIndex >= desktopMenuItems.length) desktopIndex = 0;

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: _isExtended,
                backgroundColor: Colors.white,
                selectedIndex: desktopIndex,
                onDestinationSelected: (int index) {
                  // Map desktop index back to mobile index logic if needed,
                  // but for simple switching we just update state.
                  // Note: Switching from Desktop Settings (last item) to Mobile
                  // might cause index out of bounds if not careful, handled by the reset check above.
                  setState(() => _selectedIndex = index);
                },
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
                destinations: desktopMenuItems.map((item) => NavigationRailDestination(
                  icon: Icon(item['icon']),
                  label: Text(item['label']),
                )).toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(desktopMenuItems[desktopIndex]['label'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            radius: 18,
                            child: Text(
                              widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: desktopMenuItems[desktopIndex]['page']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: Colors.indigo),
      accountName: Text(widget.user.name),
      accountEmail: Text(widget.user.email),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'A',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
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