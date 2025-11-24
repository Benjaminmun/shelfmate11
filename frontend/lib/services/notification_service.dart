// notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/inventory_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 🔒 PERSISTENT NOTIFICATION TRACKING
  late SharedPreferences _prefs;
  final Map<String, Set<String>> _dismissedNotifications = {};
  final Map<String, Set<String>> _readNotifications = {};

  // Track already notified items to prevent duplicates
  final Map<String, Set<String>> _notifiedLowStockItems = {};
  final Map<String, Set<String>> _notifiedExpiryItems = {};
  final Map<String, Set<String>> _notifiedExpiredItems = {};

  // Stream controller for real-time notifications
  final _notificationStreamController =
      StreamController<List<AppNotification>>.broadcast();

  // Overlay entry for popup notifications
  OverlayEntry? _notificationOverlay;
  bool _isOverlayShowing = false;

  // Current household context
  String? _currentHouseholdId;

  // 🆕 DEBOUNCE TIMER TO PREVENT RAPID DUPLICATES
  Timer? _refreshDebounceTimer;

  // 🎯 INITIALIZE PERSISTENT STORAGE
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistentTracking();
    } catch (e) {
      print('Error initializing NotificationService: $e');
      // Initialize with empty tracking if loading fails
      _dismissedNotifications.clear();
      _readNotifications.clear();
      _notifiedLowStockItems.clear();
      _notifiedExpiryItems.clear();
      _notifiedExpiredItems.clear();
    }
  }

  // 🎯 SET CURRENT HOUSEHOLD CONTEXT
  void setCurrentHousehold(String householdId) {
    _currentHouseholdId = householdId;
    // When switching households, ensure we have the dismissed set for this household
    _dismissedNotifications.putIfAbsent(householdId, () => {});
    _readNotifications.putIfAbsent(householdId, () => {});
  }

  // 🔒 LOAD PERSISTENT TRACKING DATA - ENHANCED
  Future<void> _loadPersistentTracking() async {
    try {
      // Load dismissed notifications using JSON for better structure
      final dismissedJson =
          _prefs.getString('dismissed_notifications_json') ?? '{}';
      final dismissedMap = Map<String, dynamic>.from(
        json.decode(dismissedJson),
      );

      _dismissedNotifications.clear();
      dismissedMap.forEach((householdId, notificationIds) {
        if (notificationIds is List) {
          _dismissedNotifications[householdId] = Set<String>.from(
            notificationIds,
          );
        }
      });

      // Load read notifications using JSON for better structure
      final readJson = _prefs.getString('read_notifications_json') ?? '{}';
      final readMap = Map<String, dynamic>.from(json.decode(readJson));

      _readNotifications.clear();
      readMap.forEach((householdId, notificationIds) {
        if (notificationIds is List) {
          _readNotifications[householdId] = Set<String>.from(notificationIds);
        }
      });

      print(
        'Loaded ${_dismissedNotifications.length} households with dismissed notifications',
      );
      print(
        'Loaded ${_readNotifications.length} households with read notifications',
      );

      // Load item tracking
      await _loadItemTracking();
    } catch (e) {
      print('Error loading persistent tracking: $e');
      // Initialize empty tracking if loading fails
      _dismissedNotifications.clear();
      _readNotifications.clear();
      _notifiedLowStockItems.clear();
      _notifiedExpiryItems.clear();
      _notifiedExpiredItems.clear();
    }
  }

  // 🔒 SAVE PERSISTENT TRACKING DATA - ENHANCED
  Future<void> _savePersistentTracking() async {
    try {
      // Save dismissed notifications using JSON for better structure
      final dismissedMap = _dismissedNotifications.map(
        (k, v) => MapEntry(k, v.toList()),
      );
      await _prefs.setString(
        'dismissed_notifications_json',
        json.encode(dismissedMap),
      );

      // Save read notifications using JSON for better structure
      final readMap = _readNotifications.map((k, v) => MapEntry(k, v.toList()));
      await _prefs.setString('read_notifications_json', json.encode(readMap));

      print(
        'Saved ${_dismissedNotifications.length} households with dismissed notifications',
      );
      print(
        'Saved ${_readNotifications.length} households with read notifications',
      );

      // Save item tracking
      await _saveItemTracking();
    } catch (e) {
      print('Error saving persistent tracking: $e');
    }
  }

  // 🔒 ITEM TRACKING PERSISTENCE
  Future<void> _loadItemTracking() async {
    try {
      final lowStockData = _prefs.getString('low_stock_tracking') ?? '{}';
      final expiryData = _prefs.getString('expiry_tracking') ?? '{}';
      final expiredData = _prefs.getString('expired_tracking') ?? '{}';

      final lowStockMap = Map<String, dynamic>.from(json.decode(lowStockData));
      final expiryMap = Map<String, dynamic>.from(json.decode(expiryData));
      final expiredMap = Map<String, dynamic>.from(json.decode(expiredData));

      _notifiedLowStockItems.clear();
      _notifiedExpiryItems.clear();
      _notifiedExpiredItems.clear();

      lowStockMap.forEach((householdId, items) {
        if (items is List) {
          _notifiedLowStockItems[householdId] = Set<String>.from(items);
        }
      });

      expiryMap.forEach((householdId, items) {
        if (items is List) {
          _notifiedExpiryItems[householdId] = Set<String>.from(items);
        }
      });

      expiredMap.forEach((householdId, items) {
        if (items is List) {
          _notifiedExpiredItems[householdId] = Set<String>.from(items);
        }
      });
    } catch (e) {
      print('Error loading item tracking: $e');
      // Initialize empty tracking if loading fails
      _notifiedLowStockItems.clear();
      _notifiedExpiryItems.clear();
      _notifiedExpiredItems.clear();
    }
  }

  Future<void> _saveItemTracking() async {
    try {
      final lowStockMap = _notifiedLowStockItems.map(
        (k, v) => MapEntry(k, v.toList()),
      );
      final expiryMap = _notifiedExpiryItems.map(
        (k, v) => MapEntry(k, v.toList()),
      );
      final expiredMap = _notifiedExpiredItems.map(
        (k, v) => MapEntry(k, v.toList()),
      );

      await _prefs.setString('low_stock_tracking', json.encode(lowStockMap));
      await _prefs.setString('expiry_tracking', json.encode(expiryMap));
      await _prefs.setString('expired_tracking', json.encode(expiredMap));

      print('Saved item tracking: ${lowStockMap.length} households');
    } catch (e) {
      print('Error saving item tracking: $e');
    }
  }

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

  // 🎯 ENHANCED NOTIFICATION CHECK WITH BETTER DEDUPLICATION
  void checkInventoryNotifications(
    List<InventoryItem> items,
    String householdId,
  ) {
    if (householdId.isEmpty) {
      print('Error: Household ID is empty');
      return;
    }

    final now = DateTime.now();

    // Initialize household tracking if needed
    _notifiedLowStockItems[householdId] ??= {};
    _notifiedExpiryItems[householdId] ??= {};
    _notifiedExpiredItems[householdId] ??= {};

    // 🆕 TRACK CURRENT STATE TO DETECT CHANGES
    final currentLowStockItems = <String>{};
    final currentExpiringItems = <String>{};
    final currentExpiredItems = <String>{};

    for (final item in items) {
      final itemId = item.id ?? '';
      if (itemId.isEmpty) continue;

      final minStock = item.minStockLevel ?? 5;
      if (item.quantity <= minStock) {
        currentLowStockItems.add(itemId);
      }

      if (item.expiryDate != null) {
        final daysUntilExpiry = item.expiryDate!.difference(now).inDays;
        if (daysUntilExpiry <= 0) {
          currentExpiredItems.add(itemId);
        } else if (daysUntilExpiry <= 3) {
          currentExpiringItems.add(itemId);
        }
      }
    }

    // 🆕 CLEANUP STALE TRACKING ENTRIES
    _cleanupStaleTracking(
      householdId,
      currentLowStockItems,
      currentExpiringItems,
      currentExpiredItems,
    );

    // Filter items that should be notified
    final filteredItems = items
        .where((item) => _shouldNotifyItem(item, householdId))
        .toList();

    // Group items by notification type
    final lowStockItems = <InventoryItem>[];
    final expiringSoonItems = <InventoryItem>[];
    final expiredItems = <InventoryItem>[];

    for (final item in filteredItems) {
      final itemId = item.id ?? '';
      if (itemId.isEmpty) continue;

      // Check low stock
      final minStock = item.minStockLevel ?? 5;
      if (item.quantity <= minStock) {
        lowStockItems.add(item);
      }

      // Check expiry
      if (item.expiryDate != null) {
        final daysUntilExpiry = item.expiryDate!.difference(now).inDays;
        if (daysUntilExpiry <= 0) {
          expiredItems.add(item);
        } else if (daysUntilExpiry <= 3) {
          expiringSoonItems.add(item);
        }
      }
    }

    // Create grouped notifications
    _createGroupedLowStockNotification(lowStockItems, householdId);
    _createGroupedExpiryNotification(
      expiringSoonItems,
      expiredItems,
      householdId,
    );

    // 🆕 SAVE TRACKING AFTER PROCESSING
    _saveItemTracking();
  }

  // 🆕 DEBOUNCED REFRESH TO PREVENT RAPID DUPLICATES
  void debouncedCheckInventoryNotifications(
    List<InventoryItem> items,
    String householdId, {
    Duration delay = const Duration(seconds: 2),
  }) {
    // Cancel previous timer
    _refreshDebounceTimer?.cancel();

    // Start new timer
    _refreshDebounceTimer = Timer(delay, () {
      checkInventoryNotifications(items, householdId);
    });
  }

  // 🆕 MANUAL REFRESH WITH CLEAR TRACKING
  void forceRefreshNotifications(
    List<InventoryItem> items,
    String householdId,
  ) {
    // Clear any pending debounced checks
    _refreshDebounceTimer?.cancel();

    // Clear tracking for this household to force re-evaluation
    _notifiedLowStockItems[householdId]?.clear();
    _notifiedExpiryItems[householdId]?.clear();
    _notifiedExpiredItems[householdId]?.clear();

    // Perform fresh check
    checkInventoryNotifications(items, householdId);
  }

  // 🆕 CLEANUP STALE TRACKING ENTRIES
  void _cleanupStaleTracking(
    String householdId,
    Set<String> currentLowStock,
    Set<String> currentExpiring,
    Set<String> currentExpired,
  ) {
    // Remove items from tracking that no longer meet criteria
    _notifiedLowStockItems[householdId]?.removeWhere(
      (itemId) => !currentLowStock.contains(itemId),
    );

    _notifiedExpiryItems[householdId]?.removeWhere(
      (itemId) => !currentExpiring.contains(itemId),
    );

    _notifiedExpiredItems[householdId]?.removeWhere(
      (itemId) => !currentExpired.contains(itemId),
    );
  }

  // 🎯 ENHANCED SHOULD NOTIFY CHECK WITH STATE VALIDATION
  bool _shouldNotifyItem(InventoryItem item, String householdId) {
    final itemId = item.id ?? '';
    if (itemId.isEmpty || householdId.isEmpty) {
      return true; // Always notify if fields are invalid
    }

    // Initialize tracking sets
    _notifiedLowStockItems[householdId] ??= {};
    _notifiedExpiryItems[householdId] ??= {};
    _notifiedExpiredItems[householdId] ??= {};

    // Check current conditions
    final minStock = item.minStockLevel ?? 5;
    final isLowStock = item.quantity <= minStock;
    final now = DateTime.now();
    final daysUntilExpiry = item.expiryDate?.difference(now).inDays ?? 999;
    final isExpiringSoon = daysUntilExpiry <= 3 && daysUntilExpiry > 0;
    final isExpired = daysUntilExpiry <= 0;

    // Check if item was previously notified
    final wasLowStockNotified = _notifiedLowStockItems[householdId]!.contains(
      itemId,
    );
    final wasExpiryNotified = _notifiedExpiryItems[householdId]!.contains(
      itemId,
    );
    final wasExpiredNotified = _notifiedExpiredItems[householdId]!.contains(
      itemId,
    );

    // 🆕 IF ITEM WAS NEVER NOTIFIED AND MEETS CRITERIA, NOTIFY
    if (!wasLowStockNotified && !wasExpiryNotified && !wasExpiredNotified) {
      return isLowStock || isExpiringSoon || isExpired;
    }

    // 🆕 IF ITEM CONDITION IMPROVED, REMOVE FROM TRACKING
    if (wasLowStockNotified && !isLowStock) {
      _notifiedLowStockItems[householdId]!.remove(itemId);
      return false;
    }

    if (wasExpiryNotified && !isExpiringSoon && !isExpired) {
      _notifiedExpiryItems[householdId]!.remove(itemId);
      return false;
    }

    if (wasExpiredNotified && !isExpired) {
      _notifiedExpiredItems[householdId]!.remove(itemId);
      return false;
    }

    // 🆕 ONLY NOTIFY IF CONDITION WORSENED OR CHANGED TYPE
    final conditionWorsened =
        (wasLowStockNotified &&
            isLowStock &&
            item.quantity < _getPreviousQuantity(itemId, householdId)) ||
        (wasExpiryNotified && isExpired) || // Changed from expiring to expired
        (wasExpiredNotified && isExpired); // Still expired

    return conditionWorsened;
  }

  // 🆕 TRACK PREVIOUS QUANTITY FOR COMPARISON
  double _getPreviousQuantity(String itemId, String householdId) {
    // You might want to store previous quantities for comparison
    // For now, return a high value to avoid false positives
    return double.maxFinite;
  }

  // 🎯 ENHANCED GROUPED NOTIFICATION WITH BETTER DEDUPLICATION
  void _createGroupedLowStockNotification(
    List<InventoryItem> items,
    String householdId,
  ) {
    if (items.isEmpty || householdId.isEmpty) return;

    // Filter out already notified items
    final newItems = items.where((item) {
      final itemId = item.id ?? '';
      return itemId.isNotEmpty &&
          !_notifiedLowStockItems[householdId]!.contains(itemId);
    }).toList();

    if (newItems.isEmpty) return;

    // 🆕 CREATE STABLE NOTIFICATION ID BASED ON CONTENT
    final itemsHash = newItems
        .map((item) => item.id ?? '')
        .where((id) => id.isNotEmpty)
        .join('_');
    final notificationId =
        'low_stock_${householdId}_${_generateStableHash(itemsHash)}';

    // Check if this exact notification was already created
    if (_notificationExists(notificationId) ||
        _isNotificationDismissed(notificationId, householdId)) {
      print(
        'Notification $notificationId already exists or dismissed - skipping',
      );
      return;
    }

    final itemCount = newItems.length;
    final isSingle = itemCount == 1;

    String title;
    String message;

    if (isSingle) {
      final item = newItems.first;
      title = '📦 Low Stock Alert';
      message =
          '${item.name} is running low (${item.quantity} left). Minimum stock: ${item.minStockLevel ?? 5}';
    } else {
      title = '📦 Low Stock: $itemCount Items';
      message = '$itemCount items are running low and need restocking.';
    }

    final notification = AppNotification(
      id: notificationId,
      title: title,
      message: message,
      type: 'low_stock_grouped',
      priority: 'medium',
      itemId: '', // Empty for grouped notifications
      itemName: isSingle ? newItems.first.name : '$itemCount items',
      actionData: {
        'type': 'low_stock_grouped',
        'householdId': householdId,
        'items': newItems
            .where((item) => item.id != null)
            .map(
              (item) => {
                'id': item.id,
                'name': item.name,
                'quantity': item.quantity,
                'minStockLevel': item.minStockLevel,
                'category': item.category,
              },
            )
            .toList(),
        'itemCount': itemCount,
      },
      timestamp: DateTime.now(),
      householdId: householdId,
    );

    _addNotification(notification);

    // Mark items as notified
    for (final item in newItems) {
      if (item.id != null) {
        _notifiedLowStockItems[householdId]!.add(item.id!);
      }
    }

    _saveItemTracking();

    // Show popup for critical low stock (quantity <= 2)
    final criticalItems = newItems.where((item) => item.quantity <= 2).toList();
    if (criticalItems.isNotEmpty) {
      _showImmediateNotificationPopup(notification);
    }
  }

  // 🎯 CREATE GROUPED EXPIRY NOTIFICATION
  void _createGroupedExpiryNotification(
    List<InventoryItem> expiringSoonItems,
    List<InventoryItem> expiredItems,
    String householdId,
  ) {
    if (householdId.isEmpty) return;

    // Filter out already notified items
    final newExpiringSoon = expiringSoonItems.where((item) {
      final itemId = item.id ?? '';
      return itemId.isNotEmpty &&
          !_notifiedExpiryItems[householdId]!.contains(itemId);
    }).toList();

    final newExpired = expiredItems.where((item) {
      final itemId = item.id ?? '';
      return itemId.isNotEmpty &&
          !_notifiedExpiredItems[householdId]!.contains(itemId);
    }).toList();

    if (newExpiringSoon.isEmpty && newExpired.isEmpty) return;

    // Create separate notifications for expiring soon and expired items
    if (newExpiringSoon.isNotEmpty) {
      _createExpiryNotificationByType(
        newExpiringSoon,
        'expiring_soon',
        householdId,
      );
    }

    if (newExpired.isNotEmpty) {
      _createExpiryNotificationByType(newExpired, 'expired', householdId);
    }
  }

  void _createExpiryNotificationByType(
    List<InventoryItem> items,
    String expiryType,
    String householdId,
  ) {
    if (items.isEmpty || householdId.isEmpty) return;

    // 🆕 CREATE STABLE NOTIFICATION ID BASED ON CONTENT
    final itemsHash = items
        .map((item) => item.id ?? '')
        .where((id) => id.isNotEmpty)
        .join('_');
    final notificationId =
        '${expiryType}_${householdId}_${_generateStableHash(itemsHash)}';

    // Check if this exact notification was already created
    if (_notificationExists(notificationId) ||
        _isNotificationDismissed(notificationId, householdId)) {
      print(
        'Notification $notificationId already exists or dismissed - skipping',
      );
      return;
    }

    final itemCount = items.length;
    final isSingle = itemCount == 1;
    final now = DateTime.now();

    String title;
    String message;
    String priority;

    switch (expiryType) {
      case 'expiring_soon':
        title = isSingle
            ? '⚠️ Expiring Soon'
            : '⚠️ $itemCount Items Expiring Soon';
        if (isSingle) {
          final days = items.first.expiryDate!.difference(now).inDays;
          message = '${items.first.name} expires in $days days. Use it soon!';
        } else {
          message =
              '$itemCount items will expire within 3 days. Use them soon!';
        }
        priority = 'high';
        break;
      case 'expired':
        title = isSingle ? '🚨 Item Expired' : '🚨 $itemCount Items Expired';
        message = isSingle
            ? '${items.first.name} has expired! Please dispose of it.'
            : '$itemCount items have expired and need disposal.';
        priority = 'high';
        break;
      default:
        return;
    }

    final notification = AppNotification(
      id: notificationId,
      title: title,
      message: message,
      type: 'expiry_grouped',
      priority: priority,
      itemId: '',
      itemName: isSingle ? items.first.name : '$itemCount items',
      actionData: {
        'type': 'expiry_grouped',
        'expiryType': expiryType,
        'householdId': householdId,
        'items': items.where((item) => item.id != null).map((item) {
          final daysUntilExpiry = item.expiryDate?.difference(now).inDays;
          return {
            'id': item.id,
            'name': item.name,
            'expiryDate': item.expiryDate?.toIso8601String(),
            'daysUntilExpiry': daysUntilExpiry,
            'category': item.category,
          };
        }).toList(),
        'itemCount': itemCount,
      },
      timestamp: DateTime.now(),
      householdId: householdId,
    );

    _addNotification(notification);

    // Mark items as notified
    final notifiedSet = expiryType == 'expired'
        ? _notifiedExpiredItems[householdId]!
        : _notifiedExpiryItems[householdId]!;

    for (final item in items) {
      if (item.id != null) {
        notifiedSet.add(item.id!);
      }
    }

    _saveItemTracking();

    // Always show popup for expiry notifications
    _showImmediateNotificationPopup(notification);
  }

  // 🆕 GENERATE STABLE HASH FOR NOTIFICATION ID
  String _generateStableHash(String input) {
    // Simple hash function for demo - consider using a proper hash in production
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = (hash << 5) - hash + input.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }

  // 🆕 CHECK IF NOTIFICATION ALREADY EXISTS
  bool _notificationExists(String notificationId) {
    return _notifications.any((n) => n.id == notificationId);
  }

  // 🎯 CHECK IF NOTIFICATION IS DISMISSED - ENHANCED WITH HOUSEHOLD CONTEXT
  bool _isNotificationDismissed(String notificationId, String householdId) {
    if (notificationId.isEmpty || householdId.isEmpty) return false;

    // Ensure we have a dismissed set for this household
    _dismissedNotifications.putIfAbsent(householdId, () => {});

    final isDismissed = _dismissedNotifications[householdId]!.contains(
      notificationId,
    );

    // Debug logging
    if (isDismissed) {
      print(
        'DEBUG: Notification $notificationId is DISMISSED for household $householdId',
      );
    }

    return isDismissed;
  }

  // 🎯 CHECK IF NOTIFICATION IS READ
  bool _isNotificationRead(String notificationId, String householdId) {
    if (notificationId.isEmpty || householdId.isEmpty) return false;

    // Ensure we have a read set for this household
    _readNotifications.putIfAbsent(householdId, () => {});

    return _readNotifications[householdId]!.contains(notificationId);
  }

  // 🎯 ENHANCED ADD NOTIFICATION WITH STRONGER DEDUPLICATION
  void _addNotification(AppNotification notification) {
    if (notification.id.isEmpty || notification.householdId.isEmpty) {
      print('Error: Notification missing required fields');
      return;
    }

    // Check if this notification is dismissed for its household
    if (_isNotificationDismissed(notification.id, notification.householdId)) {
      print(
        'Notification ${notification.id} is dismissed for household ${notification.householdId} - skipping',
      );
      return;
    }

    // 🆕 STRONGER DEDUPLICATION CHECK
    final existingIndex = _notifications.indexWhere(
      (n) => n.id == notification.id,
    );

    if (existingIndex != -1) {
      // Update existing notification but preserve read state
      final wasRead = _notifications[existingIndex].isRead;
      _notifications[existingIndex] = notification;
      _notifications[existingIndex].isRead = wasRead;
      print('Updated existing notification: ${notification.id}');
    } else {
      // Set read status from persistent storage
      notification.isRead = _isNotificationRead(
        notification.id,
        notification.householdId,
      );
      _notifications.insert(0, notification);
      print('Added new notification: ${notification.id}');
    }

    _notifyListeners();
    _saveNotificationToFirestore(notification);
  }

  Future<void> _saveNotificationToFirestore(
    AppNotification notification,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 🆕 CHECK IF NOTIFICATION ALREADY EXISTS IN FIRESTORE
      final existingQuery = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .where('id', isEqualTo: notification.id)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing notification
        await existingQuery.docs.first.reference.update({
          'title': notification.title,
          'message': notification.message,
          'type': notification.type,
          'priority': notification.priority,
          'itemId': notification.itemId,
          'itemName': notification.itemName,
          'actionData': notification.actionData,
          'timestamp': Timestamp.fromDate(notification.timestamp),
          'isRead': notification.isRead,
          'householdId': notification.householdId,
        });
        print('Updated notification in Firestore: ${notification.id}');
      } else {
        // Create new notification
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
              'householdId': notification.householdId,
            });
        print('Created new notification in Firestore: ${notification.id}');
      }
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  // 🎯 NOTIFICATION POPUP MANAGEMENT
  void _showImmediateNotificationPopup(AppNotification notification) {
    // Check if navigatorKey is available
    if (navigatorKey.currentContext == null) {
      print('Error: Navigator key not available for showing popup');
      return;
    }

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

    try {
      final overlayState = Overlay.of(navigatorKey.currentContext!);
      overlayState.insert(_notificationOverlay!);
      _isOverlayShowing = true;

      Future.delayed(Duration(seconds: 5), _removeNotificationOverlay);
    } catch (e) {
      print('Error showing notification popup: $e');
      _isOverlayShowing = false;
    }
  }

  void _removeNotificationOverlay() {
    if (_isOverlayShowing && _notificationOverlay != null) {
      try {
        _notificationOverlay!.remove();
        _notificationOverlay = null;
        _isOverlayShowing = false;
      } catch (e) {
        print('Error removing notification overlay: $e');
        _isOverlayShowing = false;
      }
    }
  }

  // 🎯 NOTIFICATION ACTIONS
  void _handleNotificationAction(AppNotification notification) {
    markAsRead(notification.id);

    switch (notification.type) {
      case 'low_stock_grouped':
        _handleGroupedStockAction(notification);
        break;
      case 'expiry_grouped':
        _handleGroupedExpiryAction(notification);
        break;
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
        _navigateToInventory(notification.householdId);
    }
  }

  void _handleGroupedStockAction(AppNotification notification) {
    final householdId = notification.householdId;
    final items = notification.actionData?['items'] ?? [];
    _navigateToLowStockItems(items, householdId);
    _showActionSnackbar('Showing ${notification.itemCount} low stock items');
  }

  void _handleGroupedExpiryAction(AppNotification notification) {
    final householdId = notification.householdId;
    final items = notification.actionData?['items'] ?? [];
    final expiryType = notification.actionData?['expiryType'] ?? '';

    if (expiryType == 'expired') {
      _navigateToExpiredItems(items, householdId);
      _showActionSnackbar('Showing ${notification.itemCount} expired items');
    } else {
      _navigateToExpiringItems(items, householdId);
      _showActionSnackbar('Showing ${notification.itemCount} expiring items');
    }
  }

  void _handleRecommendationAction(AppNotification notification) {
    if (notification.actionData != null) {
      _showActionSnackbar(
        'Handling recommendation for ${notification.itemName}',
      );
    } else {
      _navigateToItem(notification.itemId, notification.householdId);
    }
  }

  void _handleExpiryAction(AppNotification notification) {
    _navigateToItem(notification.itemId, notification.householdId);
    _showActionSnackbar('Viewing expiry details for ${notification.itemName}');
  }

  void _handleShoppingListAction(AppNotification notification) {
    _navigateToShoppingList(notification.householdId);
    _showActionSnackbar('Opening shopping list');
  }

  void _navigateToItem(String itemId, String householdId) {
    _showActionSnackbar('Navigating to item details');
  }

  void _navigateToInventory(String householdId) {
    _showActionSnackbar('Opening inventory');
  }

  void _navigateToShoppingList(String householdId) {
    _showActionSnackbar('Opening shopping list');
  }

  void _navigateToLowStockItems(List<dynamic> items, String householdId) {
    _showActionSnackbar('Showing low stock items');
  }

  void _navigateToExpiringItems(List<dynamic> items, String householdId) {
    _showActionSnackbar('Showing expiring items');
  }

  void _navigateToExpiredItems(List<dynamic> items, String householdId) {
    _showActionSnackbar('Showing expired items');
  }

  void _showActionSnackbar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 🎯 ENHANCED DISMISS NOTIFICATION - FIXED HOUSEHOLD TRACKING
  void dismissNotification(String notificationId) {
    final notificationIndex = _notifications.indexWhere(
      (n) => n.id == notificationId,
    );

    if (notificationIndex == -1) {
      print('Error: Notification not found with ID: $notificationId');
      return;
    }

    final notification = _notifications[notificationIndex];
    final householdId = notification.householdId;

    if (householdId.isEmpty) {
      print('Error: Household ID is empty for notification $notificationId');
      return;
    }

    // Mark as dismissed in persistent storage for the specific household
    _dismissedNotifications[householdId] ??= {};
    _dismissedNotifications[householdId]!.add(notificationId);
    _savePersistentTracking();

    // Remove from local list
    _notifications.removeAt(notificationIndex);
    _notifyListeners();

    print('Dismissed notification $notificationId for household $householdId');
    print(
      'Total dismissed for $householdId: ${_dismissedNotifications[householdId]!.length}',
    );
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
    // Mark all as dismissed in persistent storage for their respective households
    for (final notification in _notifications) {
      final householdId = notification.householdId;
      if (householdId.isNotEmpty) {
        _dismissedNotifications[householdId] ??= {};
        _dismissedNotifications[householdId]!.add(notification.id);
      }
    }
    _savePersistentTracking();

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

  // 🎯 ENHANCED MARK AS READ
  void markAsRead(String notificationId) {
    final notificationIndex = _notifications.indexWhere(
      (n) => n.id == notificationId,
    );

    if (notificationIndex == -1) {
      print('Error: Notification not found with ID: $notificationId');
      return;
    }

    final notification = _notifications[notificationIndex];
    notification.isRead = true;

    // Mark as read in persistent storage for the specific household
    _readNotifications[notification.householdId] ??= {};
    _readNotifications[notification.householdId]!.add(notificationId);
    _savePersistentTracking();

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

  // 🎯 ENHANCED MARK ALL AS READ
  void markAllAsRead() {
    for (final notification in _notifications) {
      notification.isRead = true;

      // Mark as read in persistent storage for the specific household
      _readNotifications[notification.householdId] ??= {};
      _readNotifications[notification.householdId]!.add(notification.id);
    }

    _savePersistentTracking();
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

  // 🎯 ENHANCED LOAD NOTIFICATIONS WITH PERSISTENT STATE
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
          householdId: data['householdId'] ?? '',
        );

        // Apply persistent read state
        notification.isRead = _isNotificationRead(
          notification.id,
          notification.householdId,
        );

        // Only add if not dismissed for this household
        if (!_isNotificationDismissed(
          notification.id,
          notification.householdId,
        )) {
          _notifications.add(notification);
        } else {
          print(
            'Skipping dismissed notification ${notification.id} for household ${notification.householdId}',
          );
        }
      }

      _notifyListeners();
    } catch (e) {
      print('Error loading notifications from Firestore: $e');
    }
  }

  // 🎯 SWITCH HOUSEHOLD - ENHANCED METHOD WITH PERSISTENT TRACKING RELOAD
  Future<void> switchHousehold(String householdId) async {
    if (householdId.isEmpty) return;

    print('=== SWITCHING HOUSEHOLD: $householdId ===');

    // 🔒 CRITICAL FIX: Reload persistent tracking to get latest dismissed notifications
    await _loadPersistentTracking();

    // Set current household context
    setCurrentHousehold(householdId);

    // Ensure we have the dismissed and read sets for this household
    _dismissedNotifications.putIfAbsent(householdId, () => {});
    _readNotifications.putIfAbsent(householdId, () => {});

    // Debug: Print dismissed notifications for this household
    final dismissedCount = _dismissedNotifications[householdId]?.length ?? 0;
    print('Dismissed notifications for $householdId: $dismissedCount');
    if (dismissedCount > 0) {
      print('Dismissed IDs: ${_dismissedNotifications[householdId]!.toList()}');
    }

    // Reload notifications to ensure proper filtering for the current household
    await loadNotificationsFromFirestore();

    print(
      '=== HOUSEHOLD SWITCHED: $householdId (${_notifications.length} notifications) ===',
    );
  }

  // 🎯 DEBUG METHOD TO CHECK DISMISSED NOTIFICATIONS
  void debugDismissedNotifications(String householdId) {
    print('=== DEBUG: Dismissed Notifications for $householdId ===');
    final dismissed = _dismissedNotifications[householdId] ?? {};
    print('Total dismissed: ${dismissed.length}');
    dismissed.forEach((notificationId) {
      print(' - $notificationId');
    });
    print('================================');
  }

  // 🎯 GET CURRENT HOUSEHOLD ID (for debugging)
  String? get currentHouseholdId => _currentHouseholdId;

  // 🎯 EXISTING METHODS (updated with enhanced tracking)
  void createRecommendationNotification(Map<String, dynamic> recommendation) {
    final type = recommendation['type'] as String? ?? '';
    final priority = recommendation['priority'] as String? ?? 'medium';
    final itemId = recommendation['itemId'] as String? ?? '';
    final itemName = recommendation['itemName'] as String? ?? 'Unknown Item';
    final title = recommendation['title'] as String? ?? '';
    final message = recommendation['message'] as String? ?? '';
    final householdId = recommendation['householdId'] as String? ?? '';

    if (householdId.isEmpty) {
      print('Error: Household ID is empty for recommendation notification');
      return;
    }

    final notificationKey = '${itemId}_${type}_$priority';

    if (!_processedRecommendations.contains(notificationKey)) {
      final notificationType = _getNotificationTypeFromRecommendation(type);
      final notificationMessage = _getNotificationMessage(
        type,
        message,
        itemName,
        recommendation,
      );

      // 🆕 USE STABLE NOTIFICATION ID
      final notificationId =
          'recommendation_${householdId}_${_generateStableHash(notificationKey)}';

      // Check if notification was already dismissed for this household
      if (_isNotificationDismissed(notificationId, householdId)) {
        return;
      }

      final notification = AppNotification(
        id: notificationId,
        title: title,
        message: notificationMessage,
        type: notificationType,
        priority: priority,
        itemId: itemId,
        itemName: itemName,
        actionData: recommendation,
        timestamp: DateTime.now(),
        householdId: householdId,
      );

      _addNotification(notification);
      _processedRecommendations.add(notificationKey);

      if (priority == 'high') {
        _showImmediateNotificationPopup(notification);
      }
    }
  }

  void createManualNotification({
    required String title,
    required String message,
    required String type,
    String priority = 'medium',
    String? itemId,
    String? itemName,
    Map<String, dynamic>? actionData,
    required String householdId,
  }) {
    if (householdId.isEmpty) {
      print('Error: Household ID is empty for manual notification');
      return;
    }

    // 🆕 USE STABLE NOTIFICATION ID
    final contentHash = _generateStableHash('$title$message$type$itemId');
    final notificationId = 'manual_${householdId}_$contentHash';

    // Check if notification was already dismissed for this household
    if (_isNotificationDismissed(notificationId, householdId)) {
      return;
    }

    final notification = AppNotification(
      id: notificationId,
      title: title,
      message: message,
      type: type,
      priority: priority,
      itemId: itemId ?? '',
      itemName: itemName ?? 'System',
      actionData: actionData,
      timestamp: DateTime.now(),
      householdId: householdId,
    );

    _addNotification(notification);

    if (priority == 'high') {
      _showImmediateNotificationPopup(notification);
    }
  }

  void createShoppingListNotification({
    required String itemName,
    required int quantity,
    String priority = 'medium',
    required String householdId,
  }) {
    if (householdId.isEmpty) {
      print('Error: Household ID is empty for shopping list notification');
      return;
    }

    // 🆕 USE STABLE NOTIFICATION ID
    final contentHash = _generateStableHash('shopping_$itemName$quantity');
    final notificationId = 'shopping_${householdId}_$contentHash';

    // Check if notification was already dismissed for this household
    if (_isNotificationDismissed(notificationId, householdId)) {
      return;
    }

    final notification = AppNotification(
      id: notificationId,
      title: 'Added to Shopping List',
      message: 'Added $quantity $itemName to your shopping list',
      type: 'shopping_list',
      priority: priority,
      itemId: '',
      itemName: itemName,
      actionData: {'type': 'shopping_list', 'quantity': quantity},
      timestamp: DateTime.now(),
      householdId: householdId,
    );

    _addNotification(notification);
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

  // 🎯 CLEAR ITEM TRACKING WHEN CONDITIONS CHANGE
  void clearItemNotificationTracking(String itemId, String householdId) {
    if (itemId.isEmpty || householdId.isEmpty) return;

    _notifiedLowStockItems[householdId]?.remove(itemId);
    _notifiedExpiryItems[householdId]?.remove(itemId);
    _notifiedExpiredItems[householdId]?.remove(itemId);
    _saveItemTracking();
  }

  // 🎯 CLEAR ALL TRACKING FOR HOUSEHOLD
  void clearHouseholdTracking(String householdId) {
    if (householdId.isEmpty) return;

    _notifiedLowStockItems.remove(householdId);
    _notifiedExpiryItems.remove(householdId);
    _notifiedExpiredItems.remove(householdId);
    _dismissedNotifications.remove(householdId);
    _readNotifications.remove(householdId);
    _savePersistentTracking();
    _saveItemTracking();
  }

  // 🎯 RESET NOTIFICATION TRACKING (for testing or user preference)
  void resetNotificationTracking(String householdId) {
    if (householdId.isEmpty) return;

    clearHouseholdTracking(householdId);

    // Also clear Firestore notifications for this household
    _clearHouseholdNotificationsFromFirestore(householdId);
  }

  Future<void> _clearHouseholdNotificationsFromFirestore(
    String householdId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('user_notifications')
          .doc(user.uid)
          .collection('notifications')
          .where('householdId', isEqualTo: householdId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing household notifications from Firestore: $e');
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

  // 🎯 GETTERS WITH HOUSEHOLD FILTERING
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  List<AppNotification> getNotificationsForHousehold(String householdId) {
    if (householdId.isEmpty) return [];
    return _notifications.where((n) => n.householdId == householdId).toList();
  }

  int getUnreadCountForHousehold(String householdId) {
    if (householdId.isEmpty) return 0;
    return _notifications
        .where((n) => n.householdId == householdId && !n.isRead)
        .length;
  }

  int getTotalCountForHousehold(String householdId) {
    if (householdId.isEmpty) return 0;
    return _notifications.where((n) => n.householdId == householdId).length;
  }

  List<AppNotification> getUnreadNotificationsForHousehold(String householdId) {
    if (householdId.isEmpty) return [];
    return _notifications
        .where((n) => n.householdId == householdId && !n.isRead)
        .toList();
  }

  List<AppNotification> getHighPriorityNotificationsForHousehold(
    String householdId,
  ) {
    if (householdId.isEmpty) return [];
    return _notifications
        .where((n) => n.householdId == householdId && n.priority == 'high')
        .toList();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get totalCount => _notifications.length;

  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<AppNotification> get highPriorityNotifications =>
      _notifications.where((n) => n.priority == 'high').toList();

  // 🎯 DISPOSE
  void dispose() {
    _refreshDebounceTimer?.cancel();
    _removeNotificationOverlay();
    _notificationStreamController.close();
    _listeners.clear();
    _savePersistentTracking();
  }
}

// 🎯 UPDATED NOTIFICATION MODEL
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
  }) : assert(id.isNotEmpty, 'Notification ID cannot be empty'),
       assert(householdId.isNotEmpty, 'Household ID cannot be empty');

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
}

