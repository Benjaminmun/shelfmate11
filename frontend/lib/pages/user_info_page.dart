import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_service.dart'; // Import household service

// Function to update user profile in Firestore from household service
Future<void> updateUserProfileInHouseholdService({
  required String userId,
  required String fullName,
  required String phone,
  required String address,
  required String email,
}) async {
  try {
    final userData = {
      'fullName': fullName,
      'phone': phone,
      'address': address,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(userData, SetOptions(merge: true));
  } catch (e) {
    print('Error updating user profile: $e');
    throw e;
  }
}

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> with SingleTickerProviderStateMixin {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isDataLoaded = false;
  final _formKey = GlobalKey<FormState>();

  // Initialize animation controllers as nullable
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Set up animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animations after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController?.forward();
    });

    // Load user data from database
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the current user's UID
      final userId = _auth.currentUser!.uid;

      // Fetch user data from Firestore
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        // Get the data from the document
        final data = doc.data();

        setState(() {
          fullNameController.text = data?['fullName'] ?? '';
          phoneController.text = data?['phone'] ?? '';
          addressController.text = data?['address'] ?? '';
          emailController.text = data?['email'] ?? '';
          _isDataLoaded = true;
        });
      } else {
        // Handle the case where no user data is found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No user data found!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load user data: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Collect the updated user data
      final userData = {
        'fullName': fullNameController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'email': emailController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save data to Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set(userData, SetOptions(merge: true));

      // Call the method to store the data in household service
      await updateUserProfileInHouseholdService(
        userId: _auth.currentUser!.uid,
        fullName: fullNameController.text,
        phone: phoneController.text,
        address: addressController.text,
        email: emailController.text,
      );

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      // Navigate to HouseholdService after saving
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HouseholdService(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving information: $e', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if animations are initialized
    if (_animationController == null || _fadeAnimation == null || _slideAnimation == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4CAF50)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2D5D7C).withOpacity(0.1),
                      const Color(0xFF4CAF50).withOpacity(0.05),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(100),
                  ),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _animationController!,
                  builder: (context, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20 + _slideAnimation!.value),
                        FadeTransition(
                          opacity: _fadeAnimation!,
                          child: Transform.translate(
                            offset: Offset(0, _slideAnimation!.value),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'User Profile',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D5D7C),
                                    ),
                                  ),
                                ),
                                if (!_isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Color(0xFF2D5D7C)),
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = true;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8 + _slideAnimation!.value / 2),
                        FadeTransition(
                          opacity: _fadeAnimation!,
                          child: Transform.translate(
                            offset: Offset(0, _slideAnimation!.value),
                            child: Text(
                              _isEditing ? 'Edit your profile information' : 'View and manage your profile',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40 + _slideAnimation!.value),
                        // Profile avatar
                        Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation!,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation!.value),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2D5D7C),
                                          Color(0xFF4CAF50),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(60),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(60),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(50),
                                              image: const DecorationImage(
                                                image: NetworkImage(
                                                    'https://miro.medium.com/v2/resize:fit:640/format:webp/1*LSroVU0uk_5WBgkovw45Bg.avif'),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: Colors.white, width: 3),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40 + _slideAnimation!.value),

                        if (_isLoading && !_isDataLoaded)
                          Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        else
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                FadeTransition(
                                  opacity: _fadeAnimation!,
                                  child: Transform.translate(
                                    offset: Offset(0, _slideAnimation!.value),
                                    child: _buildTextField(
                                      controller: fullNameController,
                                      label: 'Full Name',
                                      icon: Icons.person_outline,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20 + _slideAnimation!.value / 2),
                                FadeTransition(
                                  opacity: _fadeAnimation!,
                                  child: Transform.translate(
                                    offset: Offset(0, _slideAnimation!.value),
                                    child: _buildTextField(
                                      controller: emailController,
                                      label: 'Email Address',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: false, // Email is typically not editable
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20 + _slideAnimation!.value / 2),
                                FadeTransition(
                                  opacity: _fadeAnimation!,
                                  child: Transform.translate(
                                    offset: Offset(0, _slideAnimation!.value),
                                    child: _buildTextField(
                                      controller: phoneController,
                                      label: 'Phone Number',
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20 + _slideAnimation!.value / 2),
                                FadeTransition(
                                  opacity: _fadeAnimation!,
                                  child: Transform.translate(
                                    offset: Offset(0, _slideAnimation!.value),
                                    child: _buildTextField(
                                      controller: addressController,
                                      label: 'Address',
                                      icon: Icons.home,
                                      maxLines: 2,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 40 + _slideAnimation!.value),

                        if (_isEditing)
                          FadeTransition(
                            opacity: _fadeAnimation!,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation!.value),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 58,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditing = false;
                                          });
                                          _loadUserData(); // Reload original data
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[300],
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SizedBox(
                                      height: 58,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _saveUserInfo,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4CAF50),
                                          elevation: 6,
                                          shadowColor: const Color(0xFF4CAF50).withOpacity(0.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                strokeWidth: 2,
                                              )
                                            : const Text(
                                                'Save',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          FadeTransition(
                            opacity: _fadeAnimation!,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation!.value),
                              child: SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D5D7C),
                                    elevation: 6,
                                    shadowColor: const Color(0xFF2D5D7C).withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 30 + _slideAnimation!.value),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: enabled ? Colors.black : Colors.grey[600],
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF2D5D7C)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}