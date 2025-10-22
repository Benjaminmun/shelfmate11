import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_service.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'user_info_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _passwordError = false; // Track password errors for visual feedback
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmailPassword() async {
    // Prevent double-tap and ensure form is valid
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _passwordError = false; // Reset password error state
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        _showDialog('Error', 'Please verify your email before logging in.');
        return;
      }

      // Check if user info exists in Firestore
      final userInfoExists = await _checkUserInfoExists(userCredential.user!.uid);
      
      if (!mounted) return;
      
      if (userInfoExists) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HouseholdService(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: Duration(milliseconds: 500),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => UserInfoPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              var curve = Curves.easeInOut;
              var curveTween = CurveTween(curve: curve);
              var begin = Offset(1.0, 0.0);
              var end = Offset.zero;
              var tween = Tween(begin: begin, end: end).chain(curveTween);
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

    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      if (!mounted) return;
      _showDialog('Error', 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    
    if (email.isEmpty) {
      _showDialog('Error', 'Please enter your email address first');
      return;
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showDialog('Success', 'Password reset email sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showDialog('Error', 'No user found with that email address.');
      } else {
        _showDialog('Error', 'Error sending reset email: ${e.message}');
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred. Please try again.');
    }
  }

  Future<bool> _checkUserInfoExists(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null && 
               data['phone'] != null && 
               data['phone'].toString().isNotEmpty &&
               data['address'] != null &&
               data['address'].toString().isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    if (e.code == 'user-not-found') {
      _showDialog('Error', 'No user found for that email.');
    } else if (e.code == 'wrong-password') {
      setState(() => _passwordError = true); // Set visual error state
      _showDialog('Error', 'Incorrect password. Please try again.');
    } else if (e.code == 'invalid-email') {
      _showDialog('Error', 'Invalid email address format.');
    } else if (e.code == 'too-many-requests') {
      _showDialog('Error', 'Too many login attempts. Please try again later.');
    } else if (e.code == 'user-disabled') {
      _showDialog('Error', 'This account has been disabled.');
    } else {
      _showDialog('Error', e.message ?? 'An authentication error occurred.');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  title == 'Success' ? Icons.check_circle : Icons.error_outline, 
                  color: title == 'Success' ? Color(0xFF4CAF50) : Colors.red, 
                  size: 60
                ),
                SizedBox(height: 16),
                Text(
                  title, 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D5D7C))
                ),
                SizedBox(height: 16),
                Text(
                  message, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontSize: 16)
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Clear password error when user acknowledges the error
                      if (title != 'Success') {
                        setState(() => _passwordError = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: title == 'Success' ? Color(0xFF4CAF50) : Color(0xFF2D5D7C),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      title == 'Success' ? 'Continue' : 'Try Again', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
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
      backgroundColor: Color(0xFFE2E6E0),
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
                    icon: Icon(Icons.arrow_back, color: Color(0xFF2D5D7C)),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          var begin = Offset(-1.0, 0.0);
                          var end = Offset.zero;
                          var tween = Tween(begin: begin, end: end);
                          var offsetAnimation = animation.drive(tween);
                          
                          return SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          );
                        },
                      ),
                    ),
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
                            color: Color(0xFF2D5D7C).withOpacity(0.15),
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
                            colors: [Color(0xFF2D5D7C), Color(0xFF4CAF50)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white),
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
                        colors: [Color(0xFF2D5D7C), Color(0xFF4CAF50)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        'Welcome Back',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
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
                      'Sign in to continue to your inventory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.6)),
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
                            controller: emailController, 
                            label: 'Email Address', 
                            icon: Icons.email_outlined, 
                            keyboardType: TextInputType.emailAddress
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildPasswordField(
                            controller: passwordController, 
                            label: 'Password', 
                            obscureText: _obscurePassword, 
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                            hasError: _passwordError, // Pass error state to field
                          ),
                        ),
                      ),
                      if (_passwordError) ...[
                        SizedBox(height: 8),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Incorrect password. Please try again.',
                                  style: TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Color(0xFF2D5D7C), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _isLoading
                      ? Container(
                          key: ValueKey('loading'),
                          width: 56,
                          height: 56,
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                            strokeWidth: 3,
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _buildElevatedButton(
                              context, 
                              'Log In', 
                              _loginWithEmailPassword, 
                              Color(0xFF4CAF50)
                            ),
                          ),
                        ),
                ),
                SizedBox(height: 30),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => SignUpPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                var curve = Curves.easeInOut;
                                var curveTween = CurveTween(curve: curve);
                                var begin = Offset(1.0, 0.0);
                                var end = Offset.zero;
                                var tween = Tween(begin: begin, end: end).chain(curveTween);
                                var offsetAnimation = animation.drive(tween);

                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                              transitionDuration: Duration(milliseconds: 600),
                            ),
                          ),
                          child: Text(
                            'Sign Up', 
                            style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)
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

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    TextInputType keyboardType = TextInputType.text
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: Offset(0, 4)
          )
        ]
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16),
        autofillHints: [AutofillHints.email],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon, color: Color(0xFF2D5D7C)), 
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          filled: true, 
          fillColor: Colors.transparent
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller, 
    required String label, 
    required bool obscureText, 
    required VoidCallback onToggle,
    bool hasError = false, // New parameter for error state
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: Offset(0, 4)
          )
        ],
        border: hasError ? Border.all(color: Colors.red, width: 1.5) : null, // Visual error indicator
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(fontSize: 16, color: hasError ? Colors.red : null),
        autofillHints: [AutofillHints.password],
        onChanged: (value) {
          // Clear error state when user starts typing
          if (hasError) {
            setState(() => _passwordError = false);
          }
        },
        onFieldSubmitted: (_) => _loginWithEmailPassword(), // Submit on enter key
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          // Removed the 6-character validation - users already have established passwords
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hasError ? Colors.red : null),
          prefixIcon: Icon(Icons.lock_outline, color: hasError ? Colors.red : Color(0xFF2D5D7C)), 
          suffixIcon: Tooltip(
            message: obscureText ? 'Show password' : 'Hide password',
            child: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, 
                color: hasError ? Colors.red : Color(0xFF2D5D7C)
              ), 
              onPressed: onToggle,
            ),
          ), 
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), 
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: hasError ? Colors.red : Color(0xFF4CAF50), 
              width: 2
            ),
          ),
          filled: true, 
          fillColor: Colors.transparent
        ),
      ),
    );
  }

  Widget _buildElevatedButton(BuildContext context, String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed, // Disable when loading
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          elevation: 0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
          shadowColor: color.withOpacity(0.4)
        ),
        child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}