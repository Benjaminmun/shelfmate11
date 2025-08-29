import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F4F4), // Light grey background
      appBar: AppBar(
        title: Text('Shelf Mate', style: TextStyle(fontSize: 24)),
        backgroundColor: Colors.black, // Dark background for AppBar
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/logo.png', width: 120), // Example logo (replace with your own)
            SizedBox(height: 20),
            Text(
              'Simplify your inventory management.',
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            SizedBox(height: 40),
            _buildElevatedButton(context, 'Sign Up', SignUpPage()),
            SizedBox(height: 20),
            _buildElevatedButton(context, 'Log In', LoginPage()),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.g_mobiledata, color: Colors.black),
                  onPressed: () {
                    // Add your Google login logic here
                  },
                ),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.facebook, color: Colors.black),
                  onPressed: () {
                    // Add your Facebook login logic here
                  },
                ),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.email, color: Colors.black),
                  onPressed: () {
                    // Add your Email login logic here
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevatedButton(BuildContext context, String text, Widget page) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(text, style: TextStyle(fontSize: 18)),
    );
  }
}