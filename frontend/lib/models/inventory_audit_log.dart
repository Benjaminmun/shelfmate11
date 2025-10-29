import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:frontend/models/inventory_item_model.dart';
class InventoryAuditLog {
  final String itemId;
  final String itemName;
  final String itemImageUrl;
  final String fieldName;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  final String updatedByUserId;
  final String updatedByUserName;
  final String updatedByFullName;

  InventoryAuditLog({
    required this.itemId,
    required this.itemName,
    required this.itemImageUrl,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.updatedByUserId,
    required this.updatedByUserName,
    required this.updatedByFullName,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemImageUrl': itemImageUrl,
      'fieldName': fieldName,
      'oldValue': _convertValueForFirestore(oldValue),
      'newValue': _convertValueForFirestore(newValue),
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
      'updatedByFullName': updatedByFullName,
    };
  }

  // Convert from Firestore Map
  factory InventoryAuditLog.fromMap(Map<String, dynamic> map, String id) {
    try {
      return InventoryAuditLog(
        itemId: map['itemId'] ?? '',
        itemName: map['itemName'] ?? '',
        itemImageUrl: map['itemImageUrl'] ?? '',
        fieldName: map['fieldName'] ?? '',
        oldValue: _parseValueFromFirestore(map['oldValue']),
        newValue: _parseValueFromFirestore(map['newValue']),
        timestamp: _parseTimestamp(map['timestamp']),
        updatedByUserId: map['updatedByUserId'] ?? '',
        updatedByUserName: map['updatedByUserName'] ?? '',
        updatedByFullName: map['updatedByFullName'] ?? '',
      );
    } catch (e) {
      print('Error parsing InventoryAuditLog: $e');
      rethrow;
    }
  }

  // Helper methods for conversion
  static dynamic _convertValueForFirestore(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is num) return value;
    if (value is bool) return value;
    return value.toString();
  }

  static dynamic _parseValueFromFirestore(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return value;
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  // Displaying values for UI
  String getOldValueDisplay() {
    return _valueToString(oldValue);
  }

  String getNewValueDisplay() {
    return _valueToString(newValue);
  }

  String _valueToString(dynamic value) {
    if (value == null) return 'Not set';
    if (value is DateTime) {
      return '${value.day}/${value.month}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
    }
    if (value is num) return value.toString();
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  @override
  String toString() {
    return 'InventoryAuditLog{\n'
        '  itemId: $itemId,\n'
        '  itemName: $itemName,\n'
        '  fieldName: $fieldName,\n'
        '  oldValue: $oldValue,\n'
        '  newValue: $newValue,\n'
        '  timestamp: $timestamp,\n'
        '  updatedBy: $updatedByFullName\n'
        '}';
  }
}

// 📈 CONSUMPTION AND USAGE MODELS
class CategoryConsumptionProfile {
  final String category;
  final double typicalDailyUsage;
  final double seasonality;
  final double urgencyMultiplier;
  final double minStockLevelMultiplier;
  final double expirySensitivity;
  final ConsumptionPattern consumptionPattern;
  final double priceSensitivity;
  final double bulkPurchaseScore;
  final double emergencyPriority;
  final int lowStockThreshold;
  final int expiryWarningThreshold;

  const CategoryConsumptionProfile({
    required this.category,
    required this.typicalDailyUsage,
    required this.seasonality,
    required this.urgencyMultiplier,
    required this.minStockLevelMultiplier,
    required this.expirySensitivity,
    required this.consumptionPattern,
    required this.priceSensitivity,
    required this.bulkPurchaseScore,
    required this.emergencyPriority,
    required this.lowStockThreshold,
    required this.expiryWarningThreshold,
  });
}

class CategoryConsumptionPattern {
  final String category;
  final double averageConsumptionRate;
  final double consistencyScore;
  final int dataPoints;
  final double adjustmentFactor;

  CategoryConsumptionPattern({
    required this.category,
    required this.averageConsumptionRate,
    required this.consistencyScore,
    required this.dataPoints,
    required this.adjustmentFactor,
  });
}

enum ConsumptionPattern {
  daily,
  regular,
  steady,
  irregular,
  variable,
}

class UsageAnalysis {
  final InventoryItem item;
  final double consumptionRate;
  final double daysOfSupply;
  final double stockoutProbability;
  final double expiryRisk;
  final CategoryConsumptionProfile categoryProfile;
  final DateTime? lastRestockDate;
  final double usageConsistency;
  final int minStockLevel;
  final bool isBelowMinStock;
  final double minStockCompliance;

  UsageAnalysis({
    required this.item,
    required this.consumptionRate,
    required this.daysOfSupply,
    required this.stockoutProbability,
    required this.expiryRisk,
    required this.categoryProfile,
    required this.lastRestockDate,
    required this.usageConsistency,
    required this.minStockLevel,
    required this.isBelowMinStock,
    required this.minStockCompliance,
  });

  Map<String, dynamic> toSummaryMap() {
    return {
      'consumptionRate': consumptionRate,
      'daysOfSupply': daysOfSupply,
      'stockoutProbability': stockoutProbability,
      'expiryRisk': expiryRisk,
      'usageConsistency': usageConsistency,
      'lastRestockDate': lastRestockDate?.toIso8601String(),
      'minStockLevel': minStockLevel,
      'isBelowMinStock': isBelowMinStock,
      'minStockCompliance': minStockCompliance,
    };
  }
}
