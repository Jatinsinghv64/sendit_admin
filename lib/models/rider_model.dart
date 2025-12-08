import 'package:cloud_firestore/cloud_firestore.dart';

class Rider {
  final String id;
  final String name;
  final String phone;
  final String email; // Login ID
  final String status; // 'available', 'busy', 'offline'
  final double latitude; // For "Nearest" calculation
  final double longitude;
  final int totalDeliveries;

  Rider({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.totalDeliveries,
  });

  factory Rider.fromMap(Map<String, dynamic> data, String id) {
    return Rider(
      id: id,
      name: data['name'] ?? 'Unknown Rider',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'offline',
      // Default to 0.0 if location missing
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: data['totalDeliveries'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'totalDeliveries': totalDeliveries,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}