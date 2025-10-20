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
    );
  }
}