import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/household_service.dart';
import 'pages/signup_page.dart';
import 'pages/user_info_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and handle errors with a proper message.
  try {
    await Firebase.initializeApp();
    print("Firebase Initialized");
  } catch (e) {
    print("Error initializing Firebase: $e");
    runApp(MyApp(isFirebaseInitialized: false));
    return;
  }

  runApp(MyApp(isFirebaseInitialized: true));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;

  MyApp({required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf Mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF2D5D7C),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF2D5D7C),
          secondary: Color(0xFF4CAF50),
        ),
        scaffoldBackgroundColor: Color(0xFFF8FAFC),
      ),
      home: isFirebaseInitialized ? const AuthWrapper() : ErrorPage(),
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/household': (context) => HouseholdService(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Check if email is verified
          if (user.emailVerified) {
            return _checkUserInfoCompletion(user);
          } else {
            return _buildEmailVerificationScreen(user, context);
          }
        }

        // If no user is logged in, show home page
        return HomePage();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5D7C)),
        ),
      ),
    );
  }

  FutureBuilder<bool> _checkUserInfoCompletion(User user) {
    return FutureBuilder<bool>(
      future: _isUserInfoCompleted(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasData && snapshot.data == true) {
          return HouseholdService();
        } else {
          return UserInfoPage();
        }
      },
    );
  }

  Widget _buildEmailVerificationScreen(User user, BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email, size: 64, color: Color(0xFF2D5D7C)),
            SizedBox(height: 20),
            Text(
              'Please verify your email',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D5D7C)),
            ),
            SizedBox(height: 10),
            Text(
              'We sent a verification link to ${user.email}',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await user.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification email sent'),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2D5D7C),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Resend Verification Email', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: Text('Sign Out', style: TextStyle(color: Color(0xFF2D5D7C))),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _isUserInfoCompleted(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      // Check if the document exists and has the required fields
      if (doc.exists) {
        final data = doc.data();
        // Check if the user has completed their profile (has phone and address)
        return data != null && 
               data['phone'] != null && 
               data['phone'].toString().isNotEmpty &&
               data['address'] != null &&
               data['address'].toString().isNotEmpty;
      }
      return false;
    } catch (e) {
      print("Error checking user info completion: $e");
      return false;
    }
  }
}

class ErrorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Failed to initialize Firebase.',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      ),
    );
  }
}