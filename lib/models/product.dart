import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String thumbnailUrl;
  final Map<String, dynamic> stock; // {'availableQty': 100, 'unit': 'packets'}
  final String sku; // Stock Keeping Unit / Barcode

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.categoryId,
    required this.thumbnailUrl,
    required this.stock,
    required this.sku,
  });

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: data['categoryId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      stock: data['stock'] ?? {'availableQty': 0, 'unit': 'units'},
      sku: data['sku'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'thumbnailUrl': thumbnailUrl,
      'stock': stock,
      'sku': sku,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}