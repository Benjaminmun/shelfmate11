import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;  // Loading state flag

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signUpWithEmailPassword() async {
    setState(() {
      _isLoading = true;  // Show loading spinner
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showError('Please enter both email and password');
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.sendEmailVerification();

      _showSuccess('Sign-up successful! Please verify your email.');

      await _sendTokenToBackend();  // Send the token after successful sign-up

    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading spinner
      });
    }
  }

  // Handle Firebase Authentication specific errors
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    if (e.code == 'weak-password') {
      _showError('The password provided is too weak.');
    } else if (e.code == 'email-already-in-use') {
      _showError('The account already exists for that email.');
    } else {
      _showError(e.message!);
    }
  }

  // Function to show success dialog
  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Function to show error dialog
  void _showError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Function to send Firebase token to FastAPI backend
  Future<void> _sendTokenToBackend() async {
    try {
      String? idToken = await FirebaseAuth.instance.currentUser!.getIdToken();

      var response = await http.post(
        Uri.parse('http://localhost:8000/secure-endpoint'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        print("Token sent successfully");
      } else {
        _showError("Failed to send token to backend.");
      }
    } catch (e) {
      _showError("Error sending token to backend.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Image.asset('assets/logo.png', width: 120),
                SizedBox(height: 20),
                Text('Sign Up', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Password'),
                ),
                SizedBox(height: 40),
                _isLoading
                    ? CircularProgressIndicator()  // Show loading spinner if loading
                    : ElevatedButton(
                        onPressed: _signUpWithEmailPassword,
                        child: Text('Sign Up', style: TextStyle(fontSize: 18)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
