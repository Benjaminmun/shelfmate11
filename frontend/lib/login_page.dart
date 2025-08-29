import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _loginWithEmailPassword() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showError('Please enter both email and password');
        return;
      }

      // Sign in the user
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        _showError('Please verify your email before logging in.');
        return;
      }

      _showSuccess('Logged in successfully!');
      await _sendTokenToBackend(); // Send token to the backend

    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    if (e.code == 'user-not-found') {
      _showError('No user found for that email.');
    } else if (e.code == 'wrong-password') {
      _showError('Incorrect password.');
    } else {
      _showError(e.message!);
    }
  }

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
                Navigator.pushReplacementNamed(context, '/dashboard');
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

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

  Future<void> _sendTokenToBackend() async {
    try {
      // Get the current logged-in user
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('User is not logged in!');
        return;
      }

      // Get the ID token
      String? idToken = await user.getIdToken();
      print("Generated Firebase ID Token: $idToken");

      if (idToken == null) {
        _showError('Failed to retrieve ID token.');
        return;
      }

      // Send the token to the backend
      var response = await http.post(
        Uri.parse('http://192.168.68.51:8000/secure-endpoint'), // Use your local IP
        headers: {
          'Authorization': 'Bearer $idToken', // Send token as Authorization header
        },
      );

      // Debugging response
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("Authenticated successfully");
      } else {
        _showError("Authentication failed: ${response.body}");
      }
    } catch (e) {
      _showError("Error sending token to backend: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Image.asset('assets/logo.png', width: 120),
                SizedBox(height: 20),
                Text('Login', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
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
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _loginWithEmailPassword,
                        child: Text('Login', style: TextStyle(fontSize: 18)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
