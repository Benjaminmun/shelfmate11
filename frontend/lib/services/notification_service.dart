// notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  final List<AppNotification> _notifications = [];
  final List<VoidCallback> _listeners = [];
  final Set<String> _processedRecommendations = {};

  // Stream controller for real-time notifications
  final _notificationStreamController =
      StreamController<List<AppNotification>>.broadcast();

  // Overlay entry for popup notifications
  OverlayEntry? _notificationOverlay;
  bool _isOverlayShowing = false;

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
    _notificationStreamController.add(List.unmodifiable(_notifications));
  }

  Stream<List<AppNotification>> get notificationStream =>
      _notificationStreamController.stream;

  // 🎯 CREATE NOTIFICATION FROM RECOMMENDATION
  void createRecommendationNotification(Map<String, dynamic> recommendation) {
    final type = recommendation['type'] as String? ?? '';
    final priority = recommendation['priority'] as String? ?? 'medium';
    final itemId = recommendation['itemId'] as String? ?? '';
    final itemName = recommendation['itemName'] as String? ?? 'Unknown Item';
    final title = recommendation['title'] as String? ?? '';
    final message = recommendation['message'] as String? ?? '';

    final notificationKey = '${itemId}_${type}_$priority';

    if (!_processedRecommendations.contains(notificationKey)) {
      final notificationType = _getNotificationTypeFromRecommendation(type);
      final notificationMessage = _getNotificationMessage(
        type,
        message,
        itemName,
        recommendation,
      );

      final notification = AppNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}_$notificationKey',
        title: title,
        message: notificationMessage,
        type: notificationType,
        priority: priority,
        itemId: itemId,
        itemName: itemName,
        actionData: recommendation,
        timestamp: DateTime.now(),
      );

      _addNotification(notification);
      _processedRecommendations.add(notificationKey);

      // Show immediate popup for high priority notifications
      if (priority == 'high') {
        _showImmediateNotificationPopup(notification);
      }
    }
  }

  // 🎯 CREATE MANUAL NOTIFICATION
  void createManualNotification({
    required String title,
    required String message,
    required String type,
    String priority = 'medium',
    String? itemId,
    String? itemName,
    Map<String, dynamic>? actionData,
  }) {
    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_manual',
      title: title,
      message: message,
      type: type,
      priority: priority,
      itemId: itemId ?? '',
      itemName: itemName ?? 'System',
      actionData: actionData,
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    // Show popup for high priority manual notifications
    if (priority == 'high') {
      _showImmediateNotificationPopup(notification);
    }
  }

  // 🎯 CREATE LOW STOCK NOTIFICATION
  void createLowStockNotification({
    required String itemId,
    required String itemName,
    required int currentQuantity,
    required int minStockLevel,
  }) {
    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_low_stock_$itemId',
      title: 'Low Stock Alert',
      message:
          '$itemName is running low! Current: $currentQuantity, Minimum: $minStockLevel',
      type: 'low_stock',
      priority: currentQuantity <= 2 ? 'high' : 'medium',
      itemId: itemId,
      itemName: itemName,
      actionData: {
        'type': 'low_stock',
        'currentQuantity': currentQuantity,
        'minStockLevel': minStockLevel,
      },
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (currentQuantity <= 2) {
      _showImmediateNotificationPopup(notification);
    }
  }

  // 🎯 CREATE EXPIRY NOTIFICATION
  void createExpiryNotification({
    required String itemId,
    required String itemName,
    required int daysUntilExpiry,
  }) {
    String priority = 'medium';
    String title = 'Item Expiring Soon';

    if (daysUntilExpiry <= 0) {
      priority = 'high';
      title = '🚨 Item Expired!';
    } else if (daysUntilExpiry <= 3) {
      priority = 'high';
      title = 'Item Expiring Soon!';
    }

    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_expiry_$itemId',
      title: title,
      message: daysUntilExpiry <= 0
          ? '$itemName has expired! Please dispose of it.'
          : '$itemName expires in $daysUntilExpiry days.',
      type: 'expiry',
      priority: priority,
      itemId: itemId,
      itemName: itemName,
      actionData: {'type': 'expiry', 'daysUntilExpiry': daysUntilExpiry},
      timestamp: DateTime.now(),
    );

    _addNotification(notification);

    if (priority == 'high') {
      _showImmediateNotificationPopup(notification);
    }
  }

  // 🎯 CREATE SHOPPING LIST NOTIFICATION
  void createShoppingListNotification({
    required String itemName,
    required int quantity,
    String priority = 'medium',
  }) {
    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_shopping_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Added to Shopping List',
      message: 'Added $quantity $itemName to your shopping list',
      type: 'shopping_list',
      priority: priority,
      itemId: '',
      itemName: itemName,
      actionData: {'type': 'shopping_list', 'quantity': quantity},
      timestamp: DateTime.now(),
    );

    _addNotification(notification);
  }

  // 🎯 PRIVATE METHODS
  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // Add to beginning for newest first
    _notifyListeners();
    _saveNotificationToFirestore(notification);
  }

  Future<void> _saveNotificationToFirestore(
    AppNotification notification,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'id': notification.id,
            'title': notification.title,
            'message': notification.message,
            'type': notification.type,
            'priority': notification.priority,
            'itemId': notification.itemId,
            'itemName': notification.itemName,
            'actionData': notification.actionData,
            'timestamp': Timestamp.fromDate(notification.timestamp),
            'isRead': notification.isRead,
            'userId': user.uid,
          });
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  String _getNotificationTypeFromRecommendation(String recommendationType) {
    if (recommendationType.contains('stock')) return 'low_stock';
    if (recommendationType.contains('expiry')) return 'expiry';
    if (recommendationType.contains('usage')) return 'usage_tip';
    return 'recommendation';
  }

  String _getNotificationMessage(
    String type,
    String message,
    String itemName,
    Map<String, dynamic> recommendation,
  ) {
    if (type.contains('expiry')) {
      final daysUntilExpiry = recommendation['daysUntilExpiry'];
      if (daysUntilExpiry is int) {
        if (daysUntilExpiry <= 0) {
          return '$itemName has expired!';
        } else if (daysUntilExpiry <= 3) {
          return '$itemName expires in $daysUntilExpiry days!';
        }
      }
    }
    return message;
  }

  // 🎯 NOTIFICATION POPUP MANAGEMENT
  void _showImmediateNotificationPopup(AppNotification notification) {
    if (_isOverlayShowing) {
      _removeNotificationOverlay();
    }

    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: NotificationPopup(
          notification: notification,
          onDismiss: _removeNotificationOverlay,
          onTap: () {
            _removeNotificationOverlay();
            _handleNotificationAction(notification);
          },
        ),
      ),
    );

    final overlayState = Overlay.of(navigatorKey.currentContext!);
    overlayState.insert(_notificationOverlay!);
    _isOverlayShowing = true;

    // Auto-dismiss after 5 seconds
    Future.delayed(Duration(seconds: 5), _removeNotificationOverlay);
  }

  void _removeNotificationOverlay() {
    if (_isOverlayShowing) {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
      _isOverlayShowing = false;
    }
  }

  // 🎯 NOTIFICATION ACTIONS
  void _handleNotificationAction(AppNotification notification) {
    // Mark as read
    markAsRead(notification.id);

    // Handle different notification types
    switch (notification.type) {
      case 'low_stock':
      case 'recommendation':
        _handleRecommendationAction(notification);
        break;
      case 'expiry':
        _handleExpiryAction(notification);
        break;
      case 'shopping_list':
        _handleShoppingListAction(notification);
        break;
      default:
        // Default action - navigate to inventory
        _navigateToInventory();
    }
  }

  void _handleRecommendationAction(AppNotification notification) {
    if (notification.actionData != null) {
      // This would typically trigger a callback to your parent widget
      // to handle the recommendation action
      _showActionSnackbar(
        'Handling recommendation for ${notification.itemName}',
      );
    } else {
      _navigateToItem(notification.itemId);
    }
  }

  void _handleExpiryAction(AppNotification notification) {
    _navigateToItem(notification.itemId);
    _showActionSnackbar('Viewing expiry details for ${notification.itemName}');
  }

  void _handleShoppingListAction(AppNotification notification) {
    _navigateToShoppingList();
    _showActionSnackbar('Opening shopping list');
  }

  void _navigateToItem(String itemId) {
    // This would typically use a navigation callback
    _showActionSnackbar('Navigating to item details');
  }

  void _navigateToInventory() {
    // This would typically use a navigation callback
    _showActionSnackbar('Opening inventory');
  }

  void _navigateToShoppingList() {
    // This would typically use a navigation callback
    _showActionSnackbar('Opening shopping list');
  }

  void _showActionSnackbar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }

  // 🎯 PUBLIC METHODS
  void dismissNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notifyListeners();
    _deleteNotificationFromFirestore(notificationId);
  }

  Future<void> _deleteNotificationFromFirestore(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .where('id', isEqualTo: notificationId)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting notification from Firestore: $e');
    }
  }

  void dismissAllNotifications() {
    _notifications.clear();
    _processedRecommendations.clear();
    _notifyListeners();
    _clearAllNotificationsFromFirestore();
  }

  Future<void> _clearAllNotificationsFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing notifications from Firestore: $e');
    }
  }

  void markAsRead(String notificationId) {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification not found'),
    );

    notification.isRead = true;
    _notifyListeners();
    _updateNotificationReadStatus(notificationId, true);
  }

  Future<void> _updateNotificationReadStatus(
    String notificationId,
    bool isRead,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .where('id', isEqualTo: notificationId)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.update({'isRead': isRead});
      }
    } catch (e) {
      print('Error updating notification read status: $e');
    }
  }

  void markAllAsRead() {
    for (final notification in _notifications) {
      notification.isRead = true;
    }
    _notifyListeners();
    _markAllNotificationsReadInFirestore();
  }

  Future<void> _markAllNotificationsReadInFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // 🎯 LOAD NOTIFICATIONS FROM FIRESTORE
  Future<void> loadNotificationsFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _notifications.clear();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final notification = AppNotification(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          type: data['type'] ?? 'info',
          priority: data['priority'] ?? 'medium',
          itemId: data['itemId'] ?? '',
          itemName: data['itemName'] ?? '',
          actionData: data['actionData'] != null
              ? Map<String, dynamic>.from(data['actionData'])
              : null,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isRead: data['isRead'] ?? false,
        );
        _notifications.add(notification);
      }

      _notifyListeners();
    } catch (e) {
      print('Error loading notifications from Firestore: $e');
    }
  }

  // 🎯 CLEANUP METHODS
  void clearExpiredNotifications() {
    final now = DateTime.now();
    final expiredNotifications = _notifications
        .where(
          (notification) => now.difference(notification.timestamp).inDays > 30,
        )
        .toList();

    for (final notification in expiredNotifications) {
      _notifications.remove(notification);
      _deleteNotificationFromFirestore(notification.id);
    }

    _notifyListeners();
  }

  void clearProcessedRecommendation(
    String itemId,
    String type,
    String priority,
  ) {
    final recommendationKey = '${itemId}_${type}_$priority';
    _processedRecommendations.remove(recommendationKey);
  }

  // 🎯 GETTERS
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get totalCount => _notifications.length;

  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<AppNotification> get highPriorityNotifications =>
      _notifications.where((n) => n.priority == 'high').toList();

  // 🎯 DISPOSE
  void dispose() {
    _removeNotificationOverlay();
    _notificationStreamController.close();
    _listeners.clear();
  }
}

