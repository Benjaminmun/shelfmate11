import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Represents an item stored in the inventory.
class InventoryItem {
  final String? id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? description;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? location;
  final String? supplier;
  final String? barcode;
  final int? minStockLevel;
  final String? imageUrl;
  final String? localImagePath; // ✅ Added for locally stored image support
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? addedByUserId;
  final String? addedByUserName;
  final String? updatedByUserId;
  final String? updatedByUserName;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.description,
    this.purchaseDate,
    this.expiryDate,
    this.location,
    this.supplier,
    this.barcode,
    this.minStockLevel,
    this.imageUrl,
    this.localImagePath, // ✅ Included in constructor
    required this.createdAt,
    this.updatedAt,
    this.addedByUserId,
    this.addedByUserName,
    this.updatedByUserId,
    this.updatedByUserName,
  });

  /// Converts object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'description': description,
      'purchaseDate': purchaseDate,
      'expiryDate': expiryDate,
      'location': location,
      'supplier': supplier,
      'barcode': barcode,
      'minStockLevel': minStockLevel,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath, // ✅ Added to map
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
    };
  }

  /// Converts Firestore document into InventoryItem object
  static InventoryItem fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      quantity: (map['quantity'] ?? 0).toInt(),
      price: (map['price'] ?? 0.0).toDouble(),
      description: map['description'],
      purchaseDate: map['purchaseDate'] is Timestamp
          ? (map['purchaseDate'] as Timestamp).toDate()
          : map['purchaseDate'],
      expiryDate: map['expiryDate'] is Timestamp
          ? (map['expiryDate'] as Timestamp).toDate()
          : map['expiryDate'],
      location: map['location'],
      supplier: map['supplier'],
      barcode: map['barcode'],
      minStockLevel: map['minStockLevel']?.toInt(),
      imageUrl: map['imageUrl'],
      localImagePath: map['localImagePath'], // ✅ Added here
      createdAt: (map['createdAt'] ?? Timestamp.now()).toDate(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'],
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      updatedByUserId: map['updatedByUserId'],
      updatedByUserName: map['updatedByUserName'],
    );
  }

  /// Copy existing item and change only selected fields
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? location,
    String? supplier,
    String? barcode,
    int? minStockLevel,
    String? imageUrl,
    String? localImagePath, // ✅ Added
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedByUserId,
    String? addedByUserName,
    String? updatedByUserId,
    String? updatedByUserName,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      location: location ?? this.location,
      supplier: supplier ?? this.supplier,
      barcode: barcode ?? this.barcode,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath, // ✅ Added
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
      updatedByUserName: updatedByUserName ?? this.updatedByUserName,
    );
  }
}

/// Represents a usage record for a specific inventory item.
class UsageRecord {
  final DateTime date;
  final int amountUsed;

  UsageRecord({
    required this.date,
    required this.amountUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'amountUsed': amountUsed,
    };
  }

  static UsageRecord fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.parse(map['date']),
      amountUsed: (map['amountUsed'] ?? 0).toInt(),
    );
  }
}

/// Represents the pattern of consumption for predictive analysis.
class ConsumptionPattern {
  final double averageDailyUse;
  final double usageVariance;
  final DateTime lastUsedDate;
  final List<UsageRecord> usageHistory;

  ConsumptionPattern({
    required this.averageDailyUse,
    required this.usageVariance,
    required this.lastUsedDate,
    required this.usageHistory,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageDailyUse': averageDailyUse,
      'usageVariance': usageVariance,
      'lastUsedDate': lastUsedDate,
      'usageHistory': usageHistory.map((u) => u.toMap()).toList(),
    };
  }

  static ConsumptionPattern fromMap(Map<String, dynamic> map) {
    return ConsumptionPattern(
      averageDailyUse: (map['averageDailyUse'] ?? 0.0).toDouble(),
      usageVariance: (map['usageVariance'] ?? 0.0).toDouble(),
      lastUsedDate: map['lastUsedDate'] is Timestamp
          ? (map['lastUsedDate'] as Timestamp).toDate()
          : DateTime.parse(map['lastUsedDate']),
      usageHistory: (map['usageHistory'] as List<dynamic>? ?? [])
          .map((u) => UsageRecord.fromMap(Map<String, dynamic>.from(u)))
          .toList(),
    );
  }
}

/// Represents a predicted result such as restock date or shortage alert.
class PredictionResult {
  final DateTime predictedRestockDate;
  final bool isLowStock;
  final String recommendation;

  PredictionResult({
    required this.predictedRestockDate,
    required this.isLowStock,
    required this.recommendation,
  });

  Map<String, dynamic> toMap() {
    return {
      'predictedRestockDate': predictedRestockDate,
      'isLowStock': isLowStock,
      'recommendation': recommendation,
    };
  }

  static PredictionResult fromMap(Map<String, dynamic> map) {
    return PredictionResult(
      predictedRestockDate: map['predictedRestockDate'] is Timestamp
          ? (map['predictedRestockDate'] as Timestamp).toDate()
          : DateTime.parse(map['predictedRestockDate']),
      isLowStock: map['isLowStock'] ?? false,
      recommendation: map['recommendation'] ?? '',
    );
  }
}
