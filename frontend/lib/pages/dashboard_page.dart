import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'household_service.dart';
import 'login_page.dart';
import 'inventory_list_page.dart';
import 'chat_page.dart';
import '../services/household_service_controller.dart';

class DashboardPage extends StatefulWidget {
  final String? selectedHousehold;
  final String? householdId;

  const DashboardPage({Key? key, this.selectedHousehold, this.householdId}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final HouseholdServiceController _householdServiceController = HouseholdServiceController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Color scheme
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);
  final Color backgroundColor = Color(0xFFF5F7F9);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF333333);
  final Color lightTextColor = Color(0xFF666666);

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

  @override
  void initState() {
    super.initState();
    _currentHousehold = widget.selectedHousehold ?? '';
    _currentHouseholdId = widget.householdId ?? '';
    
    if (_currentHouseholdId.isNotEmpty) {
      _loadInventoryData();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadInventoryData() async {
    if (_currentHouseholdId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get current user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'User not authenticated';
        });
        return;
      }

      // Get inventory items
      final inventorySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('households')
          .doc(_currentHouseholdId)
          .collection('inventory')
          .get();

      // Calculate statistics
      int totalItems = inventorySnapshot.docs.length;
      int lowStockItems = 0;
      int totalCategories = 0;
      double totalValue = 0.0;
      Set<String> categories = Set();

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] ?? 0).toInt();
        final price = (data['price'] ?? 0).toDouble();
        
        if (quantity < 5) lowStockItems++;
        if (data['category'] != null) categories.add(data['category'] as String);
        totalValue += quantity * price;
      }

      totalCategories = categories.length;

      // Get recent activities
      List<Map<String, dynamic>> recentActivities = [];
      try {
        final activitiesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('households')
            .doc(_currentHouseholdId)
            .collection('activities')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        for (var doc in activitiesSnapshot.docs) {
          recentActivities.add({
            'message': doc['message'] ?? 'No message',
            'timestamp': doc['timestamp'] ?? Timestamp.now(),
          });
        }
      } catch (e) {
        print('Error loading activities: $e');
        // Activities are optional, so we don't treat this as a fatal error
      }

      // Update state
      setState(() {
        _totalItems = totalItems;
        _lowStockItems = lowStockItems;
        _totalCategories = totalCategories;
        _totalValue = totalValue;
        _recentActivities = recentActivities;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      print('Error loading inventory data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.person, color: primaryColor),
                  title: Text('Profile Settings', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile settings
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications, color: primaryColor),
                  title: Text('Notification Settings', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to notification settings
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  },
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: lightTextColor)),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        appBar: AppBar(
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
          elevation: 4,
          iconTheme: IconThemeData(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          actions: [
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
            IconButton(
              icon: Icon(Icons.settings, size: 24),
              onPressed: () => _showSettingsDialog(context),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _hasError
            ? _buildErrorState()
            : _isLoading
                ? _buildLoadingState()
                : _currentHousehold.isNotEmpty
                    ? _buildDashboardContent()
                    : _buildHouseholdSelection(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.home, color: primaryColor, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to $_currentHousehold',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage your household inventory efficiently',
                        style: TextStyle(
                          fontSize: 14,
                          color: lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
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
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Manage Inventory',
                  Icons.inventory,
                  secondaryColor,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InventoryListPage(
                          householdId: _currentHouseholdId,
                          householdName: _currentHousehold,
                        ),
                      ),
                    );
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
                    // Navigate to add item screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Navigate to add item screen'),
                        backgroundColor: secondaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
          GridView(
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
              _buildStatCard('Low Stock', _lowStockItems.toString(), Icons.warning_amber, Colors.orange),
              _buildStatCard('Categories', _totalCategories.toString(), Icons.category, secondaryColor),
              _buildStatCard('Total Value', 'RM ${_totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
            ],
          ),
          SizedBox(height: 24),
          
          // Recent Activity
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
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red),
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
              onPressed: _loadInventoryData,
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
          _loadInventoryData();
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