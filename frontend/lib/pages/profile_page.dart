import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);
  final Color secondaryColor = Color(0xFF4CAF50);

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool _isUploadingImage = false;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _updateProfilePicture() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User not authenticated");

        // Show loading indicator
        setState(() => _isUploadingImage = true);

        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pics/${user.uid}.jpg');
        
        await ref.putFile(File(pickedFile.path));
        
        // Get download URL
        final downloadUrl = await ref.getDownloadURL();

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'profilePicUrl': downloadUrl,
              'lastUpdated': FieldValue.serverTimestamp(),
            });

        // Update local state
        setState(() {
          userData!['profilePicUrl'] = downloadUrl;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile picture: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvatar() {
    final profilePicUrl = userData?['profilePicUrl'];
    final isLoading = _isUploadingImage;
    
    return Stack(
      children: [
        GestureDetector(
          onTap: isLoading ? null : _updateProfilePicture,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: primaryColor.withOpacity(0.1),
            backgroundImage: profilePicUrl != null 
                ? NetworkImage(profilePicUrl) 
                : null,
            child: isLoading
                ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                : (profilePicUrl == null 
                    ? Icon(Icons.person, size: 50, color: primaryColor)
                    : null),
          ),
        ),
        if (!isLoading)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
            ),
          ),
      ],
    );
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
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: lightTextColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.phone, color: primaryColor),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.location_on, color: primaryColor),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 24),
                    isSaving
                        ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState?.validate() ?? false) {
                                  setModalState(() => isSaving = true);

                                  try {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .update({
                                            'fullName': nameController.text,
                                            'phone': phoneController.text,
                                            'address': addressController.text,
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                      
                                      setModalState(() => isSaving = false);
                                      _loadUserData();
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Profile updated successfully'),
                                          backgroundColor: Colors.green,
                                        )
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Save Changes', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
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
                  prefixIcon: Icon(Icons.lock, color: primaryColor),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset, color: primaryColor),
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
          Icon(Icons.error_outline, size: 64, color: lightTextColor),
          SizedBox(height: 16),
          Text("No user data found", style: TextStyle(fontSize: 18, color: textColor)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage(Map<String, dynamic> userData, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          SizedBox(height: 20),
          _buildUserName(userData),
          SizedBox(height: 8),
          _buildUserEmail(userData),
          if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            _buildUserPhone(userData),
          ],
          if (userData['address'] != null && userData['address'].toString().isNotEmpty) ...[
            SizedBox(height: 8),
            _buildUserAddress(userData),
          ],
          SizedBox(height: 24),
          Divider(color: lightTextColor.withOpacity(0.3)),
          _buildProfileOptions(context),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserName(Map<String, dynamic> userData) {
    return Text(
      userData['fullName'] ?? "No Name",
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildUserEmail(Map<String, dynamic> userData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.email, size: 18, color: lightTextColor),
        SizedBox(width: 8),
        Text(
          userData['email'] ?? "No Email",
          style: TextStyle(fontSize: 16, color: lightTextColor),
        ),
      ],
    );
  }

  Widget _buildUserPhone(Map<String, dynamic> userData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.phone, size: 18, color: lightTextColor),
        SizedBox(width: 8),
        Text(
          userData['phone'] ?? "",
          style: TextStyle(fontSize: 16, color: lightTextColor),
        ),
      ],
    );
  }

  Widget _buildUserAddress(Map<String, dynamic> userData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_on, size: 18, color: lightTextColor),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            userData['address'] ?? "",
            style: TextStyle(fontSize: 16, color: lightTextColor),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOptions(BuildContext context) {
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
      child: Column(
        children: [
          _buildProfileOption(
            icon: Icons.edit,
            title: "Edit Profile",
            onTap: () {
              _showProfileSettings(context);
            },
          ),
          Divider(height: 1, indent: 16, endIndent: 16),
          _buildProfileOption(
            icon: Icons.lock,
            title: "Change Password",
            onTap: () {
              _showChangePasswordDialog(context);
            },
          ),
          Divider(height: 1, indent: 16, endIndent: 16),
          _buildProfileOption(
            icon: Icons.logout,
            title: "Logout",
            onTap: () => _showLogoutConfirmation(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : textColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? Colors.red : lightTextColor,
      ),
      onTap: onTap,
    );
  }
}