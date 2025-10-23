import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'household_service.dart';
import 'inventory_list_page.dart';
import 'chat_page.dart';
import '../services/household_service_controller.dart';
import 'add_item_page.dart';
import 'expense_tracker_page.dart';
import 'profile_page.dart';
import 'dart:async';
import 'activity_pages.dart';
import 'recommendation_section.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Enhanced method to get user info including fullName
  Future<Map<String, String>> _getUserDisplayInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'userName': 'Unknown', 'fullName': 'Unknown User'};
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final userName = data?['userName'] as String? ?? user.displayName ?? user.email?.split('@').first ?? 'Unknown';
        final fullName = data?['fullName'] as String? ?? data?['displayName'] as String? ?? userName;
        
        return {
          'userName': userName,
          'fullName': fullName,
        };
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    
    // Fallback to Firebase Auth display name
    final fallbackName = user.displayName ?? user.email?.split('@').first ?? 'Unknown';
    return {
      'userName': fallbackName,
      'fullName': fallbackName,
    };
  }

  // Real-time inventory stats stream
  Stream<Map<String, dynamic>> getInventoryStatsStream(String householdId) {
    if (householdId.isEmpty) {
      return Stream.value({});
    }
    
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory')
        .snapshots()
        .asyncMap((snapshot) async {
          return await _calculateStats(snapshot);
        });
  }
  
  // In DashboardService - _calculateStats method
