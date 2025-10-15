import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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
    required this.createdAt,
    this.updatedAt,
    this.addedByUserId,
    this.addedByUserName,
    this.updatedByUserId,
    this.updatedByUserName,
  });

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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
    };
  }

  static InventoryItem fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      quantity: (map['quantity'] ?? 0).toInt(),
      price: (map['price'] ?? 0.0).toDouble(),
      description: map['description'],
      purchaseDate: map['purchaseDate']?.toDate(),
      expiryDate: map['expiryDate']?.toDate(),
      location: map['location'],
      supplier: map['supplier'],
      barcode: map['barcode'],
      minStockLevel: map['minStockLevel']?.toDouble()?.toInt(), // Cast num? to int?
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] ?? Timestamp.now()).toDate(),
      updatedAt: map['updatedAt']?.toDate(),
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      updatedByUserId: map['updatedByUserId'],
      updatedByUserName: map['updatedByUserName'],
    );
  }

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
    int? minStockLevel, // Now it expects int? directly
    String? imageUrl,
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
      minStockLevel: minStockLevel ?? this.minStockLevel, // minStockLevel is already int?
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
      updatedByUserName: updatedByUserName ?? this.updatedByUserName,
    );
  }
}

class ConsumptionPattern {
  final String itemId;
  final String householdId;
  final double averageDailyUsage;
  final int usageFrequency; // times used per week
  final DateTime lastUsed;
  final DateTime lastRestocked;
  final int typicalRestockQuantity;
  final List<UsageRecord> usageHistory;

  ConsumptionPattern({
    required this.itemId,
    required this.householdId,
    required this.averageDailyUsage,
    required this.usageFrequency,
    required this.lastUsed,
    required this.lastRestocked,
    required this.typicalRestockQuantity,
    required this.usageHistory,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'householdId': householdId,
      'averageDailyUsage': averageDailyUsage,
      'usageFrequency': usageFrequency,
      'lastUsed': lastUsed.millisecondsSinceEpoch,
      'lastRestocked': lastRestocked.millisecondsSinceEpoch,
      'typicalRestockQuantity': typicalRestockQuantity,
      'usageHistory': usageHistory.map((record) => record.toMap()).toList(),
    };
  }

  static ConsumptionPattern fromMap(Map<String, dynamic> map) {
    return ConsumptionPattern(
      itemId: map['itemId'],
      householdId: map['householdId'],
      averageDailyUsage: map['averageDailyUsage'],
      usageFrequency: map['usageFrequency'],
      lastUsed: DateTime.fromMillisecondsSinceEpoch(map['lastUsed']),
      lastRestocked: DateTime.fromMillisecondsSinceEpoch(map['lastRestocked']),
      typicalRestockQuantity: map['typicalRestockQuantity'],
      usageHistory: List<UsageRecord>.from(
          map['usageHistory'].map((x) => UsageRecord.fromMap(x))),
    );
  }
}

class UsageRecord {
  final DateTime timestamp;
  final int quantityChange;
  final String type; // 'used', 'restocked', 'discarded'
  final String? notes;

  UsageRecord({
    required this.timestamp,
    required this.quantityChange,
    required this.type,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'quantityChange': quantityChange,
      'type': type,
      'notes': notes,
    };
  }

  static UsageRecord fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      quantityChange: map['quantityChange'],
      type: map['type'],
      notes: map['notes'],
    );
  }
}

class PredictionResult {
  final String itemId;
  final DateTime predictedDepletionDate;
  final double confidenceScore;
  final int daysUntilEmpty;
  final String recommendation;
  final DateTime calculatedAt;

  PredictionResult({
    required this.itemId,
    required this.predictedDepletionDate,
    required this.confidenceScore,
    required this.daysUntilEmpty,
    required this.recommendation,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'predictedDepletionDate': predictedDepletionDate.millisecondsSinceEpoch,
      'confidenceScore': confidenceScore,
      'daysUntilEmpty': daysUntilEmpty,
      'recommendation': recommendation,
      'calculatedAt': calculatedAt.millisecondsSinceEpoch,
    };
  }

  static PredictionResult fromMap(Map<String, dynamic> map) {
    return PredictionResult(
      itemId: map['itemId'],
      predictedDepletionDate: DateTime.fromMillisecondsSinceEpoch(map['predictedDepletionDate']),
      confidenceScore: map['confidenceScore'],
      daysUntilEmpty: map['daysUntilEmpty'],
      recommendation: map['recommendation'],
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(map['calculatedAt']),
    );
  }
}
