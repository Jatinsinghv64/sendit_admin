import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Enhanced Product Model (Lightweight for lists)
class ProductSummary {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int totalStock; // Aggregate field for fast reads
  final String thumbnailUrl;

  ProductSummary({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.totalStock,
    required this.thumbnailUrl,
  });

  factory ProductSummary.fromMap(Map<String, dynamic> data, String id) {
    return ProductSummary(
      id: id,
      name: data['name'] ?? '',
      sku: data['sku'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      totalStock: data['stock']?['availableQty'] ?? 0, // aggregate
      thumbnailUrl: data['thumbnailUrl'] ?? '',
    );
  }
}

// 2. Batch Model (For FIFO tracking & Expiry)
class ProductBatch {
  final String id;
  final String productId;
  final String batchNumber;
  final int quantity;
  final DateTime? expiryDate;
  final DateTime entryDate;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNumber,
    required this.quantity,
    this.expiryDate,
    required this.entryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'batchNumber': batchNumber,
      'quantity': quantity,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'entryDate': Timestamp.fromDate(entryDate),
    };
  }

  factory ProductBatch.fromMap(Map<String, dynamic> data, String id) {
    return ProductBatch(
      id: id,
      productId: data['productId'] ?? '',
      batchNumber: data['batchNumber'] ?? '',
      quantity: data['quantity'] ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      entryDate: (data['entryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// 3. Inventory Log (Audit Trail)
class InventoryLog {
  final String id;
  final String productId;
  final String action; // 'sale', 'restock', 'correction', 'damage'
  final int quantityChange; // +50 or -5
  final String performedByUserId;
  final DateTime timestamp;

  InventoryLog({
    required this.id,
    required this.productId,
    required this.action,
    required this.quantityChange,
    required this.performedByUserId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'action': action,
      'quantityChange': quantityChange,
      'performedBy': performedByUserId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}