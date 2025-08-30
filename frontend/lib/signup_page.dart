import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signUpWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.sendEmailVerification();
      _showDialog('Success', 'Sign-up successful! Please verify your email.');
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
    if (e.code == 'weak-password') {
      _showDialog('Error', 'The password provided is too weak.');
    } else if (e.code == 'email-already-in-use') {
      _showDialog('Error', 'The account already exists for that email.');
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
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: title == 'Success' ? Color(0xFF4CAF50) : Color(0xFF2D5D7C),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(title == 'Success' ? 'Continue to Login' : 'Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      String? idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
      var response = await http.post(
        Uri.parse('http://localhost:8000/secure-endpoint'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        print("Token sent successfully");
      } else {
        _showDialog("Error", "Failed to send token to backend.");
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
                    'Create Account',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Join us to streamline your inventory management',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: fullNameController, label: 'Full Name', icon: Icons.person_outline),
                      SizedBox(height: 20),
                      _buildTextField(controller: emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      SizedBox(height: 20),
                      _buildPasswordField(controller: passwordController, label: 'Password', obscureText: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                      SizedBox(height: 20),
                      _buildPasswordField(controller: confirmPasswordController, label: 'Confirm Password', obscureText: _obscureConfirmPassword, onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                _isLoading
                    ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)))
                    : _buildElevatedButton(context, 'Create Account', _signUpWithEmailPassword, Color(0xFF4CAF50)),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black.withOpacity(0.2))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: Text('Or sign up with', style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500))),
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
                    Text("Already have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage())),
                      child: Text('Log In', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
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
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF2D5D7C)), suffixIcon: IconButton(icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Color(0xFF2D5D7C)), onPressed: onToggle), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), filled: true, fillColor: Colors.transparent),
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