Future<Map<String, dynamic>> _calculateStats(QuerySnapshot snapshot) async {
  int totalItems = snapshot.docs.length;
  int lowStockItems = 0;
  int expiringSoonItems = 0;
  int totalCategories = 0;
  double totalValue = 0.0;
  Set<String> categories = Set();

  // Use device local time instead of GMT+8
  final now = DateTime.now(); // Remove GMT+8 conversion
  final today = DateTime(now.year, now.month, now.day);
  today.add(Duration(days: 7)); // Define next week for expiry check

  for (var doc in snapshot.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final quantity = (data['quantity'] ?? 0).toInt();
    final price = (data['price'] ?? 0).toDouble();
    
    if (quantity < 5) lowStockItems++;
    if (data['category'] != null) categories.add(data['category'] as String);
    totalValue += quantity * price;

    // Enhanced expiry date checking - use local time
    if (data['expiryDate'] != null) {
      try {
        DateTime? expiry;
        
        // Handle different expiry date formats
        if (data['expiryDate'] is Timestamp) {
          expiry = (data['expiryDate'] as Timestamp).toDate();
        } else if (data['expiryDate'] is String) {
          expiry = DateTime.parse(data['expiryDate'] as String);
        }
        
        if (expiry != null) {
          // Use local time directly - remove GMT+8 conversion
          final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
          
          // Check if expiry is within next 7 days (including today)
          final daysUntilExpiry = expiryDate.difference(today).inDays;
          
          if (daysUntilExpiry >= 0 && daysUntilExpiry <= 7) {
            expiringSoonItems++;
            print('Expiring soon: ${doc.id} - $expiryDate (${daysUntilExpiry} days)');
          }
        }
      } catch (e) {
        print('Error parsing expiry date for ${doc.id}: ${data['expiryDate']} - $e');
      }
    }
  }

  totalCategories = categories.length;

  print('Stats calculated - Total: $totalItems, Expiring: $expiringSoonItems');

  return {
    'totalItems': totalItems,
    'lowStockItems': lowStockItems,
    'expiringSoonItems': expiringSoonItems,
    'totalCategories': totalCategories,
    'totalValue': totalValue,
  };
}

  Stream<List<Map<String, dynamic>>> getRecentActivitiesStream(String householdId) {
    if (householdId.isEmpty) {
      return Stream.value([]);
    }
    
    try {
      return _firestore
          .collection('households')
          .doc(householdId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'message': data['description'] ?? data['message'] ?? 'No message',
                'timestamp': data['timestamp'] ?? Timestamp.now(),
                'type': data['type'] ?? 'info',
                'userName': data['userName'] ?? 'Unknown User',
                'fullName': data['fullName'] ?? data['userName'] ?? 'Unknown User',
                'userId': data['userId'] ?? '',
                'itemName': data['itemName'],
                'oldValue': data['oldValue'],
                'newValue': data['newValue'],
              };
            }).toList();
          });
    } catch (e) {
      print('Error getting activities stream: $e');
      return Stream.value([]);
    }
  }

  // Get activities with pagination for infinite scroll
  Future<Map<String, dynamic>> getActivitiesPaginated(
    String householdId, {
    int limit = 15,
    DocumentSnapshot? startAfter,
  }) async {
    if (householdId.isEmpty) {
      return {'activities': [], 'hasMore': false, 'lastDocument': null};
    }

    try {
      Query query = _firestore
          .collection('households')
          .doc(householdId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final activities = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'message': data['description'] ?? data['message'] ?? 'No message',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'type': data['type'] ?? 'info',
          'userName': data['userName'] ?? 'Unknown User',
          'fullName': data['fullName'] ?? data['userName'] ?? 'Unknown User',
          'userId': data['userId'] ?? '',
          'itemName': data['itemName'],
          'oldValue': data['oldValue'],
          'newValue': data['newValue'],
        };
      }).toList();

      final hasMore = snapshot.docs.length == limit;
      final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return {
        'activities': activities,
        'hasMore': hasMore,
        'lastDocument': lastDocument,
      };
    } catch (e) {
      print('Error getting paginated activities: $e');
      return {'activities': [], 'hasMore': false, 'lastDocument': null};
    }
  }

  // Enhanced logActivity method with fullName support
  Future<void> logActivity(
    String householdId, 
    String description, 
    String type, {
    String? userId,
    String? userName,
    String? fullName,
    String? itemName,
    dynamic oldValue,
    dynamic newValue,
  }) async {
    if (householdId.isEmpty) return;
    
    try {
      // If fullName is not provided, try to get user info
      String? finalUserName = userName;
      String? finalFullName = fullName;
      
      if (fullName == null) {
        final userInfo = await _getUserDisplayInfo();
        finalUserName = userInfo['userName'];
        finalFullName = userInfo['fullName'];
      }
      
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('activities')
          .add({
            'description': description,
            'type': type,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': userId ?? _auth.currentUser?.uid,
            'userName': finalUserName ?? _auth.currentUser?.displayName ?? 'User',
            'fullName': finalFullName ?? finalUserName ?? 'User',
            'itemName': itemName,
            'oldValue': oldValue,
            'newValue': newValue,
          });
      print('Activity logged: $description');
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Get detailed activity statistics
  Future<Map<String, dynamic>> getActivityStats(String householdId) async {
    if (householdId.isEmpty) return {};
    
    try {
      final weekAgo = Timestamp.fromDate(DateTime.now().subtract(Duration(days: 7)));
      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('activities')
          .where('timestamp', isGreaterThanOrEqualTo: weekAgo)
          .get();

      int totalActivities = snapshot.docs.length;
      int adds = 0, updates = 0, deletes = 0, warnings = 0;

      for (var doc in snapshot.docs) {
        final type = doc['type'] ?? 'info';
        switch (type) {
          case 'add': adds++; break;
          case 'update': updates++; break;
          case 'delete': deletes++; break;
          case 'warning': warnings++; break;
        }
      }

      return {
        'totalActivities': totalActivities,
        'adds': adds,
        'updates': updates,
        'deletes': deletes,
        'warnings': warnings,
      };
    } catch (e) {
      print('Error getting activity stats: $e');
      return {};
    }
  }
}

// Animated Stat Number Widget
class AnimatedStatNumber extends StatefulWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const AnimatedStatNumber({
    Key? key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  _AnimatedStatNumberState createState() => _AnimatedStatNumberState();
}

class _AnimatedStatNumberState extends State<AnimatedStatNumber> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = IntTween(begin: _previousValue, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _controller.reset();
      _animation = IntTween(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.toString(),
          style: widget.style,
        );
      },
    );
  }
}

