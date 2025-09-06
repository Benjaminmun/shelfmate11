import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Confirm Logout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
          content: Text('Are you sure you want to logout?', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: lightTextColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileSettings(BuildContext context) {
    final TextEditingController nameController = TextEditingController(text: userData?['fullName'] ?? '');
    final TextEditingController phoneController = TextEditingController(text: userData?['phone'] ?? '');
    final TextEditingController addressController = TextEditingController(text: userData?['address'] ?? '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                            'fullName': nameController.text,
                            'phone': phoneController.text,
                            'address': addressController.text,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                      
                      // Reload user data
                      _loadUserData();
                      
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile updated successfully'),
                          backgroundColor: Colors.green,
                        )
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating profile: $e'),
                          backgroundColor: Colors.red,
                        )
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Save Changes'),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Change Password',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: lightTextColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: Colors.red,
                    )
                  );
                  return;
                }
                
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    )
                  );
                  return;
                }
                
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  try {
                    // Reauthenticate user
                    final cred = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text
                    );
                    
                    await user.reauthenticateWithCredential(cred);
                    
                    // Update password
                    await user.updatePassword(newPasswordController.text);
                    
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password updated successfully'),
                        backgroundColor: Colors.green,
                      )
                    );
                  } on FirebaseAuthException catch (e) {
                    String message = 'Error updating password';
                    if (e.code == 'wrong-password') {
                      message = 'Current password is incorrect';
                    } else if (e.code == 'requires-recent-login') {
                      message = 'This operation requires recent authentication. Please log out and log in again.';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                      )
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating password: $e'),
                        backgroundColor: Colors.red,
                      )
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('Update Password'),
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
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingIndicator()
          : userData == null
              ? _buildNoDataMessage()
              : _buildProfilePage(userData!, context),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: primaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Center _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
    );
  }

  Center _buildNoDataMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("No user data found", style: TextStyle(color: textColor)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Padding _buildProfilePage(Map<String, dynamic> userData, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          SizedBox(height: 16),
          _buildUserName(userData),
          SizedBox(height: 8),
          _buildUserEmail(userData),
          if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            _buildUserPhone(userData),
          ],
          SizedBox(height: 24),
          Divider(color: lightTextColor.withOpacity(0.3)),
          Expanded(child: _buildProfileOptions(context)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 60, color: primaryColor),
    );
  }

  Text _buildUserName(Map<String, dynamic> userData) {
    return Text(
      userData['fullName'] ?? "No Name",
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
    );
  }

  Text _buildUserEmail(Map<String, dynamic> userData) {
    return Text(
      userData['email'] ?? "No Email",
      style: TextStyle(fontSize: 16, color: lightTextColor),
    );
  }

  Text _buildUserPhone(Map<String, dynamic> userData) {
    return Text(
      userData['phone'] ?? "",
      style: TextStyle(fontSize: 16, color: lightTextColor),
    );
  }



  Widget _buildProfileOptions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: ListView(
        children: [
          _buildProfileOption(icon: Icons.edit, title: "Edit Profile", onTap: () {
            _showProfileSettings(context);
          }),
          Divider(height: 1, indent: 16, endIndent: 16),
          _buildProfileOption(icon: Icons.lock, title: "Change Password", onTap: () {
            _showChangePasswordDialog(context);
          }),
          Divider(height: 1, indent: 16, endIndent: 16),
          _buildProfileOption(icon: Icons.logout, title: "Logout", onTap: () => _showLogoutConfirmation(context)),
        ],
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
        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
      trailing: Icon(Icons.chevron_right, color: lightTextColor),
      onTap: onTap,
    );
  }
}