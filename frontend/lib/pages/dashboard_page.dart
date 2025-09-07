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

class DashboardPage extends StatefulWidget {
  final String? selectedHousehold;
  final String? householdId;

  const DashboardPage({Key? key, this.selectedHousehold, this.householdId}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final HouseholdServiceController _householdServiceController = HouseholdServiceController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Enhanced color scheme
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color primaryLightColor = Color(0xFF5A8BA8);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);
  final Color warningColor = Color(0xFFFF5722);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);

  String _currentHousehold = '';
  String _currentHouseholdId = '';
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _totalCategories = 0;
  double _totalValue = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Navigation index
  int _currentIndex = 0;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _inventorySubscription;
  StreamSubscription<QuerySnapshot>? _activitiesSubscription;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _currentHousehold = widget.selectedHousehold ?? '';
    _currentHouseholdId = widget.householdId ?? '';
    
    if (_currentHouseholdId.isNotEmpty) {
      _setupRealTimeListeners();
    } else {
      _isLoading = false;
    }
    
    // Start animations
    _animationController.forward();
  }

  @override
  void dispose() {
    // Cancel all subscriptions when the widget is disposed
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
      // Set up real-time listener for inventory
      _inventorySubscription = _firestore
          .collection('users')
          .doc(userId)
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

      // Set up real-time listener for activities
      _activitiesSubscription = _firestore
          .collection('users')
          .doc(userId)
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
    }

    totalCategories = categories.length;

    setState(() {
      _totalItems = totalItems;
      _lowStockItems = lowStockItems;
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

  // Navigation pages based on index
  Widget _getPage(int index) {
    switch (index) {
      case 0: // Dashboard
        return _buildDashboardContent();
      case 1: // Inventory
        return InventoryListPage(
          householdId: _currentHouseholdId,
          householdName: _currentHousehold,
        );
      case 2: // Add Item
        return AddItemPage(
          householdId: _currentHouseholdId,
          householdName: _currentHousehold,
        );
      case 3: // Expense Tracker
        return ExpenseTrackerPage(householdId: _currentHouseholdId);
      case 4: // Profile
        return ProfilePage();
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: primaryColor,
        systemNavigationBarColor: backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
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
      title: Text(
        _currentHousehold.isNotEmpty ? '$_currentHousehold Dashboard' : 'Dashboard',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      actions: [
        // Refresh button for manual sync
        if (_hasError)
          IconButton(
            icon: Icon(Icons.refresh, size: 24),
            onPressed: _retryLoadData,
            tooltip: 'Retry Loading Data',
          ),
        // Chat button
        IconButton(
          icon: Icon(Icons.chat, size: 24),
          onPressed: _currentHouseholdId.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(householdId: _currentHouseholdId),
                    ),
                  );
                }
              : null,
          tooltip: 'Chat with AI Assistant',
          color: _currentHouseholdId.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.5),
        ),
        if (_currentHousehold.isNotEmpty)
          IconButton(
            icon: Icon(Icons.swap_horiz, size: 24),
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
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          topLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: cardColor,
          selectedItemColor: primaryColor,
          unselectedItemColor: lightTextColor,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 8,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: _currentIndex == 0
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.dashboard, size: 24),
              ),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: _currentIndex == 1
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.inventory, size: 24),
              ),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: _currentIndex == 2
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.add_circle_outline, size: 24),
              ),
              label: 'Add Item',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: _currentIndex == 3
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.attach_money, size: 24),
              ),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: _currentIndex == 4
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(Icons.person, size: 24),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header with improved design
              _buildWelcomeHeader(),
              SizedBox(height: 24),
              
              // Connection status indicator
              _buildConnectionStatus(),
              SizedBox(height: 16),
              
              // Quick actions
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 12),
              _buildQuickActions(),
              SizedBox(height: 24),
              
              // Statistics
              Text(
                'Inventory Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16),
              _buildStatsGrid(),
              SizedBox(height: 24),
              
              // Recent Activity
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryLightColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.home, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to $_currentHousehold',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Everything is up to date and running smoothly',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Manage Inventory',
            Icons.inventory,
            secondaryColor,
            () {
              setState(() {
                _currentIndex = 1;
              });
            },
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Add Item',
            Icons.add,
            accentColor,
            () {
              setState(() {
                _currentIndex = 2;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      children: [
        _buildStatCard('Total Items', _totalItems.toString(), Icons.inventory, primaryColor),
        _buildStatCard('Low Stock', _lowStockItems.toString(), Icons.warning_amber, warningColor),
        _buildStatCard('Categories', _totalCategories.toString(), Icons.category, secondaryColor),
        _buildStatCard('Total Value', 'RM ${_totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
      ],
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (_recentActivities.isNotEmpty)
              TextButton(
                onPressed: () {
                  // View all activities
                },
                child: Text('View All', style: TextStyle(color: primaryColor)),
              ),
          ],
        ),
        SizedBox(height: 12),
        _recentActivities.isEmpty
            ? Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: lightTextColor.withOpacity(0.5)),
                    SizedBox(height: 12),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        fontSize: 16,
                        color: lightTextColor,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 4),
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
                    return _buildActivityItem(
                      activity['message'] ?? 'No message',
                      _formatTimestamp(activity['timestamp']),
                    );
                  },
                ),
              ),
      ],
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a Household',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose a household to manage its inventory',
                style: TextStyle(
                  fontSize: 14,
                  color: lightTextColor,
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading your data...',
            style: TextStyle(
              fontSize: 16,
              color: lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({String? message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: warningColor),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message ?? _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _retryLoadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HouseholdService()),
                );
              },
              child: Text(
                'Switch Household',
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor,
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
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: 80, color: lightTextColor.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              'No households yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first household to get started',
              style: TextStyle(
                fontSize: 16,
                color: lightTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _householdServiceController.createNewHousehold(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Create New Household',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _hasError ? warningColor : secondaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            _hasError ? 'Offline' : 'Syncing in real-time',
            style: TextStyle(
              fontSize: 12,
              color: _hasError ? warningColor : secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdCard(String householdName, Timestamp createdAt, String householdId) {
    DateTime createdDate = createdAt.toDate();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_outlined,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              SizedBox(height: 16),
              Text(
                householdName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                'Created: ${_formatDate(createdDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: lightTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.notifications_none, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        time,
        style: TextStyle(
          fontSize: 12,
          color: lightTextColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate().toUtc().add(Duration(hours: 8));
    final now = DateTime.now().toUtc().add(Duration(hours: 8));
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  } 
}