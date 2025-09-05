import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../services/household_service_controller.dart';
import 'family_members_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';


class HouseholdService extends StatefulWidget {
  @override
  _HouseholdServiceState createState() => _HouseholdServiceState();
}

class _HouseholdServiceState extends State<HouseholdService> {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFF8FAF5);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF2C3E50);
  final Color lightTextColor = Color(0xFF7F8C8D);

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Refresh households
  Future<void> _refreshHouseholds() async {
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.delayed(Duration(milliseconds: 1500));
    
    setState(() {
      _isRefreshing = false;
    });
  }

  // Enhanced settings dialog
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: lightTextColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildSettingsOption(
                  icon: Icons.person_outline,
                  title: 'Profile Settings',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile settings
                  },
                ),
                _buildSettingsOption(
                  icon: Icons.people_outline,
                  title: 'Family Members',
                  subtitle: 'Manage household members',
                  onTap: () {
                    Navigator.pop(context);
                    _showFamilyMembersDialog(context);
                  },
                ),
                _buildSettingsOption(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Configure alert preferences',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to notification settings
                  },
                ),
                _buildSettingsOption(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get assistance with the app',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to help section
                  },
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => _controller.logout(context),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: lightTextColor,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: lightTextColor),
      onTap: onTap,
    );
  }

  void _showFamilyMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Household',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Choose a household to manage its family members',
                  style: TextStyle(
                    color: lightTextColor,
                  ),
                ),
                SizedBox(height: 24),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _controller.getUserHouseholdsWithDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No households available',
                          style: TextStyle(color: lightTextColor),
                        ),
                      );
                    }
                    
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          items: snapshot.data!.map((household) {
                            return DropdownMenuItem<String>(
                              value: household['id'],
                              child: Text(
                                household['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
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
                          hint: Text(
                            'Select a household',
                            style: TextStyle(color: lightTextColor),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show options dialog for a household
  void _showHouseholdOptions(BuildContext context, String householdId, String householdName) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share, color: primaryColor),
                title: Text('Share Invitation Code'),
                onTap: () {
                  Navigator.pop(context);
                  _shareHouseholdInvitation(context, householdId);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: primaryColor),
                title: Text('Copy Invitation Code'),
                onTap: () {
                  Navigator.pop(context);
                  _copyInvitationCode(context, householdId);
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Household', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, householdId, householdName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Share household invitation
  void _shareHouseholdInvitation(BuildContext context, String householdId) async {
    try {
      final householdDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final invitationCode = householdDoc.data()!['invitationCode'] ?? '';
        final householdName = householdDoc.data()!['householdName'] ?? '';
        final shareText = 'Join my household "$householdName" on HomeHub! Use code: $invitationCode';
        Share.share(shareText);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Copy invitation code to clipboard
  void _copyInvitationCode(BuildContext context, String householdId) async {
    try {
      final householdDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final invitationCode = householdDoc.data()!['invitationCode'] ?? '';
        await Clipboard.setData(ClipboardData(text: invitationCode));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation code copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying invitation code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String householdId, String householdName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Household'),
          content: Text('Are you sure you want to delete "$householdName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteHousehold(context, householdId);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Delete household
  Future<void> _deleteHousehold(BuildContext context, String householdId) async {
    try {
      await _controller.deleteHousehold(householdId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Household deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {}); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting household: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to show create or join dialog
  void _showCreateOrJoinDialog(BuildContext context) {
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
                  'Household Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5D7C),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _controller.createNewHousehold(context);
                  },
                  icon: Icon(FeatherIcons.plus),
                  label: Text('Create New Household'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    minimumSize: Size(250, 50),
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _controller.showJoinHouseholdDialog(context);
                  },
                  icon: Icon(FeatherIcons.users),
                  label: Text('Join Existing Household'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF2D5D7C),
                    side: BorderSide(color: Color(0xFF2D5D7C)),
                    minimumSize: Size(250, 50),
                  ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(FeatherIcons.bell, size: 22),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: Icon(FeatherIcons.plusCircle, size: 22),
            onPressed: () {
              _showCreateOrJoinDialog(context);
            },
            tooltip: 'Create or Join Household',
          ),
          IconButton(
            icon: Icon(FeatherIcons.settings, size: 22),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHouseholds,
        color: primaryColor,
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search households...',
                    prefixIcon: Icon(FeatherIcons.search, color: lightTextColor),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(FeatherIcons.x, size: 18),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _controller.getUserHouseholdsWithDetails(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildNoHouseholdsState();
                  }

                  // Filter households based on search query
                  final filteredHouseholds = snapshot.data!.where((household) {
                    return household['name'].toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filteredHouseholds.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return _buildHouseholdsList(filteredHouseholds);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.createNewHousehold(context),
        backgroundColor: secondaryColor,
        elevation: 4,
        child: Icon(FeatherIcons.plus, color: Colors.white, size: 28),
        tooltip: 'Create New Household',
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(width: 16),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        color: Colors.grey.shade200,
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 12,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.alertCircle, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t load your households. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: Icon(FeatherIcons.refreshCw, size: 18),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          Icon(FeatherIcons.home, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'No households yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create your first household to start managing your inventory and family members',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _controller.createNewHousehold(context),
            icon: Icon(FeatherIcons.plus, size: 18),
            label: Text('Create New Household'),
            style: ElevatedButton.styleFrom(
              backgroundColor: secondaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.search, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'No matching households',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdsList(List<Map<String, dynamic>> households) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: households.length,
      itemBuilder: (context, index) {
        var household = households[index];
        return _buildHouseholdCard(
          household['name'],
          household['createdAt'],
          household['id'],
          context,
        );
      },
    );
  }

  Widget _buildHouseholdCard(String name, dynamic createdAt, String householdId, BuildContext context) {
    DateTime createdDate;
    
    if (createdAt is Timestamp) {
      createdDate = createdAt.toDate();
    } else if (createdAt is DateTime) {
      createdDate = createdAt;
    } else {
      createdDate = DateTime.now();
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _controller.selectHousehold(name, context, householdId),
          onLongPress: () => _showHouseholdOptions(context, householdId, name),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FeatherIcons.home, color: primaryColor, size: 28),
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
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Created ${_formatDate(createdDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(FeatherIcons.users, color: primaryColor, size: 20),
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
                PopupMenuButton(
                  icon: Icon(FeatherIcons.moreVertical, color: lightTextColor, size: 20),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(FeatherIcons.share2, size: 18, color: primaryColor),
                          SizedBox(width: 8),
                          Text('Share Invitation'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(FeatherIcons.trash2, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'share') {
                      _shareHouseholdInvitation(context, householdId);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context, householdId, name);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return 'on ${DateFormat('MMM d, y').format(date)}';
    }
  }
}