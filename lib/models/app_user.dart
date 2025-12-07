enum UserRole { superAdmin, manager, cashier, delivery }

class AdminUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  factory AdminUser.fromMap(Map<String, dynamic> data, String uid) {
    return AdminUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? 'Staff',
      role: _parseRole(data['role']),
    );
  }

  static UserRole _parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase()) {
      case 'superadmin': return UserRole.superAdmin;
      case 'manager': return UserRole.manager;
      case 'cashier': return UserRole.cashier;
      case 'delivery': return UserRole.delivery;
      default: return UserRole.cashier; // Default lowest privilege
    }
  }

  bool get canManageInventory => role == UserRole.superAdmin || role == UserRole.manager;
  bool get canViewAnalytics => role == UserRole.superAdmin;
  bool get canPerformPos => role == UserRole.superAdmin || role == UserRole.manager || role == UserRole.cashier;
}