// 🎯 UPDATED NOTIFICATION POPUP WIDGET
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
              _buildNotificationIcon(),
              SizedBox(width: 12),
              Expanded(child: _buildNotificationContent()),
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

  Widget _buildNotificationIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(notification.getIcon(), color: Colors.white, size: 20),
          if (notification.isGrouped && notification.itemCount > 1)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  notification.itemCount > 99
                      ? '99+'
                      : '${notification.itemCount}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationContent() {
    return Column(
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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (notification.isGrouped && notification.itemCount > 1)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tap to view ${notification.itemCount} items',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

// 🎯 UPDATED NOTIFICATION ICON WIDGET
class NotificationIcon extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onPressed;
  final Color warningColor;
  final Color primaryColor;
  final String householdId;

  const NotificationIcon({
    Key? key,
    required this.notifications,
    required this.onPressed,
    required this.warningColor,
    required this.primaryColor,
    required this.householdId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final householdNotifications = notifications
        .where((n) => n.householdId == householdId)
        .toList();
    final unreadCount = householdNotifications.where((n) => !n.isRead).length;

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

// 🎯 UPDATED NOTIFICATIONS PANEL WIDGET
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
  final String householdId;

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
    required this.householdId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final householdNotifications = notifications
        .where((n) => n.householdId == householdId)
        .toList();

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
            _buildHeader(householdNotifications),
            if (householdNotifications.isEmpty)
              _buildEmptyState()
            else
              _buildNotificationsList(householdNotifications),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<AppNotification> householdNotifications) {
    final unreadCount = householdNotifications.where((n) => !n.isRead).length;

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
          if (householdNotifications.isNotEmpty)
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

  Widget _buildNotificationsList(List<AppNotification> householdNotifications) {
    return Container(
      constraints: BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: householdNotifications.length,
        itemBuilder: (context, index) => NotificationItem(
          notification: householdNotifications[index],
          onDismiss: () =>
              onDismissNotification(householdNotifications[index].id),
          onTap: () => onTapNotification(householdNotifications[index]),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textLight: textLight,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

// 🎯 UPDATED NOTIFICATION ITEM WIDGET
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
              _buildNotificationIcon(),
              SizedBox(width: 12),
              Expanded(child: _buildNotificationContent()),
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

  Widget _buildNotificationIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: notification
                .getColor(navigatorKey.currentContext!)
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            notification.getIcon(),
            color: notification.getColor(navigatorKey.currentContext!),
            size: 18,
          ),
        ),
        if (notification.isGrouped && notification.itemCount > 1)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                notification.itemCount > 99
                    ? '99+'
                    : '${notification.itemCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationContent() {
    return Column(
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
                  color: notification.getColor(navigatorKey.currentContext!),
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
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: notification
                    .getColor(navigatorKey.currentContext!)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notification.priority.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: notification.getColor(navigatorKey.currentContext!),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              notification.getTypeLabel(),
              style: TextStyle(fontSize: 10, color: textLight),
            ),
            if (notification.isGrouped)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '• ${notification.itemCount} items',
                  style: TextStyle(fontSize: 10, color: textLight),
                ),
              ),
            Spacer(),
            Text(
              _formatTimeAgo(notification.timestamp),
              style: TextStyle(color: textLight, fontSize: 10),
            ),
          ],
        ),
      ],
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
