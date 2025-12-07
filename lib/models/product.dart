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

  // Getter alias for compatibility
  String get thumbnailUrl => imageUrl;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      // Save as 'thumbnail' to match your DB schema
      'thumbnail': imageUrl,
      'thumbnailUrl': imageUrl, // Keep for legacy if needed
      'categoryId': categoryId,
      'sku': sku,
      'isActive': isActive,
      'stock': {'availableQty': stockQty},
      'searchKeywords': searchKeywords,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    // Robust image extraction logic
    String getImage() {
      if (data['thumbnail'] != null && data['thumbnail'].toString().isNotEmpty) {
        return data['thumbnail'];
      }
      if (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().isNotEmpty) {
        return data['thumbnailUrl'];
      }
      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        return data['imageUrl'];
      }
      if (data['images'] != null && (data['images'] as List).isNotEmpty) {
        return data['images'][0].toString();
      }
      return '';
    }

    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: getImage(),
      categoryId: data['categoryId'] ?? '',
      sku: data['sku'] ?? '',
      isActive: data['isActive'] ?? true,
      stockQty: (data['stock'] is Map)
          ? (data['stock']['availableQty'] ?? 0)
          : (data['availableQty'] ?? 0),
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
    );
  }

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