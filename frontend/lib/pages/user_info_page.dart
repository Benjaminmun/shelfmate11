import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

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
  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _profilePicUrl;
  
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Color Scheme
  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _secondaryColor = Color(0xFF4CAF50);
  final Color _backgroundColor = Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF1E293B);
  final Color _lightTextColor = Color(0xFF64748B);
  final Color _successColor = Color(0xFF10B981);
  final Color _errorColor = Color(0xFFEF4444);

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() { 
      _isLoading = true; 
    });
    
    try {
      final userId = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          fullNameController.text = data?['fullName'] ?? '';
          phoneController.text = data?['phone'] ?? '';
          addressController.text = data?['address'] ?? '';
          emailController.text = data?['email'] ?? _auth.currentUser!.email ?? '';
          _profilePicUrl = data?['profilePicUrl'];
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load user data', true);
    } finally {
      setState(() { 
        _isLoading = false; 
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source, 
        maxWidth: 800, 
        maxHeight: 800, 
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() { 
          _selectedImage = File(pickedFile.path); 
        });
        await _uploadImageToFirebase();
      }
    } catch (e) {
      _showSnackBar('Error selecting image', true);
    }
  }

  Future<void> _uploadImageToFirebase() async {
    if (_selectedImage == null) return;
    
    setState(() { 
      _isUploadingImage = true; 
    });

    try {
      final userId = _auth.currentUser!.uid;
      final Reference storageRef = FirebaseStorage.instance
          .ref().child('profile_pictures/$userId.jpg');

      await storageRef.putFile(_selectedImage!);
      final String downloadURL = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(userId).update({
        'profilePicUrl': downloadURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _profilePicUrl = downloadURL;
        _isUploadingImage = false;
      });
      
      _showSnackBar('Profile picture updated successfully!', false);
    } catch (e) {
      setState(() { 
        _isUploadingImage = false; 
      });
      _showSnackBar('Error uploading image', true);
    }
  }

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { 
      _isLoading = true; 
    });

    try {
      final userData = {
        'fullName': fullNameController.text,
        'phone': phoneController.text,
        'address': addressController.text,
        'email': emailController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users')
          .doc(_auth.currentUser!.uid)
          .set(userData, SetOptions(merge: true));

      setState(() { 
        _isEditing = false; 
      });
      
      _showSnackBar('Profile updated successfully!', false);
      
      // Add a slight delay before navigating back to show success message
      await Future.delayed(Duration(milliseconds: 1500));
      Navigator.pop(context);
      
    } catch (e) {
      _showSnackBar('Error saving information', true);
    } finally {
      setState(() { 
        _isLoading = false; 
      });
    }
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _lightTextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Choose Profile Picture',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 24),
              _buildImageSourceOption(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              _buildImageSourceOption(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: _lightTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: _primaryColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: _textColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: _lightTextColor,
      ),
      onTap: onTap,
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: _isEditing && !_isUploadingImage ? _showImageSourceDialog : null,
      child: Stack(
        children: [
          // Background glow effect
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          
          // Main avatar container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _primaryColor.withOpacity(0.2),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  // Profile image or default avatar
                  _profilePicUrl != null
                      ? Image.network(
                          _profilePicUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_primaryColor),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                      : _buildDefaultAvatar(),
                  
                  // Uploading overlay
                  if (_isUploadingImage)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Uploading...',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Edit icon overlay
          if (_isEditing && !_isUploadingImage)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.8),
            _secondaryColor.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 40,
          color: Colors.white,
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
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: enabled ? _textColor : _lightTextColor,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: _lightTextColor,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            width: 20,
            height: 20,
            margin: EdgeInsets.all(16),
            child: Icon(
              icon,
              color: _primaryColor,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: _secondaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          suffixIcon: enabled ? null : Icon(
            Icons.lock_outline_rounded,
            color: _lightTextColor.withOpacity(0.5),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                  _loadUserData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardColor,
                  foregroundColor: _lightTextColor,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveUserInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Elements
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withOpacity(0.1),
                      _backgroundColor.withOpacity(0.1),
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
            
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                height: MediaQuery.of(context).size.height * 0.2,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _secondaryColor.withOpacity(0.05),
                      _backgroundColor.withOpacity(0.05),
                    ],
                    radius: 0.6,
                  ),
                ),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        SizedBox(height: 20 + _slideAnimation.value),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _cardColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 18,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile Settings',
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: _textColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _isEditing 
                                            ? 'Update your personal information'
                                            : 'Manage your profile details',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: _lightTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isEditing)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        size: 20,
                                        color: _primaryColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Profile Avatar
                        SizedBox(height: 40 + _slideAnimation.value),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Center(
                              child: Column(
                                children: [
                                  _buildProfileAvatar(),
                                  SizedBox(height: 12),
                                  if (_isEditing)
                                    Text(
                                      'Tap to change profile picture',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: _lightTextColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Form Content
                        SizedBox(height: 40 + _slideAnimation.value),
                        
                        if (_isLoading && !_isDataLoaded)
                          Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(_primaryColor),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading your profile...',
                                  style: GoogleFonts.poppins(
                                    color: _lightTextColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      controller: fullNameController,
                                      label: 'Full Name',
                                      icon: Icons.person_outline_rounded,
                                      enabled: _isEditing,
                                    ),
                                    _buildTextField(
                                      controller: emailController,
                                      label: 'Email Address',
                                      icon: Icons.email_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: false,
                                    ),
                                    _buildTextField(
                                      controller: phoneController,
                                      label: 'Phone Number',
                                      icon: Icons.phone_rounded,
                                      keyboardType: TextInputType.phone,
                                      enabled: _isEditing,
                                    ),
                                    _buildTextField(
                                      controller: addressController,
                                      label: 'Address',
                                      icon: Icons.home_rounded,
                                      maxLines: 2,
                                      enabled: _isEditing,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Action Buttons
                        SizedBox(height: 40 + _slideAnimation.value),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: _buildActionButton(),
                          ),
                        ),
                        SizedBox(height: 40),
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}