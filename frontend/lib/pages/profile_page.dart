import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Household/household_service.dart';
import 'user_info_page.dart';
import 'change_password_page.dart'; // Import the new page

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF6B35);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);
  final Color successColor = Color(0xFF10B981);
  final Color warningColor = Color(0xFFF59E0B);
  final Color errorColor = Color(0xFFEF4444);

  Map<String, dynamic>? userData;
  bool isLoading = true;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _colorAnimation = ColorTween(
      begin: primaryColor.withOpacity(0.5),
      end: primaryColor,
    ).animate(_animationController);

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        setState(() {
          userData = snapshot.data();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToUserInfoPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => UserInfoPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    ).then((_) {
      _loadUserData();
    });
  }

  void _navigateToHouseholdService() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HouseholdService(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // NEW: Navigate to Change Password Page
  void _navigateToChangePasswordPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChangePasswordPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.8),
            secondaryColor.withOpacity(0.7),
            accentColor.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _AvatarPatternPainter(primaryColor.withOpacity(0.1)),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 50, color: Colors.white),
                SizedBox(height: 4),
                Text(
                  _getInitials(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Animated ring
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AvatarRingPainter(
                    _colorAnimation.value!,
                    _animationController.value,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    if (userData?['fullName'] != null) {
      final name = userData!['fullName'] as String;
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0].toUpperCase();
    }
    return 'U';
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AnimatedDialog(
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        errorColor.withOpacity(0.15),
                        errorColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 32,
                    color: errorColor,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Confirm Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout from your account?',
                  style: GoogleFonts.poppins(
                    color: lightTextColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: lightTextColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: lightTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _performLogout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                          shadowColor: errorColor.withOpacity(0.4),
                        ),
                        child: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
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

  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      _showErrorSnackBar('Logout failed. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: isLoading
                  ? _buildLoadingIndicator()
                  : userData == null
                  ? _buildNoDataMessage()
                  : _buildProfileContent(),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 10 * (1 - _animationController.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Text(
                'Profile',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          );
        },
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_rounded, size: 22, color: Colors.white),
          ),
          onPressed: _navigateToUserInfoPage,
          tooltip: 'Edit Profile',
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Loading Your Profile...",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: lightTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Getting everything ready for you",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: lightTextColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: lightTextColor.withOpacity(0.1),
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    lightTextColor.withOpacity(0.15),
                    lightTextColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 50,
                color: lightTextColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Profile Not Found",
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "We couldn't find your profile data. Please complete your profile setup to continue.",
              style: GoogleFonts.poppins(
                color: lightTextColor,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                shadowColor: primaryColor.withOpacity(0.4),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          SizedBox(height: 28),
          _buildUserInfo(),
          SizedBox(height: 36),
          _buildStatsCards(),
          SizedBox(height: 36),
          _buildProfileActions(),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          userData!['fullName'] ?? "No Name",
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        _buildInfoRow(Icons.email_rounded, userData!['email'] ?? "No Email"),
        if (userData!['phone'] != null &&
            userData!['phone'].toString().isNotEmpty)
          _buildInfoRow(Icons.phone_rounded, userData!['phone']),
        if (userData!['address'] != null &&
            userData!['address'].toString().isNotEmpty)
          _buildInfoRow(Icons.location_on_rounded, userData!['address']),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: lightTextColor.withOpacity(0.7)),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: lightTextColor,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_month_rounded,
            value: 'Member Since',
            label: _getMemberSince(),
            color: primaryColor,
            index: 0,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.verified_rounded,
            value: 'Status',
            label: 'Active',
            color: successColor,
            index: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required int index,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 400 + (index * 200)),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: lightTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMemberSince() {
    final timestamp = userData!['createdAt'];
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${_getMonthName(date.month)} ${date.year}';
    }
    return 'Recently';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildProfileActions() {
    final actions = [
      _ProfileAction(
        icon: Icons.edit_rounded,
        title: "Edit Profile",
        subtitle: "Update personal information",
        color: primaryColor,
        onTap: _navigateToUserInfoPage,
      ),
      _ProfileAction(
        icon: Icons.home_work_rounded,
        title: "Household Service",
        subtitle: "Manage services & bookings",
        color: secondaryColor,
        onTap: _navigateToHouseholdService,
      ),
      _ProfileAction(
        icon: Icons.lock_reset_rounded,
        title: "Change Password",
        subtitle: "Update security settings",
        color: accentColor,
        onTap: _navigateToChangePasswordPage, // Updated to use new page
      ),
      _ProfileAction(
        icon: Icons.logout_rounded,
        title: "Logout",
        subtitle: "Sign out from account",
        color: errorColor,
        isDestructive: true,
        onTap: () => _showLogoutConfirmation(context),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
      ),
      child: Column(
        children: List.generate(actions.length, (index) {
          final action = actions[index];
          return Column(
            children: [
              if (index > 0) Divider(height: 1, indent: 20, endIndent: 20),
              _buildProfileActionItem(action, index),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProfileActionItem(_ProfileAction action, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        action.color.withOpacity(0.15),
                        action.color.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Icon(action.icon, color: action.color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: action.isDestructive ? errorColor : textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: action.isDestructive
                      ? errorColor
                      : lightTextColor.withOpacity(0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _ProfileAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });
}

class AnimatedDialog extends StatelessWidget {
  final Widget child;

  const AnimatedDialog({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}

class _AvatarPatternPainter extends CustomPainter {
  final Color color;

  _AvatarPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw concentric circles
    for (double i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * 0.3 * i, paint);
    }

    // Draw cross lines
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _AvatarRingPainter(this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw animated ring
    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
