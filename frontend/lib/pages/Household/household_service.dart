import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../user_info_page.dart';
import '../../services/household_service_controller.dart';
import 'family_members_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../Dashboard/dashboard_page.dart';
import '../Dashboard/member_dashboard_page.dart';
import '../Dashboard/editor_dashboard_page.dart';

class HouseholdService extends StatefulWidget {
  @override
  _HouseholdServiceState createState() => _HouseholdServiceState();
}

class _HouseholdServiceState extends State<HouseholdService>
    with TickerProviderStateMixin {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Color scheme
  static const Color primaryColor = Color(0xFF2D5D7C);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFFFF6B35);
  static const Color backgroundColor = Color(0xFFF8FAF5);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2C3E50);
  static const Color lightTextColor = Color(0xFF7F8C8D);

  // Animation controllers
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _searchControllerAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBar = false;

  // State management for households
  List<Map<String, dynamic>> _households = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _searchControllerAnimation = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Load households initially
    _loadHouseholds();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _searchControllerAnimation.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Load households and manage state
  Future<void> _loadHouseholds() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final households = await _controller.getUserHouseholdsWithDetails();
      setState(() {
        _households = households;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading households: $e');
    }
  }

  // Enhanced method to create household and navigate to dashboard
  Future<void> _createHouseholdAndNavigate(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Creating Household...',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Create household and get the result
      final result = await _controller.createNewHousehold(context);

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // If household was created successfully, reload households and navigate
      if (result['success'] == true) {
        final householdId = result['householdId'];
        final householdName = result['householdName'];

        // Reload households to show the new one immediately
        await _loadHouseholds();

        // Navigate to household dashboard (creator)
        _navigateToHouseholdDashboard(householdId, householdName, 'creator');
      }
    } catch (e) {
      // Close loading dialog if there's an error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      _showErrorSnackbar(context, 'Failed to create household: $e');
    }
  }

  // UPDATED: Method to navigate to appropriate dashboard based on user role
  void _navigateToHouseholdDashboard(
    String householdId,
    String householdName,
    String userRole,
  ) {
    Widget targetPage;

    // Determine which dashboard to show based on user role
    switch (userRole) {
      case 'creator':
        targetPage = DashboardPage(
          householdId: householdId,
          selectedHousehold: householdName,
        );
        break;
      case 'editor':
        targetPage = EditorDashboardPage(
          householdId: householdId,
          selectedHousehold: householdName,
        );
        break;
      case 'member':
      default:
        targetPage = MemberDashboardPage(
          householdId: householdId,
          selectedHousehold: householdName,
        );
        break;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // UPDATED: Method to select household with role-based navigation
  void _selectHousehold(
    String householdId,
    String householdName,
    String userRole,
  ) {
    _navigateToHouseholdDashboard(householdId, householdName, userRole);
  }

  // NEW: Method for members and editors to leave household
  Future<void> _leaveHousehold(String householdId, String householdName) async {
    try {
      // Check if user can leave (not owner)
      final canLeave = await _controller.canLeaveHousehold(householdId);
      if (!canLeave) {
        _showErrorSnackbar(
          context,
          'Owners cannot leave households. Please transfer ownership or delete the household.',
        );
        return;
      }

      // Show confirmation dialog
      bool? confirm = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Leave Household?'),
            content: Text(
              'Are you sure you want to leave "$householdName"? You will need an invitation code to rejoin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        // Remove from local state immediately for responsive UI
        setState(() {
          _households.removeWhere(
            (household) => household['id'] == householdId,
          );
        });

        await _controller.leaveHousehold(householdId);
        _showSuccessSnackbar(context, 'Successfully left $householdName');

        // Reload to ensure consistency with backend
        await _loadHouseholds();
      }
    } catch (e) {
      // If error, reload to restore correct state
      await _loadHouseholds();
      _showErrorSnackbar(context, 'Error leaving household: $e');
    }
  }

  // Refresh households with animation
  Future<void> _refreshHouseholds() async {
    await _loadHouseholds();
  }

  // Toggle search bar with animation
  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchControllerAnimation.forward();
      } else {
        _searchControllerAnimation.reverse();
        _searchController.clear();
      }
    });
  }

  // Enhanced settings dialog with animations
  void _showSettingsDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, backgroundColor],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
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
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._buildSettingsOptions(),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSettingsOptions() {
    final options = [
      {
        'icon': Icons.person_outline,
        'title': 'Profile Settings',
        'subtitle': 'Update your personal information',
        'action': () {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  UserInfoPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          );
        },
      },
      {
        'icon': Icons.people_outline,
        'title': 'Family Members',
        'subtitle': 'Manage household members',
        'action': () {
          Navigator.pop(context);
          _showFamilyMembersDialog(context);
        },
      },
    ];

    return options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;

      return AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 100)),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 8),
        child: _buildSettingsOption(
          icon: option['icon'] as IconData,
          title: option['title'] as String,
          subtitle: option['subtitle'] as String,
          onTap: option['action'] as VoidCallback,
        ),
      );
    }).toList();
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      primaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: lightTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, size: 16, color: primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _controller.logout(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFamilyMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, backgroundColor],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Household',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a household to manage its family members',
                  style: TextStyle(color: lightTextColor),
                ),
                const SizedBox(height: 24),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _controller.getUserHouseholdsWithDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(primaryColor),
                        ),
                      );
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No households available',
                          style: TextStyle(color: lightTextColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(16),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (householdId) {
                            Navigator.pop(context);
                            if (householdId != null) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => FamilyMembersPage(
                                        householdId: householdId,
                                      ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            }
                          },
                          hint: Text(
                            'Select a household',
                            style: TextStyle(color: lightTextColor),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: lightTextColor),
                      ),
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

  // Enhanced household options dialog
  void _showHouseholdOptions(
    BuildContext context,
    String householdId,
    String householdName,
    String userRole,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        householdName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Role: ${_getRoleDisplayName(userRole)}',
                        style: TextStyle(fontSize: 14, color: lightTextColor),
                      ),
                      const SizedBox(height: 16),
                      ..._buildHouseholdOptions(
                        householdId,
                        householdName,
                        userRole,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildHouseholdOptions(
    String householdId,
    String householdName,
    String userRole,
  ) {
    final options = <Widget>[];

    // Options available for all roles
    options.addAll([
      _buildOptionTile(
        icon: Icons.share,
        title: 'Share Invitation Code',
        color: primaryColor,
        onTap: () {
          Navigator.pop(context);
          _shareHouseholdInvitation(context, householdId);
        },
      ),
      _buildOptionTile(
        icon: Icons.copy,
        title: 'Copy Invitation Code',
        color: accentColor,
        onTap: () {
          Navigator.pop(context);
          _copyInvitationCode(context, householdId);
        },
      ),
    ]);

    // Add divider before destructive actions
    options.add(const Divider());

    // Owner-only options
    if (userRole == 'creator') {
      options.add(
        _buildOptionTile(
          icon: Icons.delete,
          title: 'Delete Household',
          color: Colors.red,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(context, householdId, householdName);
          },
        ),
      );
    } else {
      // Leave household option for non-owners (members and editors)
      options.add(
        _buildOptionTile(
          icon: Icons.exit_to_app,
          title: 'Leave Household',
          color: Colors.orange,
          onTap: () {
            Navigator.pop(context);
            _leaveHousehold(householdId, householdName);
          },
        ),
      );
    }

    return options;
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareHouseholdInvitation(
    BuildContext context,
    String householdId,
  ) async {
    try {
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final invitationCode = householdDoc.data()!['invitationCode'] ?? '';
        final householdName = householdDoc.data()!['householdName'] ?? '';
        final shareText =
            'Join my household "$householdName" on HomeHub! Use code: $invitationCode';
        Share.share(shareText);
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Error sharing invitation: $e');
    }
  }

  void _copyInvitationCode(BuildContext context, String householdId) async {
    try {
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        final invitationCode = householdDoc.data()!['invitationCode'] ?? '';
        await Clipboard.setData(ClipboardData(text: invitationCode));

        _showSuccessSnackbar(context, 'Invitation code copied to clipboard');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Error copying invitation code: $e');
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String householdId,
    String householdName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning, color: Colors.red, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Household?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "$householdName"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: lightTextColor),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteHousehold(context, householdId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Delete'),
                      ),
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

  // Delete household with immediate UI update
  Future<void> _deleteHousehold(
    BuildContext context,
    String householdId,
  ) async {
    try {
      // Remove from local state immediately for responsive UI
      setState(() {
        _households.removeWhere((household) => household['id'] == householdId);
      });

      await _controller.deleteHousehold(householdId);
      _showSuccessSnackbar(context, 'Household deleted successfully');

      // Reload to ensure consistency with backend
      await _loadHouseholds();
    } catch (e) {
      // If error, reload to restore correct state
      await _loadHouseholds();
      _showErrorSnackbar(context, 'Error deleting household: $e');
    }
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // Enhanced create or join dialog
  void _showCreateOrJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, backgroundColor],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(FeatherIcons.home, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Household Options',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to proceed',
                  style: TextStyle(color: lightTextColor),
                ),
                const SizedBox(height: 24),
                _buildAnimatedButton(
                  icon: FeatherIcons.plus,
                  text: 'Create New Household',
                  color: secondaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _createHouseholdAndNavigate(context);
                  },
                ),
                const SizedBox(height: 12),
                _buildAnimatedButton(
                  icon: FeatherIcons.users,
                  text: 'Join Existing Household',
                  color: primaryColor,
                  isOutlined: true,
                  onTap: () {
                    Navigator.pop(context);
                    _controller.showJoinHouseholdDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedButton({
    required IconData icon,
    required String text,
    required Color color,
    bool isOutlined = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: (_) => _scaleController.forward(),
      onExit: (_) => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: isOutlined
            ? OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(text),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color, width: 2),
                  minimumSize: const Size(250, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(250, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showSearchBar
              ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Search households...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleSearchBar,
                    ),
                  ),
                )
              : const Text(
                  "My Households",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        // UPDATED: Removed notification and help & support buttons
        actions: _showSearchBar
            ? []
            : [
                IconButton(
                  icon: const Icon(FeatherIcons.search, size: 20),
                  onPressed: _toggleSearchBar,
                  tooltip: 'Search',
                ),
                IconButton(
                  icon: const Icon(FeatherIcons.plusCircle, size: 20),
                  onPressed: () => _showCreateOrJoinDialog(context),
                  tooltip: 'Create or Join Household',
                ),
                IconButton(
                  icon: const Icon(FeatherIcons.settings, size: 20),
                  onPressed: () => _showSettingsDialog(context),
                  tooltip: 'Settings',
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHouseholds,
        color: primaryColor,
        backgroundColor: Colors.white,
        displacement: 40,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Animated search bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showSearchBar ? 0 : 20,
                curve: Curves.easeInOut,
              ),
              Expanded(child: _buildHouseholdsContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: () => _createHouseholdAndNavigate(context),
          backgroundColor: secondaryColor,
          elevation: 6,
          child: const Icon(FeatherIcons.plus, color: Colors.white, size: 28),
          tooltip: 'Create New Household',
        ),
      ),
    );
  }

  Widget _buildHouseholdsContent() {
    if (_isLoading && _households.isEmpty) {
      return _buildLoadingState();
    }

    if (_households.isEmpty) {
      return _buildNoHouseholdsState();
    }

    final filteredHouseholds = _households.where((household) {
      return household['name'].toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredHouseholds.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildHouseholdsList(filteredHouseholds);
  }

  // Enhanced loading state with shimmer animation
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoHouseholdsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FeatherIcons.home, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'No households yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Create your first household to start managing your inventory and family members',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: lightTextColor),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _createHouseholdAndNavigate(context),
              icon: const Icon(FeatherIcons.plus, size: 18),
              label: const Text('Create New Household'),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.search, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No matching households',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 14, color: lightTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdsList(List<Map<String, dynamic>> households) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: households.length,
      itemBuilder: (context, index) {
        var household = households[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 0),
          child: _buildHouseholdCard(
            household['name'],
            household['createdAt'],
            household['id'],
            household['userRole'] ?? 'member',
            context,
          ),
        );
      },
    );
  }

  Widget _buildHouseholdCard(
    String name,
    dynamic createdAt,
    String householdId,
    String userRole,
    BuildContext context,
  ) {
    DateTime createdDate = _parseCreatedAt(createdAt);

    return MouseRegion(
      onEnter: (_) => _scaleController.forward(),
      onExit: (_) => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectHousehold(householdId, name, userRole),
              onLongPress: () =>
                  _showHouseholdOptions(context, householdId, name, userRole),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FeatherIcons.home,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Created ${_formatDate(createdDate)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: lightTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // UPDATED: Enhanced role badge with editor support
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(userRole).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getRoleDisplayName(userRole),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getRoleColor(userRole),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildHouseholdActions(
                      householdId,
                      userRole,
                      name,
                      context,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get role display name
  String _getRoleDisplayName(String userRole) {
    switch (userRole) {
      case 'creator':
        return 'Owner';
      case 'editor':
        return 'Editor';
      case 'member':
      default:
        return 'Member';
    }
  }

  // Helper method to get role color
  Color _getRoleColor(String userRole) {
    switch (userRole) {
      case 'creator':
        return secondaryColor;
      case 'editor':
        return accentColor;
      case 'member':
      default:
        return primaryColor;
    }
  }

  Widget _buildHouseholdActions(
    String householdId,
    String userRole,
    String householdName,
    BuildContext context,
  ) {
    return Row(
      children: [
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(FeatherIcons.users, color: primaryColor, size: 16),
          ),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    FamilyMembersPage(householdId: householdId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    },
              ),
            );
          },
          tooltip: 'Manage Family Members',
        ),
        PopupMenuButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FeatherIcons.moreVertical,
              color: primaryColor,
              size: 16,
            ),
          ),
          itemBuilder: (context) {
            // Different menu items based on user role
            if (userRole == 'creator') {
              return [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(FeatherIcons.share2, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text('Share Invitation'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(FeatherIcons.trash2, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            } else {
              // For members and editors
              return [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(FeatherIcons.share2, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text('Share Invitation'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(FeatherIcons.logOut, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Leave Household',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ];
            }
          },
          onSelected: (value) {
            if (value == 'share') {
              _shareHouseholdInvitation(context, householdId);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, householdId, householdName);
            } else if (value == 'leave') {
              _leaveHousehold(householdId, householdName);
            }
          },
        ),
      ],
    );
  }

  DateTime _parseCreatedAt(dynamic createdAt) {
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    } else if (createdAt is DateTime) {
      return createdAt;
    } else {
      return DateTime.now();
    }
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
