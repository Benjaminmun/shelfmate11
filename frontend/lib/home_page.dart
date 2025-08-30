import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color customBlack = Color(0xFF000000);
  static const Color primaryColor = Color(0xFF2D5D7C);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color lightBackground = Color(0xFFE2E6E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(height: 40),
                // Logo with enhanced shadow
                _buildLogo(),
                SizedBox(height: 20),
                // App name with gradient
                _buildAppName(),
                SizedBox(height: 10),
                // Tagline
                _buildTagline(),
                SizedBox(height: 50),
                // New Feature Highlights
                _buildFeatureRow(Icons.inventory_2_outlined, 'Inventory Overview', 'Get a complete overview of your stock'),
                SizedBox(height: 20),
                _buildFeatureRow(Icons.sync, 'Real-Time Sync', 'Sync inventory across devices instantly'),
                SizedBox(height: 20),
                _buildFeatureRow(Icons.camera_alt, 'OCR', 'Scan and manage inventory items using OCR'),
                SizedBox(height: 50),
                // Sign up and Log in buttons
                _buildButton(context, 'Get Started', SignUpPage(), accentColor),
                SizedBox(height: 20),
                _buildOutlinedButton(context, 'Log In', LoginPage()),
                SizedBox(height: 40),
                // Divider with text
                _buildDividerWithText('Or continue with'),
                SizedBox(height: 30),
                // Social media buttons
                _buildSocialMediaButtons(),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() => Container(
    decoration: BoxDecoration(
      boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 20, spreadRadius: 2, offset: Offset(0, 8))],
    ),
    child: Image.asset('assets/logo.png', width: 160, height: 160),
  );

  Widget _buildAppName() => ShaderMask(
    shaderCallback: (bounds) => LinearGradient(
      colors: [primaryColor, accentColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(bounds),
    child: Text(
      'Shelf Mate',
      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
    ),
  );

  Widget _buildTagline() => Text(
    'Simplify your inventory management',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: customBlack.withOpacity(0.7), letterSpacing: 0.5),
    textAlign: TextAlign.center,
  );

  Widget _buildFeatureRow(IconData icon, String title, String description) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 6))]),
    child: Row(
      children: [
        _buildFeatureIcon(icon),
        SizedBox(width: 16),
        _buildFeatureText(title, description),
      ],
    ),
  );

  Widget _buildFeatureIcon(IconData icon) => Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
    child: Icon(icon, color: primaryColor, size: 24),
  );

  Widget _buildFeatureText(String title, String description) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: customBlack.withOpacity(0.9))),
        SizedBox(height: 4),
        Text(description, style: TextStyle(fontSize: 14, color: customBlack.withOpacity(0.6))),
      ],
    ),
  );

  Widget _buildButton(BuildContext context, String text, Widget page, Color color) => SizedBox(
    width: double.infinity,
    height: 58,
    child: ElevatedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
      style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), shadowColor: color.withOpacity(0.4)),
      child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );

  Widget _buildOutlinedButton(BuildContext context, String text, Widget page) => SizedBox(
    width: double.infinity,
    height: 58,
    child: OutlinedButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
      style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: BorderSide(color: primaryColor, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: EdgeInsets.symmetric(vertical: 16)),
      child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _buildDividerWithText(String text) => Row(
    children: [
      Expanded(child: Divider(color: customBlack.withOpacity(0.2), thickness: 1)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: Text(text, style: TextStyle(color: customBlack.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500))),
      Expanded(child: Divider(color: customBlack.withOpacity(0.2), thickness: 1)),
    ],
  );

  Widget _buildSocialMediaButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      _buildSocialMediaButton(Icons.g_mobiledata, Color(0xFFDB4437), 'Google'),
      SizedBox(width: 25),
      _buildSocialMediaButton(Icons.facebook, Color(0xFF4267B2), 'Facebook'),
      SizedBox(width: 25),
      _buildSocialMediaButton(Icons.email, customBlack, 'Email'),
    ],
  );

  Widget _buildSocialMediaButton(IconData icon, Color color, String tooltip) => Tooltip(
    message: tooltip,
    child: Material(
      elevation: 4,
      shape: CircleBorder(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: Offset(0, 4))]),
        child: IconButton(
          icon: Icon(icon, color: color, size: 28),
          onPressed: () {
            // Add social media login logic here
          },
        ),
      ),
    ),
  );
}
