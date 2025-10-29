import 'package:flutter/material.dart';
import 'package:frontend/services/inventory_reccomendation_service.dart';
import '../services/shopping_list_service.dart';
import 'shopping_list_page.dart';
import 'all_recommendations_page.dart';

// Notification Service for managing notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<InventoryNotification> _notifications = [];
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void addNotification(InventoryNotification notification) {
    // Avoid duplicates
    if (!_notifications.any((n) => 
        n.itemId == notification.itemId && 
        n.type == notification.type &&
        n.timestamp.difference(notification.timestamp).inHours < 1)) {
      
      _notifications.add(notification);
      _notifyListeners();
      
      print('🔔 Added notification: ${notification.title}');
    }
  }

  void dismissNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notifyListeners();
  }

  void dismissAllNotifications() {
    _notifications.clear();
    _notifyListeners();
  }

  List<InventoryNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.length;

  void clearExpiredNotifications() {
    final now = DateTime.now();
    _notifications.removeWhere((notification) => 
        now.difference(notification.timestamp).inHours > 24);
    _notifyListeners();
  }
}

// Notification Model
class InventoryNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'low_stock', 'expiry', 'recommendation', 'system'
  final String priority; // 'high', 'medium', 'low'
  final String itemId;
  final String itemName;
  final DateTime timestamp;
  final Map<String, dynamic>? actionData;
  bool isRead;

  InventoryNotification({
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.itemId,
    required this.itemName,
    this.actionData,
    this.isRead = false,
  }) : 
    id = '${DateTime.now().millisecondsSinceEpoch}_${itemId}_$type',
    timestamp = DateTime.now();

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
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class RecommendationSection extends StatefulWidget {
  final String householdId;
  final String householdName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Function(String, int, String) onAddToShoppingList;
  final Function(String) onNavigateToItem;
  final int maxDisplayCount;

  const RecommendationSection({
    Key? key,
    required this.householdId,
    required this.householdName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.onAddToShoppingList,
    required this.onNavigateToItem,
    this.maxDisplayCount = 2,
  }) : super(key: key);

  @override
  _RecommendationSectionState createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  final InventoryRecommendationService _recommendationService = InventoryRecommendationService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  final NotificationService _notificationService = NotificationService();
  
  List<Map<String, dynamic>> _smartRecommendations = [];
  bool _isRecommendationsLoading = false;
  bool _hasError = false;
  int _shoppingListCount = 0;
  Set<String> _itemsInCart = Set<String>();
  List<InventoryNotification> _notifications = [];
  OverlayEntry? _notificationOverlay;
  bool _showNotificationsPanel = false;

  @override
  void initState() {
    super.initState();
    _loadSmartRecommendations();
    _loadShoppingListCount();
    _loadCartState();
    _setupNotificationListener();
    _scheduleNotificationCheck();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_updateNotifications);
    _removeNotificationOverlay();
    super.dispose();
  }

  void _setupNotificationListener() {
    _notificationService.addListener(_updateNotifications);
  }

  void _updateNotifications() {
    if (mounted) {
      setState(() {
        _notifications = _notificationService.notifications;
      });
    }
  }

  void _scheduleNotificationCheck() {
    // Check for notifications every 30 seconds
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        _checkForNewNotifications();
        _scheduleNotificationCheck();
      }
    });
  }

  Future<void> _checkForNewNotifications() async {
    if (_smartRecommendations.isEmpty) return;

    for (final recommendation in _smartRecommendations) {
      final type = recommendation['type'] as String? ?? '';
      final priority = recommendation['priority'] as String? ?? 'medium';
      final itemId = recommendation['itemId'] as String? ?? '';
      final itemName = recommendation['itemName'] as String? ?? 'Unknown Item';
      final title = recommendation['title'] as String? ?? '';
      final message = recommendation['message'] as String? ?? '';

      // Only create notifications for high and medium priority items
      if (priority == 'high' || priority == 'medium') {
        final notificationType = _getNotificationTypeFromRecommendation(type);
        
        final notification = InventoryNotification(
          title: title,
          message: message,
          type: notificationType,
          priority: priority,
          itemId: itemId,
          itemName: itemName,
          actionData: recommendation,
        );

        _notificationService.addNotification(notification);
        
        // Show immediate popup for high priority notifications
        if (priority == 'high' && mounted) {
          _showImmediateNotificationPopup(notification);
        }
      }
    }
  }

  String _getNotificationTypeFromRecommendation(String recommendationType) {
    if (recommendationType.contains('stock')) return 'low_stock';
    if (recommendationType.contains('expiry')) return 'expiry';
    return 'recommendation';
  }

  void _showImmediateNotificationPopup(InventoryNotification notification) {
    // Remove any existing overlay
    _removeNotificationOverlay();

    // Create new overlay entry
    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _buildNotificationPopup(notification),
        ),
      ),
    );

    // Insert overlay
    Overlay.of(context).insert(_notificationOverlay!);

    // Auto remove after 5 seconds
    Future.delayed(Duration(seconds: 5), () {
      _removeNotificationOverlay();
    });
  }

  void _removeNotificationOverlay() {
    if (_notificationOverlay != null) {
      _notificationOverlay?.remove();
      _notificationOverlay = null;
    }
  }

  Widget _buildNotificationPopup(InventoryNotification notification) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.symmetric(horizontal: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _removeNotificationOverlay();
            _handleNotificationAction(notification);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notification.getIcon(), color: Colors.white, size: 20),
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
                  onPressed: _removeNotificationOverlay,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: 32, height: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSmartRecommendations() async {
    if (widget.householdId.isEmpty || _smartRecommendations.isNotEmpty) return;
    
    setState(() {
      _isRecommendationsLoading = true;
      _hasError = false;
    });

    try {
      print('🔄 Loading smart recommendations for household: ${widget.householdId}');
      final recommendations = await _recommendationService.getSmartRecommendations(widget.householdId);
      
      print('✅ Loaded ${recommendations.length} recommendations');
      
      if (mounted) {
        setState(() {
          _smartRecommendations = recommendations;
          _isRecommendationsLoading = false;
        });
        
        // Check for notifications after loading recommendations
        _checkForNewNotifications();
      }
    } catch (e) {
      print('❌ Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isRecommendationsLoading = false;
          _hasError = true;
          _smartRecommendations = [];
        });
      }
    }
  }

  Future<void> _loadShoppingListCount() async {
    try {
      final count = await _shoppingListService.getShoppingListCount(widget.householdId);
      if (mounted) {
        setState(() {
          _shoppingListCount = count;
        });
      }
    } catch (e) {
      print('❌ Error loading shopping list count: $e');
    }
  }

  Future<void> _loadCartState() async {
    try {
      final shoppingListItems = await _shoppingListService.getShoppingListItems(widget.householdId);
      if (mounted) {
        setState(() {
          _itemsInCart = Set<String>.from(shoppingListItems.map((item) => item['id']?.toString() ?? ''));
        });
      }
    } catch (e) {
      print('❌ Error loading cart state: $e');
    }
  }

  Future<void> _refreshRecommendations() async {
    setState(() {
      _smartRecommendations = [];
      _itemsInCart.clear();
      _notificationService.clearExpiredNotifications();
    });
    await Future.wait([
      _loadSmartRecommendations(),
      _loadShoppingListCount(),
      _loadCartState(),
    ]);
  }

  void _navigateToAllRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllRecommendationsPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          accentColor: widget.accentColor,
          successColor: widget.successColor,
          warningColor: widget.warningColor,
          errorColor: widget.errorColor,
          backgroundColor: widget.backgroundColor,
          surfaceColor: widget.surfaceColor,
          textPrimary: widget.textPrimary,
          textSecondary: widget.textSecondary,
          textLight: widget.textLight,
          onAddToShoppingList: widget.onAddToShoppingList,
          onNavigateToItem: widget.onNavigateToItem,
        ),
      ),
    ).then((_) {
      _loadShoppingListCount();
      _loadCartState();
      _loadSmartRecommendations();
    });
  }

  void _navigateToShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          accentColor: widget.accentColor,
          successColor: widget.successColor,
          warningColor: widget.warningColor,
          errorColor: widget.errorColor,
          backgroundColor: widget.backgroundColor,
          surfaceColor: widget.surfaceColor,
          textPrimary: widget.textPrimary,
          textSecondary: widget.textSecondary,
          textLight: widget.textLight,
        ),
      ),
    ).then((_) {
      _loadShoppingListCount();
      _loadCartState();
      _loadSmartRecommendations();
    });
  }

  Future<void> _toggleCartStatus(Map<String, dynamic> recommendation) async {
    final String itemId = recommendation['itemId'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final String itemName = recommendation['itemName'] ?? 'Unknown Item';
    
    print('🔄 Toggling cart status for: $itemName (ID: $itemId)');
    
    final bool isCurrentlyInCart = _itemsInCart.contains(itemId);

    try {
      if (isCurrentlyInCart) {
        await _removeFromCart(itemId);
      } else {
        await _addToCart(recommendation);
      }
    } catch (e) {
      print('❌ Error toggling cart status: $e');
      _showErrorSnackbar('Error updating cart: $e');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> recommendation) async {
    final String itemId = recommendation['itemId'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final String itemName = recommendation['itemName'] ?? 'Unknown Item';
    
    print('🛒 Adding to cart: $itemName (ID: $itemId)');
    
    setState(() {
      _itemsInCart.add(itemId);
      _smartRecommendations.removeWhere((rec) => rec['itemId'] == itemId);
    });

    try {
      final result = await _recommendationService.addRecommendationToShoppingList(
        householdId: widget.householdId,
        recommendation: recommendation,
      );

      if (result['success'] == true) {
        _showSuccessSnackbar('$itemName added to cart');
        print('✅ Successfully added to cart: $itemName');
        
        _loadShoppingListCount();
        
        final quantity = 1;
        widget.onAddToShoppingList(itemName, quantity, itemId);

        // Remove any notifications for this item
        _notificationService.notifications
          .where((n) => n.itemId == itemId)
          .toList()
          .forEach((n) => _notificationService.dismissNotification(n.id));
      } else {
        _showErrorSnackbar('Failed to add $itemName: ${result['error']}');
        setState(() {
          _itemsInCart.remove(itemId);
          _smartRecommendations.add(recommendation);
        });
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      _showErrorSnackbar('Error adding $itemName to cart: $e');
      setState(() {
        _itemsInCart.remove(itemId);
        _smartRecommendations.add(recommendation);
      });
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    print('🗑️ Removing from cart: $itemId');
    
    try {
      final result = await _shoppingListService.removeFromShoppingList(widget.householdId, itemId);
      
      if (result['success'] == true) {
        setState(() {
          _itemsInCart.remove(itemId);
        });
        _showInfoSnackbar('Item removed from cart');
        _loadShoppingListCount();
        _loadSmartRecommendations();
      } else {
        _showErrorSnackbar('Failed to remove item: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error removing from cart: $e');
      _showErrorSnackbar('Error removing item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            
            if (_hasError) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.bug_report_rounded),
                  label: Text('Debug Shopping List Issue'),
                  onPressed: _debugTestShoppingList,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.warningColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            
            _isRecommendationsLoading
                ? _buildRecommendationsLoading()
                : _hasError
                    ? _buildErrorState()
                    : _smartRecommendations.isEmpty
                        ? _buildNoRecommendations()
                        : _buildDashboardRecommendations(),
          ],
        ),

        // Notifications Panel
        if (_showNotificationsPanel)
          Positioned(
            top: 80,
            right: 16,
            child: _buildNotificationsPanel(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final urgentCount = _smartRecommendations.where((rec) => 
      rec['priority'] == 'high').length;
    final displayedCount = _smartRecommendations.length;
    final inCartCount = _itemsInCart.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            
            // Notifications Icon with Badge
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _notifications.isNotEmpty 
                        ? widget.warningColor.withOpacity(0.1)
                        : widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _notifications.isNotEmpty 
                          ? Icons.notifications_active_rounded 
                          : Icons.notifications_rounded,
                      size: 22,
                    ),
                    onPressed: _toggleNotificationsPanel,
                    tooltip: '${_notifications.length} notifications',
                    color: _notifications.isNotEmpty ? widget.warningColor : widget.primaryColor,
                  ),
                ),
                if (_notifications.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.warningColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${_notifications.length}',
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
            ),
            
            const SizedBox(width: 8),
            
            // Shopping Cart Icon with Badge
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.shopping_cart_rounded, size: 22),
                    onPressed: _navigateToShoppingList,
                    tooltip: 'View Shopping List ($_shoppingListCount items)',
                    color: widget.primaryColor,
                  ),
                ),
                if (_shoppingListCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$_shoppingListCount',
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
            ),
          ],
        ),
        
        if (_smartRecommendations.isNotEmpty && !_isRecommendationsLoading)
          Container(
            margin: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                // Progress indicator for urgent items
                if (urgentCount > 0)
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$urgentCount urgent items',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: inCartCount / urgentCount,
                          backgroundColor: widget.backgroundColor,
                          color: widget.successColor,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                
                if (urgentCount > 0) const SizedBox(width: 12),
                
                // Cart status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: inCartCount > 0 ? widget.successColor.withOpacity(0.1) : widget.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: inCartCount > 0 ? widget.successColor.withOpacity(0.3) : widget.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inCartCount > 0 ? Icons.shopping_cart_checkout_rounded : Icons.auto_awesome_rounded, 
                        size: 14, 
                        color: inCartCount > 0 ? widget.successColor : widget.primaryColor
                      ),
                      const SizedBox(width: 6),
                      Text(
                        inCartCount > 0 
                            ? '$inCartCount in cart' 
                            : '$displayedCount recommendations',
                        style: TextStyle(
                          fontSize: 12,
                          color: inCartCount > 0 ? widget.successColor : widget.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _toggleNotificationsPanel() {
    setState(() {
      _showNotificationsPanel = !_showNotificationsPanel;
    });
  }

  Widget _buildNotificationsPanel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: widget.surfaceColor,
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
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: widget.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Inventory Alerts',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: widget.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  if (_notifications.isNotEmpty)
                    TextButton(
                      onPressed: _notificationService.dismissAllNotifications,
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: widget.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18),
                    onPressed: _toggleNotificationsPanel,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(width: 32, height: 32),
                  ),
                ],
              ),
            ),

            // Notifications List
            if (_notifications.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.notifications_off_rounded, size: 48, color: widget.textLight),
                    SizedBox(height: 12),
                    Text(
                      'No Alerts',
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(
                        color: widget.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationItem(notification);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(InventoryNotification notification) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationAction(notification),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.backgroundColor,
                width: 1,
              ),
            ),
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
                              color: widget.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: notification.getColor(context).withOpacity(0.1),
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
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatTimeAgo(notification.timestamp),
                      style: TextStyle(
                        color: widget.textLight,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16),
                onPressed: () => _notificationService.dismissNotification(notification.id),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 24, height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationAction(InventoryNotification notification) {
    _notificationService.dismissNotification(notification.id);
    
    if (notification.actionData != null) {
      _handleRecommendationAction(notification.actionData!);
    } else {
      widget.onNavigateToItem(notification.itemId);
    }
    
    setState(() {
      _showNotificationsPanel = false;
    });
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  // ... (keep all the existing _buildStateWidget, _buildRecommendationsLoading, 
  // _buildErrorState, _buildNoRecommendations, _buildDashboardRecommendations methods)

  Widget _buildStateWidget(String title, String subtitle, IconData icon, Color iconColor, {String? actionText, VoidCallback? onAction}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsLoading() {
    return _buildStateWidget(
      'Analyzing Your Inventory...',
      'Checking stock levels, expiry dates, and consumption patterns to provide personalized recommendations',
      Icons.auto_awesome_rounded,
      widget.primaryColor,
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        _buildStateWidget(
          'Unable to Load Recommendations',
          'There was an error analyzing your inventory data. Please check your connection and try again.',
          Icons.error_outline_rounded,
          widget.errorColor,
          actionText: 'Try Again',
          onAction: _refreshRecommendations,
        ),
      ],
    );
  }

  Widget _buildNoRecommendations() {
    return Column(
      children: [
        _buildStateWidget(
          'Everything Looks Great! 🎉',
          'Your inventory is well managed with optimal stock levels and no urgent issues detected.',
          Icons.check_circle_rounded,
          widget.successColor,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatusChip('Stock Levels', 'Optimal', widget.successColor, Icons.inventory_2_rounded),
            _buildStatusChip('Expiry Dates', 'No Issues', widget.successColor, Icons.calendar_today_rounded),
            _buildStatusChip('Consumption', 'Stable', widget.successColor, Icons.timeline_rounded),
            _buildStatusChip('Budget', 'On Track', widget.successColor, Icons.attach_money_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardRecommendations() {
    final displayedRecommendations = _smartRecommendations.take(widget.maxDisplayCount).toList();
    final hasMoreRecommendations = _smartRecommendations.length > widget.maxDisplayCount;
    
    return Column(
      children: [
        ...displayedRecommendations.map((recommendation) => 
          _DashboardRecommendationItem(
            recommendation: recommendation,
            onTap: () => _handleRecommendationAction(recommendation),
            onToggleCart: () => _toggleCartStatus(recommendation),
            isInCart: _itemsInCart.contains(recommendation['itemId']),
            textPrimary: widget.textPrimary,
            textSecondary: widget.textSecondary,
            textLight: widget.textLight,
            primaryColor: widget.primaryColor,
            successColor: widget.successColor,
            errorColor: widget.errorColor,
          )
        ).toList(),
        
        if (hasMoreRecommendations) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                'View All ${_smartRecommendations.length} Recommendations',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _navigateToAllRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor.withOpacity(0.1),
                foregroundColor: widget.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRecommendationAction(Map<String, dynamic> recommendation) {
    final String? action = recommendation['action'] as String?;
    final String? itemId = recommendation['itemId'] as String?;
    final String? itemName = recommendation['itemName'] as String?;
    
    if (itemId == null) {
      _showErrorSnackbar('Invalid recommendation: missing item ID');
      return;
    }

    switch (action) {
      case 'restock':
      case 'restock_immediate':
        _showRestockDialog(itemName ?? 'Unknown Item', itemId);
        break;
      case 'use_soon':
        _showExpiryWarning(itemName ?? 'Unknown Item', recommendation['daysUntilExpiry'] ?? recommendation['expiryRiskLevel']);
        break;
      case 'plan_restock':
      case 'buy_now':
        _showPredictionDetails(itemName ?? 'Unknown Item', recommendation['daysRemaining'] ?? recommendation['stockoutProbability']);
        break;
      case 'monitor':
      case 'adjust_usage':
      case 'consider_alternatives':
        widget.onNavigateToItem(itemId);
        break;
      case 'reduce_stock':
        _showOverstockWarning(itemName ?? 'Unknown Item', recommendation['excessQuantity'] ?? 5);
        break;
      case 'rebalance_budget':
        _showBudgetRebalanceTip();
        break;
      case 'optimize_spending':
        _showSpendingOptimizationTip(recommendation['savingsOpportunity']);
        break;
      case 'improve_practices':
        _showSustainabilityTip();
        break;
      default:
        widget.onNavigateToItem(itemId);
    }
  }

  void _showRestockDialog(String itemName, String itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: widget.primaryColor),
            const SizedBox(width: 8),
            Text('Restock $itemName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add this item to your shopping list?'),
            const SizedBox(height: 8),
            Text(
              'Based on your consumption patterns and current stock levels.',
              style: TextStyle(
                fontSize: 12,
                color: widget.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              _addToCart({
                'itemId': itemId,
                'itemName': itemName,
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
            ),
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showExpiryWarning(String itemName, dynamic expiryInfo) {
    String message;
    if (expiryInfo is int) {
      message = expiryInfo == 0 
          ? 'This item expires today! Use it immediately to avoid waste.'
          : 'This item expires in $expiryInfo days. Consider using it soon to prevent expiration.';
    } else {
      message = 'This item has a high expiry risk. Consider using it soon.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: widget.warningColor),
            const SizedBox(width: 8),
            Text('$itemName Expiring'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPredictionDetails(String itemName, dynamic predictionInfo) {
    String message;
    if (predictionInfo is double) {
      message = 'Based on consumption patterns, this item will run out in ${predictionInfo.toStringAsFixed(1)} days. Consider restocking soon to avoid running out.';
    } else {
      message = 'This item is predicted to run out soon. Consider restocking to maintain optimal inventory levels.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timeline_rounded, color: widget.accentColor),
            const SizedBox(width: 8),
            Text('$itemName Stock Prediction'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showOverstockWarning(String itemName, int excessQuantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_rounded, color: widget.warningColor),
            const SizedBox(width: 8),
            Text('$itemName Overstocked'),
          ],
        ),
        content: Text('You have $excessQuantity more units than recommended. Consider using or donating the excess to optimize storage space and reduce waste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBudgetRebalanceTip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: widget.primaryColor),
            const SizedBox(width: 8),
            const Text('Budget Rebalancing Tip'),
          ],
        ),
        content: const Text('Consider shifting some of your budget from well-stocked categories to categories that are running low for better inventory balance and cost optimization.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSpendingOptimizationTip(dynamic savings) {
    String message = 'You can optimize your spending by timing your purchases better and taking advantage of bulk discounts.';
    if (savings != null) {
      message = 'You could save up to ${savings.toStringAsFixed(0)}% by optimizing your purchase timing and considering alternative products.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.savings_rounded, color: widget.successColor),
            const SizedBox(width: 8),
            const Text('Spending Optimization'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSustainabilityTip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.eco_rounded, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Sustainability Tip'),
          ],
        ),
        content: const Text('Consider bulk purchases, local products, and reducing food waste to improve your sustainability score and environmental impact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: widget.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: widget.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: widget.accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _debugTestShoppingList() async {
    print('🐛 Starting debug test...');
    
    final diagnosis = await _recommendationService.diagnoseShoppingListIssue(widget.householdId);
    print('🔍 Diagnosis: $diagnosis');
    
    final testResult = await _recommendationService.debugAddToShoppingList(
      householdId: widget.householdId,
      itemName: 'Debug Test Milk',
      itemId: 'debug_test_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('🐛 Debug test result: $testResult');
    
    if (testResult['success'] == true) {
      _showSuccessSnackbar('Debug test passed! Check console for details.');
    } else {
      _showErrorSnackbar('Debug test failed: ${testResult['error']}');
    }
    
    _loadShoppingListCount();
  }
}

class _DashboardRecommendationItem extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final VoidCallback onTap;
  final VoidCallback onToggleCart;
  final bool isInCart;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;

  const _DashboardRecommendationItem({
    Key? key,
    required this.recommendation,
    required this.onTap,
    required this.onToggleCart,
    required this.isInCart,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = Color(recommendation['color'] as int);
    final IconData icon = recommendation['icon'] as IconData;
    final String priority = recommendation['priority'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleCart,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isInCart ? successColor.withOpacity(0.1) : color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isInCart ? successColor.withOpacity(0.3) : color.withOpacity(0.2),
                width: isInCart ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isInCart ? successColor.withOpacity(0.2) : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isInCart ? successColor.withOpacity(0.4) : color.withOpacity(0.3)
                        ),
                      ),
                      child: Icon(
                        isInCart ? Icons.check_circle_rounded : icon, 
                        color: isInCart ? successColor : color, 
                        size: 22
                      ),
                    ),
                    if (priority == 'high')
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: errorColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recommendation['title'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation['message'],
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isInCart) ...[
                        const SizedBox(height: 4),
                        Text(
                          'In shopping list • Tap to remove',
                          style: TextStyle(
                            fontSize: 10,
                            color: successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tap to add to shopping list',
                          style: TextStyle(
                            fontSize: 10,
                            color: textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } 
}