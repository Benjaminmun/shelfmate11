import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _loginWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
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

      _showDialog('Success', 'Logged in successfully!');
      await _sendTokenToBackend();

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
    if (e.code == 'user-not-found') {
      _showDialog('Error', 'No user found for that email.');
    } else if (e.code == 'wrong-password') {
      _showDialog('Error', 'Incorrect password.');
    } else {
      _showDialog('Error', e.message!);
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
                Icon(title == 'Success' ? Icons.check_circle : Icons.error_outline, 
                      color: title == 'Success' ? Color(0xFF4CAF50) : Colors.red, 
                      size: 60),
                SizedBox(height: 16),
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D5D7C))),
                SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (title == 'Success') {
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: title == 'Success' ? Color(0xFF4CAF50) : Color(0xFF2D5D7C),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(title == 'Success' ? 'Continue to Dashboard' : 'Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendTokenToBackend() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showDialog('Error', 'User is not logged in!');
        return;
      }

      String? idToken = await user.getIdToken();
      print("Generated Firebase ID Token: $idToken");

      if (idToken == null) {
        _showDialog('Error', 'Failed to retrieve ID token.');
        return;
      }

      var response = await http.post(
        Uri.parse('http://localhost:8000/secure-endpoint'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("Authenticated successfully");
      } else {
        _showDialog("Error", "Authentication failed: ${response.body}");
      }
    } catch (e) {
      _showDialog("Error", "Error sending token to backend: $e");
    }
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(height: 20),
                Container(
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
                  child: Image.asset('assets/logo.png', width: 140, height: 140),
                ),
                SizedBox(height: 20),
                ShaderMask(
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
                SizedBox(height: 8),
                Text(
                  'Sign in to continue to your inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      SizedBox(height: 20),
                      _buildPasswordField(controller: passwordController, label: 'Password', obscureText: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Add forgot password functionality
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Color(0xFF2D5D7C), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                _isLoading
                    ? Container(
                        width: 56,
                        height: 56,
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                          strokeWidth: 3,
                        ),
                      )
                    : _buildElevatedButton(context, 'Log In', _loginWithEmailPassword, Color(0xFF4CAF50)),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black.withOpacity(0.2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Text(
                        'Or continue with',
                        style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.black.withOpacity(0.2))),
                  ],
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildSocialMediaButton(Icons.g_mobiledata, Color(0xFFDB4437), 'Google'),
                    SizedBox(width: 25),
                    _buildSocialMediaButton(Icons.facebook, Color(0xFF4267B2), 'Facebook'),
                    SizedBox(width: 25),
                    _buildSocialMediaButton(Icons.email, Colors.black, 'Email'),
                  ],
                ),
                SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SignUpPage())),
                      child: Text('Sign Up', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Color(0xFF2D5D7C)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), filled: true, fillColor: Colors.transparent),
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String label, required bool obscureText, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF2D5D7C)),
          suffixIcon: IconButton(icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Color(0xFF2D5D7C)), onPressed: onToggle),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildElevatedButton(BuildContext context, String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadowColor: color.withOpacity(0.4)),
        child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildSocialMediaButton(IconData icon, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 4,
        shape: CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: Offset(0, 4))]),
          child: IconButton(icon: Icon(icon, color: color, size: 28), onPressed: () {}),
        ),
      ),
    );
  }
}
