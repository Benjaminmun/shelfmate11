// notification_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/analytics_service.dart';
import 'package:frontend/services/inventory_service.dart';
import 'package:frontend/services/ml_prediction_service.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Request permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initializationSettings);

    // Handle background messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // Token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    // Save token to user document in Firestore for cloud messaging
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'inventory_channel',
      'Inventory Notifications',
      channelDescription: 'Notifications for inventory management',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails();

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Inventory Alert',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
    );
  }

  // Smart notification methods
  Future<void> scheduleRestockReminder(String householdId, String itemId, String itemName, DateTime remindDate) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'restock_reminder',
      'Restock Reminders',
      channelDescription: 'Reminders to restock items',
      importance: Importance.high,
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails();

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _localNotifications.zonedSchedule(
      itemId.hashCode,
      'Time to Restock',
      '$itemName is running low. Consider restocking soon.',
      tz.TZDateTime.from(remindDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> checkAndNotifyLowStock(String householdId) async {
    final mlService = MLPredictionService();
    final predictions = await mlService.predictAllItems(householdId);

    for (final prediction in predictions) {
      if (prediction.daysUntilEmpty <= 3) {
        // Critical - notify immediately
        await _showLocalNotification(RemoteMessage(
          notification: RemoteNotification(
            title: '🔄 Time to Restock',
            body: '${prediction.itemId} will run out in ${prediction.daysUntilEmpty} days',
          ),
        ));

        // Schedule reminder for tomorrow if still critical
        if (prediction.daysUntilEmpty <= 1) {
          await scheduleRestockReminder(
            householdId,
            prediction.itemId,
            prediction.itemId, // You might want to fetch the actual name
            DateTime.now().add(Duration(days: 1)),
          );
        }
      } else if (prediction.daysUntilEmpty <= 7) {
        // Warning - schedule notification
        await scheduleRestockReminder(
          householdId,
          prediction.itemId,
          prediction.itemId,
          DateTime.now().add(Duration(days: prediction.daysUntilEmpty - 2)),
        );
      }
    }
  }

  Future<void> notifyExpiringItems(String householdId) async {
    final inventoryService = InventoryService();
    final expiringStream = inventoryService.getExpiringSoonItemsStream(householdId, days: 3);

    // This would need to be adapted for stream handling
    // For now, we'll create a simple check
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory')
        .where('expiryDate', isLessThanOrEqualTo: DateTime.now().add(Duration(days: 3)))
        .where('expiryDate', isGreaterThan: DateTime.now())
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final itemName = data['name'] as String? ?? 'Unknown Item';
      final expiryDate = (data['expiryDate'] as Timestamp).toDate();
      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

      await _showLocalNotification(RemoteMessage(
        notification: RemoteNotification(
          title: '⏰ Item Expiring Soon',
          body: '$itemName expires in $daysUntilExpiry days',
        ),
      ));
    }
  }

  // Weekly summary notification
  Future<void> sendWeeklySummary(String householdId) async {
    final analyticsService = AnalyticsService();
    final trends = await analyticsService.getConsumptionTrends(householdId, days: 7);

    final lowStockCount = trends['lowStockItems'] as int? ?? 0;
    final totalValue = trends['totalValue'] as double? ?? 0;

    await _showLocalNotification(RemoteMessage(
      notification: RemoteNotification(
        title: '📊 Weekly Inventory Summary',
        body: 'You have $lowStockCount low stock items. Total inventory value: \$${totalValue.toStringAsFixed(2)}',
      ),
    ));
  }
}