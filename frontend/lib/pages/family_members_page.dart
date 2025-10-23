import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:timeago/timeago.dart' as timeago;
import '../services/household_service_controller.dart';

class FamilyMembersPage extends StatefulWidget {
  final String householdId;

  const FamilyMembersPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _FamilyMembersPageState createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> with SingleTickerProviderStateMixin {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF5D8AA8);
  final Color accentColor = Color(0xFF4CAF50);
  final Color warningColor = Color(0xFFFF9800);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textPrimary = Color(0xFF2D3748);
  final Color textSecondary = Color(0xFF718096);
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _householdMembers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _userRole = 'member';
  bool _isOwner = false;
  bool _isRemovingMember = false;
  int? _removingMemberIndex;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _pageSize = 10;
  AnimationController? _fabController;
  bool _showFab = true;

  // Enhanced color palette for avatar backgrounds
  final List<Color> _avatarColors = [
    Color(0xFF2D5D7C),
    Color(0xFF5D8AA8),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFF009688),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _loadData();
    
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        _showFloatingActionButton();
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        _hideFloatingActionButton();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabController?.dispose();
    super.dispose();
  }

  void _showFloatingActionButton() {
    if (!_showFab) {
      setState(() => _showFab = true);
      _fabController?.forward();
    }
  }

  void _hideFloatingActionButton() {
    if (_showFab) {
      setState(() => _showFab = false);
      _fabController?.reverse();
    }
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore && (!_hasMore || _isLoadingMore)) return;
    
    try {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
          _householdMembers = [];
          _lastDocument = null;
          _hasMore = true;
        }
      });

      // Get user role first
      final role = await _controller.getUserRole(widget.householdId);
      
      // Load household members with enhanced data fetching
      final result = await _controller.getHouseholdMembersPaginated(
        widget.householdId, 
        limit: _pageSize, 
        startAfter: loadMore ? _lastDocument : null
      );
      
      // Enhance member data with user profiles
      final enhancedMembers = await _enhanceMemberData(result.members);
      
      setState(() {
        _userRole = role;
        _isOwner = role == 'creator';
        
        if (loadMore) {
          _householdMembers.addAll(enhancedMembers);
          _isLoadingMore = false;
        } else {
          _householdMembers = enhancedMembers;
          _isLoading = false;
        }
        
        _lastDocument = result.lastDocument;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      
      _showErrorSnackBar('Error loading household members: $e', isRetryable: true);
    }
  }

  // Enhance member data by fetching additional user information
  Future<List<Map<String, dynamic>>> _enhanceMemberData(List<Map<String, dynamic>> members) async {
    final enhancedMembers = <Map<String, dynamic>>[];
    
    for (var member in members) {
      try {
        // Always try to fetch the latest user profile data
        if (member['userId'] != null) {
          final userProfile = await _fetchUserProfile(member['userId']);
          if (userProfile != null) {
            // Merge user profile data with member data
            member['fullName'] = userProfile['fullName'] ?? member['fullName'];
            member['phone'] = userProfile['phone'] ?? member['phone'];
            member['email'] = userProfile['email'] ?? member['email'];
            // You can add more fields here as needed
          }
        }
        enhancedMembers.add(member);
      } catch (e) {
        print('Error enhancing member data: $e');
        enhancedMembers.add(member);
      }
    }
    
    return enhancedMembers;
  }

  // Fetch user profile from Firestore
  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  void _showErrorSnackBar(String message, {bool isRetryable = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: isRetryable ? SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadData,
        ) : null,
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'creator':
        return 'Household Owner';
      case 'editor':
        return 'Editor';
      case 'member':
        return 'Family Member';
      default:
        return role.replaceAll('_', ' ').toTitleCase();
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not available';
    
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return '${timeago.format(dateTime)} • ${_formatDateTime(dateTime)}';
      }
      return date.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getDisplayName(Map<String, dynamic> member) {
    final fullName = member['fullName']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    return member['email']?.split('@').first ?? 'Unknown User';
  }

  String _getInitials(String displayName) {
    final names = displayName.split(' ').where((name) => name.isNotEmpty).toList();
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (displayName.isNotEmpty) {
      return displayName.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  Color _getAvatarColor(String displayName) {
    final index = displayName.hashCode % _avatarColors.length;
    return _avatarColors[index.abs()];
  }

  Widget _buildRoleBadge(String role) {
    final bool isCreator = role == 'creator';
    
    final bool isEditor = role == 'editor';
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: isCreator 
                ? LinearGradient(colors: [Colors.blue, Colors.lightBlue])
                : isEditor
                    ? LinearGradient(colors: [Colors.purple, Colors.deepPurple])
                    : LinearGradient(colors: [Colors.green, Colors.lightGreen]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCreator 
                ? Colors.amber.withOpacity(0.3)
                    : isEditor
                        ? Colors.purple.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCreator ? Icons.star : 
            isEditor ? Icons.edit : Icons.person,
            size: 14,
            color: Colors.white,
          ),
          SizedBox(width: 4),
          Text(
            _formatRole(role),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Role change functionality methods
  void _showRoleChangeDialog(Map<String, dynamic> member) {
    final String displayName = _getDisplayName(member);
    final String currentRole = member['userRole'] ?? 'member';
    final List<String> availableRoles = _getAvailableRoles();
    String? selectedRole;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: primaryColor),
                  SizedBox(width: 8),
                  Text("Change Member Role"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Update permissions for:"),
                  SizedBox(height: 12),
                  // Member info card
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getAvatarColor(displayName),
                          child: Text(
                            _getInitials(displayName),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              _buildRoleBadge(currentRole),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Select New Role:",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...availableRoles.map((role) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedRole = role;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedRole == role 
                                  ? primaryColor.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedRole == role 
                                    ? primaryColor 
                                    : Colors.grey[300]!,
                                width: selectedRole == role ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getRoleIcon(role),
                                  color: _getRoleColor(role),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatRole(role),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _getRoleDescription(role),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedRole == role)
                                  Icon(
                                    Icons.check_circle,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  if (availableRoles.isEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      "You don't have permission to change roles.",
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel", style: TextStyle(color: textSecondary)),
                ),
                if (availableRoles.isNotEmpty)
                  ElevatedButton(
                    onPressed: selectedRole != null && selectedRole != currentRole
                        ? () => _changeMemberRole(member, selectedRole!)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Update Role"),
                  ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _getAvailableRoles() {
    if (_userRole == 'creator') {
      return [ 'editor', 'member'];
    }
    return []; // Members can't change roles
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'creator':
        return Icons.star;

      case 'editor':
        return Icons.edit;
      case 'member':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'creator':
        return Colors.amber;
      case 'admin':
        return Colors.blue;
      case 'editor':
        return Colors.green;
      case 'member':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'creator':
        return 'Full household ownership and management';
      case 'editor':
        return 'Can edit household content and data';
      case 'member':
        return 'Can view household content';
      default:
        return 'Basic household access';
    }
  }

  Future<void> _changeMemberRole(Map<String, dynamic> member, String newRole) async {
    final String userId = member['userId'];
    final String displayName = _getDisplayName(member);
    final String currentRole = member['userRole'] ?? 'member';
    

    if (newRole == currentRole) {
      _showErrorSnackBar("User already has the $newRole role");
      return;
    }

    Navigator.of(context).pop(); // Close the dialog

    try {
      await _controller.updateMemberRole(widget.householdId, userId, newRole);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$displayName's role changed to ${_formatRole(newRole)}",
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Refresh the data to show the updated role
      _loadData();
    } catch (e) {
      _showErrorSnackBar("Failed to change role: $e");
    }
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> member) {
    final String displayName = _getDisplayName(member);
    final String initials = _getInitials(displayName);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          _buildRoleBadge(member['userRole'] ?? 'member'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Details
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDetailSection(
                        title: 'Contact Information',
                        icon: Icons.contact_mail,
                        children: [
                          _buildDetailItem(
                            icon: Icons.person,
                            label: 'Full Name',
                            value: member['fullName'] ?? 'Not provided',
                            isImportant: true,
                          ),
                          _buildDetailItem(
                            icon: Icons.email,
                            label: 'Email Address',
                            value: member['email'] ?? 'Not provided',
                            isImportant: true,
                          ),
                          _buildDetailItem(
                            icon: Icons.phone,
                            label: 'Phone Number',
                            value: member['phone']?.toString() ?? 'Not provided',
                            isImportant: false,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      _buildDetailSection(
                        title: 'Household Information',
                        icon: Icons.family_restroom,
                        children: [
                          _buildDetailItem(
                            icon: Icons.calendar_today,
                            label: 'Joined Date',
                            value: _formatDate(member['joinedAt']),
                            isImportant: false,
                          ),
                          _buildDetailItem(
                            icon: Icons.badge,
                            label: 'Member ID',
                            value: member['userId'] ?? 'Unknown',
                            isImportant: false,
                          ),
                        ],
                      ),
                      
                      if ((_isOwner || _userRole == 'admin') && member['userRole'] != 'creator')
                        Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              // Role Change Button
                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(bottom: 12),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showRoleChangeDialog(member);
                                  },
                                  icon: Icon(Icons.admin_panel_settings),
                                  label: Text('Change Role'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Remove Button
                              Container(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _removeMember(_householdMembers.indexOf(member));
                                  },
                                  icon: Icon(Icons.person_remove),
                                  label: Text('Remove from Household'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({required IconData icon, required String label, required String value, required bool isImportant}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isImportant ? textPrimary : textSecondary,
                    fontWeight: isImportant ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _removeMember(int index) async {
    final member = _householdMembers[index];
    final displayName = _getDisplayName(member);
    
    if (member['userId'] == null) {
      _showErrorSnackBar("Cannot remove member: Missing user ID");
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red),
              SizedBox(width: 8),
              Text("Remove Member"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Are you sure you want to remove this member from the household?"),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getAvatarColor(displayName),
                      radius: 24,
                      child: Text(
                        _getInitials(displayName),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            member['email'] ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          if (member['phone'] != null) ...[
                            SizedBox(height: 2),
                            Text(
                              member['phone'].toString(),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Remove Member"),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      setState(() {
        _isRemovingMember = true;
        _removingMemberIndex = index;
      });
      
      try {
        await _controller.removeHouseholdMember(widget.householdId, member['userId']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text("$displayName has been removed from the household")),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        
        _loadData();
      } catch (e) {
        _showErrorSnackBar("Failed to remove member: $e");
      } finally {
        setState(() {
          _isRemovingMember = false;
          _removingMemberIndex = null;
        });
      }
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final bool isCreator = member['userRole'] == 'creator';
    final bool isRemovingThisMember = _isRemovingMember && _removingMemberIndex == index;
    final String displayName = _getDisplayName(member);
    final String initials = _getInitials(displayName);
    final Color avatarColor = _getAvatarColor(displayName);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Background Card with enhanced design
          Container(
            margin: EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.05),
                  secondaryColor.withOpacity(0.08),
                ],
              ),
            ),
          ),
          
          // Main Card Content
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: primaryColor.withOpacity(0.03),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showMemberDetails(context, member),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Avatar Section
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              avatarColor,
                              Color.lerp(avatarColor, Colors.black, 0.1)!,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isCreator 
                              ? Icon(Icons.star, color: Colors.white, size: 28)
                              : Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      // Member Details - Enhanced Layout
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name and Role Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      _buildRoleBadge(member['userRole'] ?? 'member'),
                                    ],
                                  ),
                                ),
                                
                                // Action Menu
                                if ((_isOwner || _userRole == 'admin') && !isCreator && member['userId'] != null)
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: isRemovingThisMember
                                        ? Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : IconButton(
                                            icon: Icon(Icons.more_vert, size: 18),
                                            onPressed: () => _showMemberDetails(context, member),
                                            tooltip: 'View details',
                                            padding: EdgeInsets.zero,
                                          ),
                                  ),
                              ],
                            ),
                            
                            SizedBox(height: 12),
                            
                            // Contact Information with enhanced icons
                            if (member['email'] != null || member['phone'] != null)
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    if (member['email'] != null)
                                      _buildEnhancedContactItem(
                                        Icons.email_rounded,
                                        member['email']!,
                                        primaryColor,
                                      ),
                                    if (member['phone'] != null && member['phone'].toString().isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: _buildEnhancedContactItem(
                                          Icons.phone_rounded,
                                          member['phone'].toString(),
                                          accentColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            
                            SizedBox(height: 12),
                            
                            // Additional Info with improved chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (member['joinedAt'] != null)
                                  _buildEnhancedInfoChip(
                                    Icons.calendar_month_rounded,
                                    'Joined ${_formatDate(member['joinedAt']).split(' • ').first}',
                                    secondaryColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedContactItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Loading more members...',
                style: TextStyle(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_hasMore) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () => _loadData(loadMore: true),
          icon: Icon(Icons.refresh),
          label: Text("Load More Members"),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: accentColor, size: 48),
            SizedBox(height: 8),
            Text(
              'All members loaded',
              style: TextStyle(
                color: textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor.withOpacity(0.1), secondaryColor.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 80,
                color: primaryColor.withOpacity(0.5),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'No Family Members Yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Your household family members will appear here once they join.\nStart by inviting your family members to create a connected household.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textSecondary,
                height: 1.6,
              ),
            ),
            SizedBox(height: 32),
            if (_isOwner)
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Invite functionality coming soon!'),
                        ],
                      ),
                      backgroundColor: accentColor,
                    ),
                  );
                },
                icon: Icon(Icons.person_add_alt_1),
                label: Text('Invite Family Members'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Family Members',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Gathering your household information...',
            style: TextStyle(
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Family Members",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: Icon(Icons.person_add_alt_1),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Add member functionality coming soon!'),
                      ],
                    ),
                    backgroundColor: accentColor,
                  ),
                );
              },
              tooltip: 'Add Member',
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _householdMembers.isEmpty
              ? _buildEmptyState()
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!_isLoadingMore && 
                        _hasMore && 
                        scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100) {
                      _loadData(loadMore: true);
                      return true;
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _loadData(),
                    color: primaryColor,
                    backgroundColor: backgroundColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _householdMembers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _householdMembers.length) {
                          return _buildLoadMoreButton();
                        }
                        return _buildMemberCard(_householdMembers[index], index);
                      },
                    ),
                  ),
                ),
      floatingActionButton: _isOwner ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedOpacity(
      opacity: _showFab ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person_add, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Invite family members functionality coming soon!'),
                ],
              ),
              backgroundColor: accentColor,
            ),
          );
        },
        icon: Icon(Icons.person_add_alt_1),
        label: Text('Invite'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }
}

// Extension method to convert string to title case
extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}