import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_service.dart';
import 'login_page.dart';
import 'inventory_list_page.dart';

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
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFE2E6E0);
  final Color cardColor = Colors.white;

  String? _currentHousehold;
  String? _currentHouseholdId;
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _totalCategories = 0;
  double _totalValue = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _currentHousehold = widget.selectedHousehold;
    _currentHouseholdId = widget.householdId;
    
    if (_currentHouseholdId != null) {
      _loadInventoryData();
    }
  }

  Future<void> _loadInventoryData() async {
    if (_currentHouseholdId == null) return;

    try {
      // Get current user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

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
        final quantity = data['quantity'] ?? 0;
        final price = (data['price'] ?? 0).toDouble();
        
        if (quantity < 5) lowStockItems++;
        if (data['category'] != null) categories.add(data['category']);
        totalValue += quantity * price;
      }

      totalCategories = categories.length;

      // Get recent activities
      final activitiesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('households')
          .doc(_currentHouseholdId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> recentActivities = [];
      for (var doc in activitiesSnapshot.docs) {
        recentActivities.add({
          'message': doc['message'],
          'timestamp': doc['timestamp'],
        });
      }

      // Update state
      setState(() {
        _totalItems = totalItems;
        _lowStockItems = lowStockItems;
        _totalCategories = totalCategories;
        _totalValue = totalValue;
        _recentActivities = recentActivities;
      });
    } catch (e) {
      print('Error loading inventory data: $e');
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
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                  title: Text('Profile Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile settings
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications, color: primaryColor),
                  title: Text('Notification Settings'),
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
                  child: Text('Cancel'),
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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _currentHousehold != null ? '$_currentHousehold Dashboard' : 'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_currentHousehold != null)
            IconButton(
              icon: Icon(Icons.swap_horiz),
              onPressed: () {
                // Navigate back to household selection
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HouseholdService()),
                );
              },
              tooltip: 'Switch Household',
            ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _currentHousehold != null
          ? _buildDashboardContent()
          : _buildHouseholdSelection(),
    );
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          // Manage Inventory Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InventoryListPage(
                      householdId: _currentHouseholdId!,
                      householdName: _currentHousehold!,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.inventory, size: 24),
              label: Text(
                'Manage Inventory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Set a fixed height for the grid
          Container(
            height: 250,
            child: GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              children: [
                _buildStatCard('Total Items', _totalItems.toString(), Icons.inventory, primaryColor),
                _buildStatCard('Low Stock', _lowStockItems.toString(), Icons.warning_amber, Colors.orange),
                _buildStatCard('Categories', _totalCategories.toString(), Icons.category, accentColor),
                _buildStatCard('Total Value', '\$${_totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: _recentActivities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.black38),
                        SizedBox(height: 16),
                        Text(
                          'No recent activity',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: _recentActivities.map((activity) {
                      return _buildActivityItem(
                        activity['message'],
                        _formatTimestamp(activity['timestamp']),
                      );
                    }).toList(),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading your households...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading households',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black38,
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_outlined, size: 80, color: Colors.black38),
                SizedBox(height: 16),
                Text(
                  'No households yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Create your first household to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _householdServiceController.createNewHousehold(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
          );
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
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose a household to manage its inventory',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
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
                      household['name'],
                      household['createdAt'],
                      household['id'],
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
                color: Colors.black.withOpacity(0.1),
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
                  color: Colors.black87,
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
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
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
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
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
          ),
        ),
        subtitle: Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
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