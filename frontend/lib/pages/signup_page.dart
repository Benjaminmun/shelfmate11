import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:password_strength_checker/password_strength_checker.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Updated color scheme to match DashboardPage
  static const Color primaryColor = Color(0xFF2D5D7C);
  static const Color secondaryColor = Color(0xFF6270B1);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Enhanced password strength notifier
  final ValueNotifier<PasswordStrength?> _passwordStrengthNotifier =
      ValueNotifier<PasswordStrength?>(null);
  final List<String> _commonPasswords = [
    'password',
    '123456',
    '12345678',
    '1234',
    'qwerty',
    'abc123',
    'password1',
    'admin',
    'welcome',
    'monkey',
    'letmein',
    'shadow',
  ];

  // Custom password validation rules
  final Map<String, bool> _passwordValidation = {
    'min_length': false,
    'uppercase': false,
    'lowercase': false,
    'numbers': false,
    'special_chars': false,
    'not_common': false,
  };

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();

    // Listen to password changes for strength checking
    passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final password = passwordController.text;

    if (password.isEmpty) {
      _passwordStrengthNotifier.value = null;
      _resetPasswordValidation();
      return;
    }

    // Update validation rules
    _passwordValidation['min_length'] = password.length >= 8;
    _passwordValidation['uppercase'] = RegExp(r'[A-Z]').hasMatch(password);
    _passwordValidation['lowercase'] = RegExp(r'[a-z]').hasMatch(password);
    _passwordValidation['numbers'] = RegExp(r'[0-9]').hasMatch(password);
    _passwordValidation['special_chars'] = RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password);
    _passwordValidation['not_common'] = !_commonPasswords.contains(
      password.toLowerCase(),
    );

    // Calculate custom strength score
    final strength = _calculateCustomPasswordStrength(password);
    _passwordStrengthNotifier.value = strength;
  }

  PasswordStrength _calculateCustomPasswordStrength(String password) {
    int score = 0;
    int maxScore = 6; // Number of validation criteria

    // Base score from validation rules
    _passwordValidation.forEach((key, value) {
      if (value) score++;
    });

    // Bonus points for length
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;

    // Penalty for sequential characters
    if (_hasSequentialCharacters(password)) score = score > 0 ? score - 1 : 0;

    // Calculate percentage
    double percentage = score / (maxScore + 2); // +2 for bonus points

    // Convert to PasswordStrength enum
    if (percentage >= 0.8) return PasswordStrength.secure;
    if (percentage >= 0.6) return PasswordStrength.strong;
    if (percentage >= 0.4) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  bool _hasSequentialCharacters(String password) {
    // Check for sequential numbers (123, 456, etc.)
    for (int i = 0; i < password.length - 2; i++) {
      int char1 = password.codeUnitAt(i);
      int char2 = password.codeUnitAt(i + 1);
      int char3 = password.codeUnitAt(i + 2);

      if (char2 == char1 + 1 && char3 == char2 + 1) {
        return true;
      }
    }

    // Check for sequential letters (abc, def, etc.)
    final lowerPassword = password.toLowerCase();
    for (int i = 0; i < lowerPassword.length - 2; i++) {
      int char1 = lowerPassword.codeUnitAt(i);
      int char2 = lowerPassword.codeUnitAt(i + 1);
      int char3 = lowerPassword.codeUnitAt(i + 2);

      if (char1 >= 97 &&
          char1 <= 122 &&
          char2 == char1 + 1 &&
          char3 == char2 + 1) {
        return true;
      }
    }

    return false;
  }

  void _resetPasswordValidation() {
    _passwordValidation.updateAll((key, value) => false);
  }

  String _getPasswordStrengthText(PasswordStrength? strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak password';
      case PasswordStrength.medium:
        return 'Medium strength';
      case PasswordStrength.strong:
        return 'Strong password';
      case PasswordStrength.secure:
        return 'Very strong password';
      default:
        return 'Enter a password';
    }
  }

  Color _getPasswordStrengthColor(PasswordStrength? strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return errorColor;
      case PasswordStrength.medium:
        return warningColor;
      case PasswordStrength.strong:
        return successColor;
      case PasswordStrength.secure:
        return successColor;
      default:
        return textLight;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordStrengthNotifier.dispose();
    passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  Future<void> _signUpWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Enhanced password strength validation
    final strength = _passwordStrengthNotifier.value;
    if (strength == PasswordStrength.weak || strength == null) {
      _showDialog(
        'Weak Password',
        'Please choose a stronger password. Your password should include:\n\n• At least 8 characters\n• Uppercase and lowercase letters\n• Numbers\n• Special characters\n• Not a common password',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final fullName = fullNameController.text.trim();

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Store user data in Firestore
      final String userId = userCredential.user!.uid;
      await _firestore.collection('users').doc(userId).set({
        'fullName': fullName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': userId,
      });

      // After successful signup, send email verification
      await userCredential.user!.sendEmailVerification();
      _showDialog(
        'Success',
        'Sign-up successful! Please check your email to verify your account before logging in.',
      );
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showDialog('Error', 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage = 'An error occurred during sign-up.';

    switch (e.code) {
      case 'weak-password':
        errorMessage =
            'The password provided is too weak. Please choose a stronger password.';
        break;
      case 'email-already-in-use':
        errorMessage = 'An account already exists with this email address.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is not valid.';
        break;
      case 'operation-not-allowed':
        errorMessage =
            'Email/password accounts are not enabled. Please contact support.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your internet connection.';
        break;
      default:
        errorMessage = e.message ?? errorMessage;
    }

    _showDialog('Error', errorMessage);
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  title == 'Success' ? Icons.check_circle : Icons.error_outline,
                  color: title == 'Success' ? successColor : errorColor,
                  size: 60,
                ),
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: textSecondary),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (title == 'Success') {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    LoginPage(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  var curve = Curves.easeInOut;
                                  var curveTween = CurveTween(curve: curve);
                                  var begin = Offset(1.0, 0.0);
                                  var end = Offset.zero;
                                  var tween = Tween(
                                    begin: begin,
                                    end: end,
                                  ).chain(curveTween);
                                  var offsetAnimation = animation.drive(tween);

                                  return SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  );
                                },
                            transitionDuration: Duration(milliseconds: 600),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: title == 'Success'
                          ? successColor
                          : primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      title == 'Success' ? 'Continue to Login' : 'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      'Join us to streamline your inventory management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildTextField(
                            controller: fullNameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (value.trim().split(' ').length < 2) {
                                return 'Please enter your full name (first and last name)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildTextField(
                            controller: emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            children: [
                              _buildPasswordField(
                                controller: passwordController,
                                label: 'Password',
                                obscureText: _obscurePassword,
                                onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }

                                  // Enhanced strength validation
                                  final strength =
                                      _passwordStrengthNotifier.value;
                                  if (strength == PasswordStrength.weak) {
                                    return 'Please choose a stronger password';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 12),
                              // Enhanced password strength indicator
                              _buildPasswordStrengthIndicator(),
                              SizedBox(height: 8),
                              // Password requirements checklist
                              _buildPasswordRequirements(),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildPasswordField(
                            controller: confirmPasswordController,
                            label: 'Confirm Password',
                            obscureText: _obscureConfirmPassword,
                            onToggle: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                _isLoading
                    ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 56,
                          height: 56,
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildElevatedButton(
                            context,
                            'Create Account',
                            _signUpWithEmailPassword,
                            primaryColor,
                          ),
                        ),
                      ),
                SizedBox(height: 40),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(color: textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      LoginPage(),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    var curve = Curves.easeInOut;
                                    var curveTween = CurveTween(curve: curve);
                                    var begin = Offset(-1.0, 0.0);
                                    var end = Offset.zero;
                                    var tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(curveTween);
                                    var offsetAnimation = animation.drive(
                                      tween,
                                    );

                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    );
                                  },
                              transitionDuration: Duration(milliseconds: 600),
                            ),
                          ),
                          child: Text(
                            'Log In',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return ValueListenableBuilder<PasswordStrength?>(
      valueListenable: _passwordStrengthNotifier,
      builder: (context, strength, child) {
        if (strength == null || passwordController.text.isEmpty) {
          return SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: strength == PasswordStrength.weak
                        ? 0.25
                        : strength == PasswordStrength.medium
                        ? 0.5
                        : strength == PasswordStrength.strong
                        ? 0.75
                        : 1.0,
                    backgroundColor: textLight.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getPasswordStrengthColor(strength),
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  _getPasswordStrengthText(strength),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getPasswordStrengthColor(strength),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPasswordRequirements() {
    return ValueListenableBuilder<PasswordStrength?>(
      valueListenable: _passwordStrengthNotifier,
      builder: (context, strength, child) {
        if (passwordController.text.isEmpty) {
          return SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password requirements:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            SizedBox(height: 4),
            _buildRequirementItem(
              'At least 8 characters',
              _passwordValidation['min_length']!,
            ),
            _buildRequirementItem(
              'Uppercase letter (A-Z)',
              _passwordValidation['uppercase']!,
            ),
            _buildRequirementItem(
              'Lowercase letter (a-z)',
              _passwordValidation['lowercase']!,
            ),
            _buildRequirementItem(
              'Number (0-9)',
              _passwordValidation['numbers']!,
            ),
            _buildRequirementItem(
              'Special character (!@#\$%)',
              _passwordValidation['special_chars']!,
            ),
            _buildRequirementItem(
              'Not a common password',
              _passwordValidation['not_common']!,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? successColor : textLight,
          ),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? successColor : textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 16, color: textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textSecondary),
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: TextStyle(fontSize: 16, color: textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textSecondary),
          prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: primaryColor,
            ),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildElevatedButton(
    BuildContext context,
    String text,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: color.withOpacity(0.4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