// 🎯 NOTIFICATION MODEL
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
    this.isRead = false,
  });

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
        return Icons.inventory_2_rounded;
      case 'expiry':
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
        return 'Stock Alert';
      case 'expiry':
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
}

// 🎯 NOTIFICATION POPUP WIDGET
class NotificationPopup extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const NotificationPopup({
    Key? key,
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.getColor(context).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.getIcon(),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🎯 NOTIFICATION ICON WIDGET
class NotificationIcon extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onPressed;
  final Color warningColor;
  final Color primaryColor;

  const NotificationIcon({
    Key? key,
    required this.notifications,
    required this.onPressed,
    required this.warningColor,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: unreadCount > 0
                ? warningColor.withOpacity(0.1)
                : primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              unreadCount > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_rounded,
              size: 22,
            ),
            onPressed: onPressed,
            tooltip: '$unreadCount unread notifications',
            color: unreadCount > 0 ? warningColor : primaryColor,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: warningColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// 🎯 NOTIFICATIONS PANEL WIDGET
class NotificationsPanel extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onDismissPanel;
  final Function(String) onDismissNotification;
  final Function(AppNotification) onTapNotification;
  final Color surfaceColor;
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color backgroundColor;

  const NotificationsPanel({
    Key? key,
    required this.notifications,
    required this.onDismissPanel,
    required this.onDismissNotification,
    required this.onTapNotification,
    required this.surfaceColor,
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (notifications.isEmpty)
              _buildEmptyState()
            else
              _buildNotificationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_rounded, color: primaryColor, size: 20),
          SizedBox(width: 8),
          Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textPrimary,
              fontSize: 16,
            ),
          ),
          if (unreadCount > 0) ...[
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          Spacer(),
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => NotificationService().markAllAsRead(),
              child: Text(
                'Mark All Read',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18),
            onPressed: onDismissPanel,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.notifications_off_rounded, size: 48, color: textLight),
          SizedBox(height: 12),
          Text(
            'No Notifications',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'You\'re all caught up!',
            style: TextStyle(color: textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: notifications.length,
        itemBuilder: (context, index) => NotificationItem(
          notification: notifications[index],
          onDismiss: () => onDismissNotification(notifications[index].id),
          onTap: () => onTapNotification(notifications[index]),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textLight: textLight,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

// 🎯 NOTIFICATION ITEM WIDGET
class NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color backgroundColor;

  const NotificationItem({
    Key? key,
    required this.notification,
    required this.onDismiss,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: backgroundColor, width: 1),
            ),
            color: notification.isRead
                ? Colors.transparent
                : backgroundColor.withOpacity(0.3),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: notification.getColor(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.getIcon(),
                  color: notification.getColor(context),
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: notification.getColor(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: notification
                                .getColor(context)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notification.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: notification.getColor(context),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          notification.getTypeLabel(),
                          style: TextStyle(fontSize: 10, color: textLight),
                        ),
                        Spacer(),
                        Text(
                          _formatTimeAgo(notification.timestamp),
                          style: TextStyle(color: textLight, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 24, height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// 🎯 GLOBAL NAVIGATOR KEY (Add this to your main.dart)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
