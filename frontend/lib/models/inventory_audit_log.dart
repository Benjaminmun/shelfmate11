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
  final String updatedByFullName; // Add this field

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
    required this.updatedByFullName, // Add this parameter
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemImageUrl': itemImageUrl,
      'fieldName': fieldName,
      'oldValue': oldValue,
      'newValue': newValue,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
      'updatedByFullName': updatedByFullName, // Include in Firestore
    };
  }

  factory InventoryAuditLog.fromMap(Map<String, dynamic> map, String id) {
    return InventoryAuditLog(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      itemImageUrl: map['itemImageUrl'] ?? '',
      fieldName: map['fieldName'] ?? '',
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      updatedByUserId: map['updatedByUserId'] ?? '',
      updatedByUserName: map['updatedByUserName'] ?? '',
      updatedByFullName: map['updatedByFullName'] ?? '', // Extract from Firestore
    );
  }
}