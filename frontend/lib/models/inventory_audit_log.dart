import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Helper method to convert values for Firestore storage
  static dynamic _convertValueForFirestore(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is num) return value;
    if (value is bool) return value;
    return value.toString();
  }

  // Helper method to parse values from Firestore
  static dynamic _parseValueFromFirestore(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return value;
  }

  // Helper method to safely parse timestamp
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  // Utility method to get display string for values
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

  // Method to convert to activity map for UI display
  Map<String, dynamic> toActivityMap() {
    return {
      'type': _getActivityType(),
      'message': _generateActivityMessage(),
      'timestamp': Timestamp.fromDate(timestamp),
      'itemId': itemId,
      'itemName': itemName,
      'itemImage': itemImageUrl,
      'fullName': updatedByFullName,
      'profileImage': '', // You might want to add this field
      'oldValue': oldValue,
      'newValue': newValue,
      'fieldName': fieldName,
    };
  }

  String _getActivityType() {
    if (oldValue == null && newValue != null) return 'add';
    if (oldValue != null && newValue == null) return 'delete';
    return 'update';
  }

  String _generateActivityMessage() {
    final user = updatedByFullName.isNotEmpty ? updatedByFullName : 'A user';
    final item = itemName.isNotEmpty ? itemName : 'an item';
    
    switch (_getActivityType()) {
      case 'add':
        return '$user added $item';
      case 'delete':
        return '$user deleted $item';
      case 'update':
        return '$user updated ${_getFieldDisplayName(fieldName)} for $item';
      default:
        return '$user modified $item';
    }
  }

  String _getFieldDisplayName(String fieldName) {
    switch (fieldName) {
      case 'quantity':
        return 'quantity';
      case 'name':
        return 'name';
      case 'description':
        return 'description';
      case 'category':
        return 'category';
      case 'expiryDate':
        return 'expiry date';
      case 'price':
        return 'price';
      default:
        return fieldName;
    }
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