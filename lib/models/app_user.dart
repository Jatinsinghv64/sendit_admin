class AdminUser {
  final String uid;
  final String email;
  final String name;
  final String role;
  final Map<String, bool> permissions;

  AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
  });

  factory AdminUser.fromMap(Map<String, dynamic> data, String uid) {
    // 1. Safely parse the permissions map from Firestore
    final Map<String, bool> parsedPermissions = {};

    if (data['permissions'] != null && data['permissions'] is Map) {
      final rawMap = data['permissions'] as Map<dynamic, dynamic>;
      rawMap.forEach((key, value) {
        parsedPermissions[key.toString()] = value == true;
      });
    }

    return AdminUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? 'Staff',
      role: data['role'] ?? 'staff',
      permissions: parsedPermissions,
    );
  }

  // 2. Getters that map directly to your Firestore keys
  bool get canManageInventory => permissions['manage_inventory'] ?? false;
  bool get canPerformPos => permissions['perform_pos'] ?? false;
  bool get canViewAnalytics => permissions['view_analytics'] ?? false;
  bool get canViewOrders => permissions['view_orders'] ?? false;
}