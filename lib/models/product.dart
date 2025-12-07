import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final String sku;
  final bool isActive;
  final int stockQty; // Helper accessor
  final List<String> searchKeywords;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.sku = '',
    this.isActive = true,
    this.stockQty = 0,
    this.searchKeywords = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'sku': sku,
      'isActive': isActive,
      'stock': {'availableQty': stockQty}, // Nested stock for scalability
      'searchKeywords': searchKeywords,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      categoryId: data['categoryId'] ?? '',
      sku: data['sku'] ?? '',
      isActive: data['isActive'] ?? true,
      stockQty: data['stock']?['availableQty'] ?? 0,
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
    );
  }

  // Helper to generate keywords for search
  static List<String> generateKeywords(String title) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < title.length; i++) {
      temp = temp + title[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }
}