// Enhanced Activity Item Widget with fullName support
class EnhancedActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const EnhancedActivityItem({
    Key? key,
    required this.activity,
    required this.onTap,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final icon = _getActivityIcon(activity['type']);
    final color = _getActivityColor(activity['type']);
    final timestamp = activity['timestamp'] as Timestamp;
    final hasDetails = activity['itemName'] != null;
    
    // Get user display info with fullName support
    final String userName = activity['userName'] ?? 'Unknown User';
    final String fullName = activity['fullName'] ?? userName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity Icon with gradient background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              
              // Activity Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity Message
                    Text(
                      activity['message'] ?? 'No message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Item Name (if available)
                    if (hasDetails && activity['itemName'] != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Item: ${activity['itemName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    
                    if (hasDetails && activity['itemName'] != null)
                      SizedBox(height: 8),
                    
                    // User and Time Info with fullName support - FIXED ROW
                    Row(
                      children: [
                        // User Avatar and Name
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 12,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(width: 6),
                        // Display fullName only (removed @ symbol)
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Spacer(),
                        
                        // Time - FIXED TIME FORMAT
                        Icon(Icons.access_time_rounded, size: 12, color: textLight),
                        SizedBox(width: 4),
                        Text(
                          _formatActivityTime(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: textLight,
                          ),
                        ),
                      ],
                    ),
                    
                    // Value Changes (for updates)
                    if (activity['type'] == 'update' && activity['oldValue'] != null && activity['newValue'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${activity['oldValue']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 12, color: textLight),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${activity['newValue']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Activity Type Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getActivityTypeLabel(activity['type']),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Enhanced time formatting with GMT+8
  String _formatActivityTime(Timestamp timestamp) {
  // Use device local time directly - remove GMT+8 conversion
  final date = timestamp.toDate(); // This uses the device's local timezone
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final activityDate = DateTime(date.year, date.month, date.day);
  
  if (activityDate == today) {
    // Today: show time only
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  } else if (activityDate == today.subtract(Duration(days: 1))) {
    // Yesterday
    return 'Yesterday';
  } else {
    // Other days: show date
    return '${date.day}/${date.month}';
  }
}

  String _getActivityTypeLabel(String type) {
    switch (type) {
      case 'add': return 'ADDED';
      case 'update': return 'UPDATED';
      case 'delete': return 'DELETED';
      case 'warning': return 'ALERT';
      case 'info': return 'INFO';
      default: return 'ACTIVITY';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'add': return Icons.add_circle_rounded;
      case 'update': return Icons.edit_rounded;
      case 'delete': return Icons.delete_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      case 'info': return Icons.info_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'add': return Color(0xFF10B981);
      case 'update': return Color(0xFF3B82F6);
      case 'delete': return Color(0xFFEF4444);
      case 'warning': return Color(0xFFF59E0B);
      case 'info': return Color(0xFF6B7280);
      default: return Color(0xFF6B7280);
    }
  }
}

// Activity Shimmer Loading Widget
class ActivityShimmer extends StatelessWidget {
  const ActivityShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) => 
        Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          width: 40,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String? selectedHousehold;
  final String? householdId;

  const DashboardPage({Key? key, this.selectedHousehold, this.householdId}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final HouseholdServiceController _householdServiceController = HouseholdServiceController();
  final DashboardService _dashboardService = DashboardService();
  
  // Enhanced color scheme with gradients
  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _secondaryColor = Color(0xFF6270B1);
  final Color _accentColor = Color(0xFF4CC9F0);
  final Color _successColor = Color(0xFF10B981);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _backgroundColor = Color(0xFFF8FAFF);
  final Color _surfaceColor = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1E293B);
  final Color _textSecondary = Color(0xFF64748B);
  final Color _textLight = Color(0xFF94A3B8);

  String _currentHousehold = '';
  String _currentHouseholdId = '';
  String _userFullName = '';
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _expiringSoonItems = 0;
  double _totalValue = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];
  Map<String, dynamic> _activityStats = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isActivitiesLoading = true;
  
  int _currentIndex = 0;
  int _selectedActivityTab = 0;

  // Stream subscriptions for real-time data
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _activitiesSubscription;

  // Enhanced animations
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _currentHousehold = widget.selectedHousehold ?? '';
    _currentHouseholdId = widget.householdId ?? '';
    _loadUserData();
    
    if (_currentHouseholdId.isNotEmpty) {
      _setupRealTimeSubscriptions();
    } else {
      _isLoading = false;
      _isActivitiesLoading = false;
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
  }

  // Enhanced user data loading with fullName support
  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userInfo = await _dashboardService._getUserDisplayInfo();
      
      setState(() {
        _userFullName = userInfo['fullName'] ?? 'User';
      });
    }
  }

  void _setupRealTimeSubscriptions() {
    setState(() {
      _isLoading = true;
      _isActivitiesLoading = true;
      _hasError = false;
    });

    // Cancel existing subscriptions
    _statsSubscription?.cancel();
    _activitiesSubscription?.cancel();

    // Set up real-time stats subscription
    _statsSubscription = _dashboardService
        .getInventoryStatsStream(_currentHouseholdId)
        .listen((stats) {
      if (mounted) {
        setState(() {
          _totalItems = stats['totalItems'] ?? 0;
          _lowStockItems = stats['lowStockItems'] ?? 0;
          _expiringSoonItems = stats['expiringSoonItems'] ?? 0;
          _totalValue = stats['totalValue'] ?? 0.0;
          _isLoading = false;
          _hasError = false;
        });
        
        // Load activity stats
        _loadActivityStats();
        
        // Start animations when first data arrives
        if (!_animationController.isAnimating) {
          _animationController.forward();
        }
      }
    }, onError: (error) {
      print('Stats stream error: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load real-time data: ${error.toString()}';
        });
      }
    });

    // Set up activities subscription
    _setupActivitiesSubscription();
  }

  void _setupActivitiesSubscription() {
    _activitiesSubscription = _dashboardService
        .getRecentActivitiesStream(_currentHouseholdId)
        .listen((activities) {
      if (mounted) {
        setState(() {
          _recentActivities = activities;
          _isActivitiesLoading = false;
        });
      }
    }, onError: (error) {
      print('Activities stream error: $error');
      _createSampleActivities();
    });
  }

  Future<void> _loadActivityStats() async {
    final stats = await _dashboardService.getActivityStats(_currentHouseholdId);
    if (mounted) {
      setState(() {
        _activityStats = stats;
      });
    }
  }

  void _createSampleActivities() {
    setState(() {
      _recentActivities = [
        {
          'message': 'Welcome to your household! Start by adding some items to see activity here.',
          'timestamp': Timestamp.now(),
          'type': 'info',
          'userName': 'System',
          'fullName': 'System',
          'itemName': null,
        },
        {
          'message': 'Milk was added to inventory',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
          'type': 'add',
          'userName': _userFullName,
          'fullName': _userFullName,
          'itemName': 'Milk',
        },
        {
          'message': 'Eggs quantity was updated',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 4))),
          'type': 'update',
          'userName': _userFullName,
          'fullName': _userFullName,
          'itemName': 'Eggs',
          'oldValue': 3,
          'newValue': 12,
        },
        {
          'message': 'Bread is running low',
          'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
          'type': 'warning',
          'userName': 'System',
          'fullName': 'System',
          'itemName': 'Bread',
        },
      ];
      _isActivitiesLoading = false;
    });
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _activitiesSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _manualRefresh() async {
    if (_currentHouseholdId.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _isActivitiesLoading = true;
      });
      
      await _dashboardService.logActivity(
        _currentHouseholdId,
        'Dashboard data was manually refreshed',
        'info',
      );
      
      _setupRealTimeSubscriptions();
    }
  }

  Future<void> _retryLoadData() async {
    if (_currentHouseholdId.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _isActivitiesLoading = true;
        _hasError = false;
      });
      _setupRealTimeSubscriptions();
    }
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return _buildDashboardContent();
      case 1: return InventoryListPage(
        householdId: _currentHouseholdId,
        householdName: _currentHousehold,
      );
      case 2: return AddItemPage(
        householdId: _currentHouseholdId,
        householdName: _currentHousehold,
      );
      case 3: return ExpenseTrackerPage(householdId: _currentHouseholdId, isReadOnly: true); 
      case 4: return ProfilePage();
      default: return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _primaryColor,
        systemNavigationBarColor: _backgroundColor,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _currentIndex == 0 ? _buildAppBar() : null,
        body: _hasError
            ? _buildErrorState()
            : _isLoading
                ? _buildLoadingState()
                : _currentHousehold.isNotEmpty
                    ? _getPage(_currentIndex)
                    : _buildHouseholdSelection(),
        bottomNavigationBar: _currentHousehold.isNotEmpty 
            ? _buildBottomNavigationBar() 
            : null,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: Text(
          _currentHousehold.isNotEmpty ? '$_currentHousehold' : 'Dashboard',
          key: ValueKey(_currentHousehold),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      backgroundColor: _primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, size: 24),
          onPressed: _manualRefresh,
          tooltip: 'Refresh Data',
        ),
        IconButton(
          icon: Icon(Icons.chat_rounded, size: 24),
          onPressed: _currentHouseholdId.isNotEmpty ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(householdId: _currentHouseholdId),
              ),
            );
          } : null,
          tooltip: 'AI Assistant',
        ),
        if (_currentHousehold.isNotEmpty)
          IconButton(
            icon: Icon(Icons.swap_horiz_rounded, size: 24),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HouseholdService()),
              );
            },
            tooltip: 'Switch Household',
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: _surfaceColor,
          selectedItemColor: _primaryColor,
          unselectedItemColor: _textLight,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 12,
          items: [
            _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
            _buildNavItem(Icons.inventory_2_rounded, 'Inventory', 1),
            _buildNavItem(Icons.add_circle_rounded, 'Add Item', 2),
            _buildNavItem(Icons.analytics_rounded, 'Expenses', 3),
            _buildNavItem(Icons.person_rounded, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _currentIndex == index ? _primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24),
      ),
      label: label,
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _manualRefresh,
      color: _primaryColor,
      backgroundColor: _surfaceColor,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        children: [
          _buildWelcomeHeader(),
          SizedBox(height: 24),
          _buildQuickStats(),
          SizedBox(height: 24),
          
          // 🔮 ENHANCED: Smart Recommendations Section
          RecommendationSection(
            householdId: _currentHouseholdId,
            householdName: _currentHousehold,
            primaryColor: _primaryColor,
            secondaryColor: _secondaryColor,
            accentColor: _accentColor,
            successColor: _successColor,
            warningColor: _warningColor,
            errorColor: _errorColor,
            backgroundColor: _backgroundColor,
            surfaceColor: _surfaceColor,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            textLight: _textLight,
            onAddToShoppingList: _addToShoppingList,
            onNavigateToItem: _navigateToItem,
          ),
          SizedBox(height: 24),
          
          _buildActivitySection(),
          SizedBox(height: 24),
          _buildQuickActions(),
          SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, $_userFullName!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _currentHousehold.isNotEmpty 
                      ? 'Your $_currentHousehold inventory is looking great!'
                      : 'Manage your household inventory efficiently',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                _buildStatusIndicator(),
              ],
            ),
          ),
          SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.home_rounded, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (_hasError) {
      statusColor = _errorColor;
      statusText = 'Needs Attention';
      statusIcon = Icons.error_outline_rounded;
    } else if (_isLoading) {
      statusColor = _warningColor;
      statusText = 'Loading...';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = _successColor;
      statusText = 'Live & Updated';
      statusIcon = Icons.check_circle_rounded;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasError && !_isLoading)
            PulseIndicator(color: statusColor, size: 10),
          SizedBox(width: 6),
          Icon(statusIcon, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Inventory Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 8),
            PulseIndicator(color: _primaryColor, size: 6),
          ],
        ),
        SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          children: [
            _buildEnhancedStatCard(
              'Total Items',
              _totalItems,
              Icons.inventory_2_rounded,
              _primaryColor,
              'All items in inventory',
            ),
            _buildEnhancedStatCard(
              'Low Stock',
              _lowStockItems,
              Icons.warning_amber_rounded,
              _warningColor,
              'Items below 5 quantity',
            ),
            _buildEnhancedStatCard(
              'Expiring Soon',
              _expiringSoonItems,
              Icons.calendar_today_rounded,
              _errorColor,
              'Expiring in 7 days',
            ),
            _buildEnhancedStatCard(
              'Total Value',
              _totalValue.toInt(),
              Icons.attach_money_rounded,
              _successColor,
              'Total inventory worth',
              isCurrency: true,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(String title, int value, IconData icon, Color color, String subtitle, {bool isCurrency = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (value > 0 && title == 'Low Stock')
                  PulseIndicator(color: _warningColor, size: 8),
                if (value > 0 && title == 'Expiring Soon')
                  PulseIndicator(color: _errorColor, size: 8),
              ],
            ),
            SizedBox(height: 16),
            if (isCurrency)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                  AnimatedStatNumber(
                    value: value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              )
            else
              AnimatedStatNumber(
                value: value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Callback methods for RecommendationSection
  void _addToShoppingList(String itemName, int quantity, String itemId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $quantity $itemName to shopping list'),
        backgroundColor: _successColor,
      ),
    );
  }

  void _navigateToItem(String itemId) {
    setState(() {
      _currentIndex = 1; // Navigate to inventory page
    });
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  _buildActivityTab('Recent', 0),
                  _buildActivityTab('Stats', 1),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: _selectedActivityTab == 0 ? _buildRecentActivityView() : _buildActivityStatsView(),
        ),
      ],
    );
  }

  Widget _buildActivityTab(String text, int index) {
    final isSelected = _selectedActivityTab == index;
    return Material(
      color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _selectedActivityTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? _primaryColor : _textLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityView() {
    if (_isActivitiesLoading) {
      return Container(
        height: 300,
        child: ActivityShimmer(),
      );
    }

    if (_recentActivities.isEmpty) {
      return _buildEmptyActivityState();
    }

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          LimitedBox(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentActivities.length,
              itemBuilder: (context, index) {
                final activity = _recentActivities[index];
                return EnhancedActivityItem(
                  activity: activity,
                  onTap: () => _showActivityDetails(activity),
                  primaryColor: _primaryColor,
                  surfaceColor: _surfaceColor,
                  textPrimary: _textPrimary,
                  textSecondary: _textSecondary,
                  textLight: _textLight,
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityLogPage(
                      householdId: _currentHouseholdId,
                      householdName: _currentHousehold,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View All Activities',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailPage(activity: activity),
      ),
    );
  }

  Widget _buildActivityStatsView() {
    final total = _activityStats['totalActivities'] ?? 0;
    final adds = _activityStats['adds'] ?? 0;
    final updates = _activityStats['updates'] ?? 0;
    final deletes = _activityStats['deletes'] ?? 0;
    final warnings = _activityStats['warnings'] ?? 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Activity Statistics (Last 7 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1.4,
            ),
            children: [
              _buildActivityStatItem('Total Activities', total, Icons.analytics_rounded, _primaryColor),
              _buildActivityStatItem('Items Added', adds, Icons.add_rounded, _successColor),
              _buildActivityStatItem('Items Updated', updates, Icons.edit_rounded, _accentColor),
              _buildActivityStatItem('Items Deleted', deletes, Icons.delete_rounded, _errorColor),
            ],
          ),
          if (warnings > 0) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _warningColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: _warningColor, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$warnings Low Stock Warnings',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Consider restocking these items soon',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityStatItem(String title, int value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          AnimatedStatNumber(
            value: value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 50,
              color: _textLight.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your recent activities will appear here when you add, update, or delete items from your inventory',
              style: TextStyle(
                fontSize: 14,
                color: _textLight,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _currentIndex = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add Your First Item',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 18),
        GridView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          children: [
            _buildEnhancedActionCard(
              'Manage Inventory',
              'View and organize your items',
              Icons.inventory_2_rounded,
              _primaryColor,
              () => setState(() => _currentIndex = 1),
            ),
            _buildEnhancedActionCard(
              'Add New Item',
              'Quickly add items to inventory',
              Icons.add_circle_rounded,
              _successColor,
              () => setState(() => _currentIndex = 2),
            ),
            _buildEnhancedActionCard(
              'AI Assistant',
              'Get help with your inventory',
              Icons.chat_rounded,
              _accentColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(householdId: _currentHouseholdId ),
                  ),
                );
              },
            ),
            _buildEnhancedActionCard(
              'Expense Tracking',
              'Monitor your spending',
              Icons.analytics_rounded,
              _warningColor,
              () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHouseholdSelection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _householdServiceController.getUserHouseholdsWithDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(message: 'Error loading households: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoHouseholdsState();
        }

        return Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a Household',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose a household to manage its inventory',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var household = snapshot.data![index];
                    return _buildHouseholdCard(
                      household['name'] ?? 'Unnamed Household',
                      household['createdAt'] ?? Timestamp.now(),
                      household['id'] ?? '',
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your dashboard...',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({String? message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 35, color: _errorColor),
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                message ?? _errorMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retryLoadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoHouseholdsState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.home_work_outlined, size: 40, color: _primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'No households yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Create your first household to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _householdServiceController.createNewHousehold(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Text(
                'Create New Household',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdCard(String householdName, Timestamp createdAt, String householdId) {
    DateTime createdDate = createdAt.toDate();
    
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentHousehold = householdName;
            _currentHouseholdId = householdId;
            _isLoading = true;
            _isActivitiesLoading = true;
          });
          _setupRealTimeSubscriptions();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_rounded,
                  color: _primaryColor,
                  size: 25,
                ),
              ),
              SizedBox(height: 12),
              Text(
                householdName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
              Text(
                'Created ${_formatDate(createdDate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: _textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Utility methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Pulse Indicator with glow effect
class PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;
  
  const PulseIndicator({Key? key, required this.color, this.size = 8}) : super(key: key);
  
  @override
  _PulseIndicatorState createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value * 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}