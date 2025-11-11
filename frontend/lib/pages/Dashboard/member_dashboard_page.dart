import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../Household/household_service.dart';
import '../Inventory/member_inventory_list_page.dart';
import '../../services/household_service_controller.dart';
import '../expense_tracker_page.dart';
import '../profile_page.dart';
import 'dart:async';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Enhanced method to get user info including fullName and role
  Future<Map<String, dynamic>> _getUserDisplayInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'userName': 'Unknown', 'fullName': 'Unknown User', 'role': 'member'};
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final userName = data?['userName'] as String? ?? user.displayName ?? user.email?.split('@').first ?? 'Unknown';
        final fullName = data?['fullName'] as String? ?? data?['displayName'] as String? ?? userName;
        final role = data?['role'] as String? ?? 'member'; // Default to 'member' if not set
        
        return {
          'userName': userName,
          'fullName': fullName,
          'role': role,
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
      'role': 'member',
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
  
  Future<Map<String, dynamic>> _calculateStats(QuerySnapshot snapshot) async {
    int totalItems = snapshot.docs.length;
    int lowStockItems = 0;
    int expiringSoonItems = 0;
    int totalCategories = 0;
    double totalValue = 0.0;
    Set<String> categories = Set();

    for (var doc in snapshot.docs) {
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

    return {
      'totalItems': totalItems,
      'lowStockItems': lowStockItems,
      'expiringSoonItems': expiringSoonItems,
      'totalCategories': totalCategories,
      'totalValue': totalValue,
    };
  }
}

// Enhanced Pulse Indicator with glow effect
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

class MemberDashboardPage extends StatefulWidget {
  final String? selectedHousehold;
  final String? householdId;

  const MemberDashboardPage({Key? key, this.selectedHousehold, this.householdId}) : super(key: key);

  @override
  _MemberDashboardPageState createState() => _MemberDashboardPageState();
}

class _MemberDashboardPageState extends State<MemberDashboardPage> with SingleTickerProviderStateMixin {
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
  String _userRole = 'member'; // Default to member
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _expiringSoonItems = 0;
  double _totalValue = 0.0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  int _currentIndex = 0;

  // Stream subscriptions for real-time data
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;

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
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
  }

  // Enhanced user data loading with fullName and role support
  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Use the enhanced method to get user info
      final userInfo = await _dashboardService._getUserDisplayInfo();
      
      setState(() {
        _userFullName = userInfo['fullName'] ?? 'User';
        _userRole = userInfo['role'] ?? 'member'; // Get user role
      });
    }
  }

  void _setupRealTimeSubscriptions() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Cancel existing subscriptions
    _statsSubscription?.cancel();

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
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _manualRefresh() async {
    if (_currentHouseholdId.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      _setupRealTimeSubscriptions();
    }
  }

  Future<void> _retryLoadData() async {
    if (_currentHouseholdId.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      _setupRealTimeSubscriptions();
    }
  }


  Widget _getPage(int index) {
    final adjustedIndex = _getAdjustedIndex(index);

    switch (adjustedIndex) {
      case 0: return _buildDashboardContent();
      case 1: return MemberInventoryListPage(
        householdId: _currentHouseholdId,
        householdName: _currentHousehold,
      );
      case 2: return ExpenseTrackerPage(
        householdId: _currentHouseholdId, 
        isReadOnly: true
      );
      case 3: return ProfilePage();
      default: return _buildDashboardContent();
    }
  }

  int _getAdjustedIndex(int index) {
    // For members, tabs are: Dashboard, Inventory, Expenses, Profile
    return index;
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Text(
              _currentHousehold.isNotEmpty ? '$_currentHousehold' : 'Dashboard',
              key: ValueKey(_currentHousehold),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Text(
            'Role: ${_userRole.toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
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
    final navItems = [
      _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
      _buildNavItem(Icons.inventory_2_rounded, 'Inventory', 1),
      _buildNavItem(Icons.analytics_rounded, 'Expenses', 2),
      _buildNavItem(Icons.person_rounded, 'Profile', 3),
    ];

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
          items: navItems,
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
            // Modified this part to include RM symbol for currency
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
              'Expense Tracking',
              'Monitor your spending',
              Icons.analytics_rounded,
              _warningColor,
              () => setState(() => _currentIndex = 2),
            ),
            _buildEnhancedActionCard(
              'Switch Household',
              'Change to another household',
              Icons.swap_horiz_rounded,
              _successColor,
              () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HouseholdService()),
                );
              },
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