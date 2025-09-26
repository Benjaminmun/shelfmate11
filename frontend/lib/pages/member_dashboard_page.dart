import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'household_service.dart';
import 'inventory_list_page.dart';
import 'chat_page.dart';
import '../services/household_service_controller.dart';
import 'expense_tracker_page.dart';
import 'profile_page.dart';
import 'dart:async';

class MemberDashboardPage extends StatefulWidget {
  final String? selectedHousehold;
  final String? householdId;

  const MemberDashboardPage({Key? key, this.selectedHousehold, this.householdId}) : super(key: key);

  @override
  _MemberDashboardPageState createState() => _MemberDashboardPageState();
}

class _MemberDashboardPageState extends State<MemberDashboardPage> with SingleTickerProviderStateMixin {
  final HouseholdServiceController _householdServiceController = HouseholdServiceController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Modern color scheme matching DashboardPage
  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _secondaryColor = Color.fromARGB(255, 98, 112, 177);
  final Color _accentColor = Color(0xFF4CC9F0);
  final Color _successColor = Color(0xFF4ADE80);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _backgroundColor = Color(0xFFF8FAFF);
  final Color _surfaceColor = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1E293B);
  final Color _textSecondary = Color(0xFF64748B);
  final Color _textLight = Color(0xFF94A3B8);

  String _currentHousehold = '';
  String _currentHouseholdId = '';
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _expiringSoonItems = 0;
  int _totalCategories = 0;
  double _totalValue = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _inventorySubscription;
  StreamSubscription<QuerySnapshot>? _activitiesSubscription;

  // Enhanced animations matching DashboardPage
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _currentHousehold = widget.selectedHousehold ?? '';
    _currentHouseholdId = widget.householdId ?? '';
    
    if (_currentHouseholdId.isNotEmpty) {
      _setupRealTimeListeners();
    } else {
      _isLoading = false;
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _staggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _activitiesSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupRealTimeListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty || _currentHouseholdId.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'User not authenticated or household not selected';
      });
      return;
    }

    try {
      // Set up real-time listener for inventory (read-only for members)
      _inventorySubscription = _firestore
          .collection('households')
          .doc(_currentHouseholdId)
          .collection('inventory')
          .snapshots()
          .listen((snapshot) {
        _calculateStats(snapshot.docs);
      }, onError: (error) {
        print('Inventory stream error: $error');
        if (!_hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to sync inventory: ${error.toString()}';
          });
        }
      });

      // Set up real-time listener for activities (read-only for members)
      _activitiesSubscription = _firestore
          .collection('households')
          .doc(_currentHouseholdId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots()
          .listen((snapshot) {
        List<Map<String, dynamic>> recentActivities = [];
        for (var doc in snapshot.docs) {
          recentActivities.add({
            'message': doc['message'] ?? 'No message',
            'timestamp': doc['timestamp'] ?? Timestamp.now(),
            'type': doc['type'] ?? 'info',
          });
        }
        setState(() {
          _recentActivities = recentActivities;
          _hasError = false;
        });
      }, onError: (error) {
        print('Activities stream error: $error');
        // Activities are optional, so we don't treat this as a fatal error
      });

      // Start animations after data loads
      _animationController.forward();
      
    } catch (e) {
      print('Error setting up real-time listeners: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to set up real-time sync: ${e.toString()}';
      });
    }
  }

  void _calculateStats(List<QueryDocumentSnapshot> inventoryDocs) {
    int totalItems = inventoryDocs.length;
    int lowStockItems = 0;
    int expiringSoonItems = 0;
    int totalCategories = 0;
    double totalValue = 0.0;
    Set<String> categories = Set();

    for (var doc in inventoryDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final quantity = (data['quantity'] ?? 0).toInt();
      final price = (data['price'] ?? 0).toDouble();
      
      if (quantity < 5) lowStockItems++;
      if (data['category'] != null) categories.add(data['category'] as String);
      totalValue += quantity * price;

      // Check for expiring items (within 7 days)
      if (data['expiryDate'] != null) {
        try {
          final expiry = DateTime.parse(data['expiryDate']);
          final daysUntilExpiry = expiry.difference(DateTime.now()).inDays;
          if (daysUntilExpiry >= 0 && daysUntilExpiry <= 7) {
            expiringSoonItems++;
          }
        } catch (e) {
          // Invalid date format, skip
        }
      }
    }

    totalCategories = categories.length;

    setState(() {
      _totalItems = totalItems;
      _lowStockItems = lowStockItems;
      _expiringSoonItems = expiringSoonItems;
      _totalCategories = totalCategories;
      _totalValue = totalValue;
      _isLoading = false;
      _hasError = false;
    });
  }

  Future<void> _retryLoadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    // Cancel existing subscriptions
    _inventorySubscription?.cancel();
    _activitiesSubscription?.cancel();
    
    // Set up new listeners
    _setupRealTimeListeners();
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return _buildDashboardContent();
      case 1: return InventoryListPage(
        householdId: _currentHouseholdId,
        householdName: _currentHousehold,
        isReadOnly: true, // Important: Members have read-only access
      );
      case 2: return ExpenseTrackerPage(
        householdId: _currentHouseholdId,
        isReadOnly: true, // Members have read-only access to expenses
      );
      case 3: return ProfilePage();
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
        if (_hasError)
          _buildAppBarAction(
            Icons.refresh_rounded,
            'Retry Loading Data',
            _retryLoadData,
          ),
        _buildAppBarAction(
          Icons.chat_rounded,
          'AI Assistant',
          _currentHouseholdId.isNotEmpty ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(householdId: _currentHouseholdId),
              ),
            );
          } : null,
        ),
        if (_currentHousehold.isNotEmpty)
          _buildAppBarAction(
            Icons.swap_horiz_rounded,
            'Switch Household',
            () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HouseholdService()),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAppBarAction(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 24),
      onPressed: onPressed,
      tooltip: tooltip,
      color: onPressed != null ? Colors.white : Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
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
          elevation: 8,
          items: [
            _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
            _buildNavItem(Icons.inventory_2_rounded, 'Inventory', 1),
            _buildNavItem(Icons.analytics_rounded, 'Expenses', 2),
            _buildNavItem(Icons.person_rounded, 'Profile', 3),
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (1 - _staggerAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  SizedBox(height: 24),
                  _buildQuickStats(),
                  SizedBox(height: 24),
                  _buildQuickActions(),
                  SizedBox(height: 24),
                  _buildRecentActivitySection(),
                  SizedBox(height: 80), // Extra space for bottom navigation
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 25,
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
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _currentHousehold.isNotEmpty 
                      ? 'Viewing $_currentHousehold inventory as a member'
                      : 'View household inventory information',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                _buildMemberBadge(),
              ],
            ),
          ),
          SizedBox(width: 16),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.visibility_rounded, color: Colors.white, size: 35),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _hasError ? _errorColor : _successColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            _hasError ? 'Connection Issue' : 'Member Access - View Only',
            style: TextStyle(
              fontSize: 12,
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
        Text(
          'Inventory Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          children: [
            _buildStatCard(
              'Total Items',
              _totalItems.toString(),
              Icons.inventory_2_rounded,
              _primaryColor,
            ),
            _buildStatCard(
              'Low Stock',
              _lowStockItems.toString(),
              Icons.warning_amber_rounded,
              _warningColor,
            ),
            _buildStatCard(
              'Expiring Soon',
              _expiringSoonItems.toString(),
              Icons.calendar_today_rounded,
              _errorColor,
            ),
            _buildStatCard(
              'Total Value',
              'RM${_totalValue.toStringAsFixed(0)}',
              Icons.attach_money_rounded,
              _successColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          children: [
            _buildActionCard(
              'View Inventory',
              'Browse household items',
              Icons.inventory_2_rounded,
              _primaryColor,
              () => setState(() => _currentIndex = 1),
            ),
            _buildActionCard(
              'View Expenses',
              'Monitor household spending',
              Icons.analytics_rounded,
              _warningColor,
              () => setState(() => _currentIndex = 2),
            ),
            _buildActionCard(
              'AI Assistant',
              'Get help with your inventory',
              Icons.chat_rounded,
              _accentColor,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(householdId: _currentHouseholdId),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Your Profile',
              'Manage your account',
              Icons.person_rounded,
              _successColor,
              () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
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

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (_recentActivities.isNotEmpty)
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        _recentActivities.isEmpty
            ? _buildEmptyState()
            : Container(
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _recentActivities.length,
                  separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final activity = _recentActivities[index];
                    return _buildActivityItem(activity);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final icon = _getActivityIcon(activity['type']);
    final color = _getActivityColor(activity['type']);
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        activity['message'] ?? 'No message',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatTimestamp(activity['timestamp']),
        style: TextStyle(
          fontSize: 11,
          color: _textLight,
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'add': return Icons.add_circle_rounded;
      case 'update': return Icons.edit_rounded;
      case 'delete': return Icons.delete_rounded;
      case 'warning': return Icons.warning_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'add': return _successColor;
      case 'update': return _accentColor;
      case 'delete': return _errorColor;
      case 'warning': return _warningColor;
      default: return _primaryColor;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceColor,
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
        children: [
          Icon(Icons.history_rounded, size: 48, color: _textLight.withOpacity(0.3)),
          SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Household activities will appear here',
            style: TextStyle(
              fontSize: 12,
              color: _textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
                'Choose a household to view its information',
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
                      household['userRole'] ?? 'member',
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
              'No households available',
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
                'You need to be invited to a household to access this feature',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdCard(String householdName, Timestamp createdAt, String householdId, String userRole) {
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
          });
          _setupRealTimeListeners();
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
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: userRole == 'creator' 
                      ? _successColor.withOpacity(0.1)
                      : _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  userRole == 'creator' ? 'Owner' : 'Member',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: userRole == 'creator' ? _successColor : _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}