import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({Key? key}) : super(key: key);

  // Using the same color scheme as DashboardPage
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data();
  }

  // Function to show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Confirm Logout',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: lightTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await FirebaseAuth.instance.signOut();
                // Navigate to login page and remove all previous routes
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', 
                  (Route<dynamic> route) => false
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              child: Text('Logout'),
            ),
          ],
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
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Text(
                "No user data found",
                style: TextStyle(color: textColor),
              ),
            );
          }

          final userData = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person, 
                    size: 60, 
                    color: primaryColor
                  ),
                ),
                SizedBox(height: 16),

                // Name
                Text(
                  userData['fullName'] ?? "No Name",
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),

                // Email
                Text(
                  userData['email'] ?? "No Email",
                  style: TextStyle(
                    fontSize: 16, 
                    color: lightTextColor,
                  ),
                ),

                SizedBox(height: 24),
                Divider(color: lightTextColor.withOpacity(0.3)),

                // Options
                Expanded(
                  child: Container(
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
                    child: ListView(
                      children: [
                        _buildProfileOption(
                          icon: Icons.settings,
                          title: "Settings",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Navigate to Settings"),
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileOption(
                          icon: Icons.lock,
                          title: "Change Password",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Navigate to Change Password"),
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileOption(
                          icon: Icons.logout,
                          title: "Logout",
                          onTap: () => _showLogoutConfirmation(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: lightTextColor),
      onTap: onTap,
    );
  }
}