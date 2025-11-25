import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Password strength indicators
  double _passwordStrength = 0.0;
  String _passwordFeedback = '';
  Color _strengthColor = Colors.grey;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Colors
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);
  final Color successColor = Color(0xFF10B981);
  final Color errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    double strength = 0.0;
    String feedback = '';

    if (password.isEmpty) {
      strength = 0.0;
      feedback = '';
    } else if (password.length < 6) {
      strength = 0.3;
      feedback = 'Too short';
    } else {
      // Check for character variety
      bool hasUpper = password.contains(RegExp(r'[A-Z]'));
      bool hasLower = password.contains(RegExp(r'[a-z]'));
      bool hasDigits = password.contains(RegExp(r'[0-9]'));
      bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      int criteriaMet = 0;
      if (hasUpper) criteriaMet++;
      if (hasLower) criteriaMet++;
      if (hasDigits) criteriaMet++;
      if (hasSpecial) criteriaMet++;

      if (password.length >= 8) criteriaMet++;

      strength = (criteriaMet / 5).clamp(0.0, 1.0);

      if (strength < 0.4) {
        feedback = 'Weak';
      } else if (strength < 0.7) {
        feedback = 'Fair';
      } else if (strength < 0.9) {
        feedback = 'Good';
      } else {
        feedback = 'Strong';
      }
    }

    setState(() {
      _passwordStrength = strength;
      _passwordFeedback = feedback;
      _strengthColor = _getStrengthColor(strength);
    });
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.4) return Colors.red;
    if (strength < 0.7) return Colors.orange;
    return Colors.green;
  }

  List<String> _getPasswordRequirements() {
    return [
      'At least 8 characters',
      'One uppercase letter',
      'One lowercase letter',
      'One number',
      'One special character',
    ];
  }

  bool _validateForm() {
    if (_currentPasswordController.text.isEmpty) {
      _showError('Please enter your current password');
      return false;
    }
    if (_newPasswordController.text.isEmpty) {
      _showError('Please enter a new password');
      return false;
    }
    if (_newPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('New passwords do not match');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No user logged in');
        return;
      }

      if (user.email == null) {
        _showError('User email not available');
        return;
      }

      // Reauthenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text.trim());

      // Success
      _showSuccess('Password updated successfully!');

      // Navigate back after successful update
      Future.delayed(Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to update password';

      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again to change password';
          break;
        case 'user-not-found':
          errorMessage = 'User not found';
          break;
        case 'user-mismatch':
          errorMessage = 'Credential does not match current user';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credential';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Password update is not allowed';
          break;
        default:
          errorMessage = 'An error occurred: ${e.message}';
      }

      _showError(errorMessage);
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              child: _buildContent(),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Change Password',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            margin: EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.1),
                  primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 36,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Update Your Password',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Create a strong and secure password to protect your account',
                  style: GoogleFonts.poppins(
                    color: lightTextColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Current Password Field
          _buildPasswordField(
            controller: _currentPasswordController,
            label: 'Current Password',
            hintText: 'Enter your current password',
            obscureText: _obscureCurrentPassword,
            onToggleVisibility: () => setState(() {
              _obscureCurrentPassword = !_obscureCurrentPassword;
            }),
            icon: Icons.lock_rounded,
          ),
          SizedBox(height: 20),

          // New Password Field
          _buildPasswordField(
            controller: _newPasswordController,
            label: 'New Password',
            hintText: 'Create a new password',
            obscureText: _obscureNewPassword,
            onToggleVisibility: () => setState(() {
              _obscureNewPassword = !_obscureNewPassword;
            }),
            icon: Icons.lock_outline_rounded,
          ),

          // Password Strength Indicator
          if (_newPasswordController.text.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildPasswordStrengthIndicator(),
            SizedBox(height: 8),
          ],

          SizedBox(height: 20),

          // Confirm Password Field
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            hintText: 'Re-enter your new password',
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () => setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            }),
            icon: Icons.lock_reset_rounded,
          ),

          // Password Requirements
          SizedBox(height: 24),
          _buildPasswordRequirements(),

          // Update Button
          SizedBox(height: 32),
          _buildUpdateButton(),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.poppins(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: Icon(icon, color: Colors.grey[600]),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.grey[600],
              ),
              onPressed: onToggleVisibility,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.grey[200],
                color: _strengthColor,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ),
            SizedBox(width: 12),
            Text(
              _passwordFeedback,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _strengthColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Password strength',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final requirements = _getPasswordRequirements();
    final newPassword = _newPasswordController.text;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12),
          Column(
            children: requirements.map((requirement) {
              bool isMet = _checkRequirement(requirement, newPassword);
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isMet
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: isMet ? successColor : Colors.grey[400],
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        requirement,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isMet ? successColor : Colors.grey[600],
                          fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updatePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Update Password',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  bool _checkRequirement(String requirement, String password) {
    if (password.isEmpty) return false;

    switch (requirement) {
      case 'At least 8 characters':
        return password.length >= 8;
      case 'One uppercase letter':
        return password.contains(RegExp(r'[A-Z]'));
      case 'One lowercase letter':
        return password.contains(RegExp(r'[a-z]'));
      case 'One number':
        return password.contains(RegExp(r'[0-9]'));
      case 'One special character':
        return password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
