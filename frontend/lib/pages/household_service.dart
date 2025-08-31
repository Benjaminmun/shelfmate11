import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/household_service_controller.dart';
import 'family_members_page.dart';

class HouseholdService extends StatefulWidget {
  @override
  _HouseholdServiceState createState() => _HouseholdServiceState();
}

class _HouseholdServiceState extends State<HouseholdService> {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFE2E6E0);

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
                  leading: Icon(Icons.people, color: primaryColor),
                  title: Text('Family Members'),
                  onTap: () {
                    Navigator.pop(context);
                    _showFamilyMembersDialog(context);
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
                    _controller.logout(context);
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

  void _showFamilyMembersDialog(BuildContext context) {
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
                  'Family Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 20),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _controller.getUserHouseholdsWithDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Text('No households found');
                    }
                    
                    return DropdownButtonFormField<String>(
                      items: snapshot.data!.map((household) {
                        return DropdownMenuItem<String>(
                          value: household['id'],
                          child: Text(household['name']),
                        );
                      }).toList(),
                      onChanged: (householdId) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FamilyMembersPage(householdId: householdId!),
                          ),
                        );
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Household',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
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
          "My Households",
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
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _controller.getUserHouseholdsWithDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildNoHouseholdsState();
          }

          return _buildHouseholdsList(snapshot);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _controller.createNewHousehold(context),
        backgroundColor: accentColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text("New Household", style: TextStyle(color: Colors.white)),
        elevation: 4,
      ),
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildErrorState() {
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

  Widget _buildNoHouseholdsState() {
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
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _controller.createNewHousehold(context),
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
      )
    );
  }

  Widget _buildHouseholdsList(AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Households',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select a household to manage its inventory',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var household = snapshot.data![index];
                return _buildHouseholdCard(
                  household['name'],
                  household['createdAt'],
                  household['id'],
                  context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdCard(String name, dynamic createdAt, String householdId, BuildContext context) {
    DateTime createdDate;
    
    // Handle different types of createdAt values
    if (createdAt is Timestamp) {
      createdDate = createdAt.toDate();
    } else if (createdAt is DateTime) {
      createdDate = createdAt;
    } else {
      // Fallback to current date if unknown type
      createdDate = DateTime.now();
    }
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _controller.selectHousehold(name, context, householdId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.home_outlined, color: primaryColor, size: 30),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(createdDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.people_outline, color: primaryColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FamilyMembersPage(householdId: householdId),
                    ),
                  );
                },
                tooltip: 'Manage Family Members',
              ),
              Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}