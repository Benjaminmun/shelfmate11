import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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
      'timestamp': timestamp,
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
    };
  }

  factory InventoryAuditLog.fromMap(Map<String, dynamic> map) {
    return InventoryAuditLog(
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String,
      itemImageUrl: map['itemImageUrl'] as String,
      fieldName: map['fieldName'] as String,
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      updatedByUserId: map['updatedByUserId'] as String,
      updatedByUserName: map['updatedByUserName'] as String,
    );
  }
}