import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String imageUrl; // Maps to 'image' in DB
  final bool isActive;
  final int themeColor; // Stored as int (ARGB) in DB
  final List<SubCategory> subCategories;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.isActive = true,
    this.themeColor = 0xFFFFFFFF, // Default to opaque white
    this.subCategories = const [],
    this.createdAt,
  });

  // Helper to get Color object safely
  Color get color {
    // If 0, return white to avoid invisible backgrounds
    if (themeColor == 0) return Colors.white;
    return Color(themeColor);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': imageUrl, // DB expects 'image'
      'isActive': isActive,
      'themeColor': themeColor,
      'subCategories': subCategories.map((s) => s.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      // Robust fallback for image key
      imageUrl: data['image'] ?? data['imageUrl'] ?? '',
      isActive: data['isActive'] ?? true,
      // Parse themeColor safely
      themeColor: (data['themeColor'] is int) ? data['themeColor'] : 0xFFFFFFFF,
      subCategories: (data['subCategories'] as List<dynamic>?)
          ?.map((e) => SubCategory.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SubCategory {
  final String name;
  final String imageUrl;
  final String offer;

  SubCategory({
    required this.name,
    required this.imageUrl,
    required this.offer,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': imageUrl,
      'offer': offer,
    };
  }

  factory SubCategory.fromMap(Map<String, dynamic> data) {
    return SubCategory(
      name: data['name'] ?? '',
      imageUrl: data['image'] ?? '',
      offer: data['offer'] ?? '',
    );
  }
}