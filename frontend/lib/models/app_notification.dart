import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String itemId;
  final String itemName;
  final Map<String, dynamic>? actionData;
  final DateTime timestamp;
  final String householdId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.itemId,
    required this.itemName,
    this.actionData,
    required this.timestamp,
    required this.householdId,
    this.isRead = false,
  });

  // Check if this is a grouped notification
  bool get isGrouped => type.endsWith('_grouped');

  // Get item count for grouped notifications
  int get itemCount => actionData?['itemCount'] ?? 1;

  Color getColor(BuildContext context) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  IconData getIcon() {
    switch (type) {
      case 'low_stock':
      case 'low_stock_grouped':
        return Icons.inventory_2_rounded;
      case 'expiry':
      case 'expiry_grouped':
        return Icons.calendar_today_rounded;
      case 'recommendation':
        return Icons.auto_awesome_rounded;
      case 'shopping_list':
        return Icons.shopping_cart_rounded;
      case 'usage_tip':
        return Icons.lightbulb_rounded;
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String getTypeLabel() {
    switch (type) {
      case 'low_stock':
      case 'low_stock_grouped':
        return 'Stock Alert';
      case 'expiry':
      case 'expiry_grouped':
        return 'Expiry Alert';
      case 'recommendation':
        return 'Recommendation';
      case 'shopping_list':
        return 'Shopping List';
      case 'usage_tip':
        return 'Usage Tip';
      case 'system':
        return 'System';
      default:
        return 'Notification';
    }
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'itemId': itemId,
      'itemName': itemName,
      'actionData': actionData,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'householdId': householdId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          householdId == other.householdId;

  @override
  int get hashCode => id.hashCode ^ householdId.hashCode;
}
