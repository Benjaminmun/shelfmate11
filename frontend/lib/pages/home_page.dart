import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // Color scheme from DashboardPage
  static const Color primaryColor = Color(0xFF2D5D7C);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFFFF9800);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);
  static const Color lightTextColor = Color(0xFF64748B);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 40),
                // Logo with enhanced shadow and animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildLogo(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // App name with gradient and animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildAppName(),
                  ),
                ),
                const SizedBox(height: 10),
                // Tagline with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildTagline(),
                  ),
                ),
                const SizedBox(height: 50),
                // Feature cards with staggered animation
                _buildFeatureGrid(),
                const SizedBox(height: 50),
                // Sign up and Log in buttons with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildButton(context, 'Get Started', const SignUpPage(), secondaryColor),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildOutlinedButton(context, 'Log In', const LoginPage()),
                  ),
                ),
                const SizedBox(height: 40),
                // Divider with text and animation
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        width: 160,
        height: 160,
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
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        'Shelf Mate',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      'Simplify your inventory management',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textColor.withOpacity(0.7),
        letterSpacing: 0.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFeatureGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 13,
        mainAxisSpacing: 13,
        childAspectRatio: 0.82,
      ),
      children: [
        _buildFeatureCard(
          'Inventory Overview',
          'Get a complete overview of your stock',
          Icons.inventory_2_outlined,
          primaryColor,
        ),
        _buildFeatureCard(
          'Real-Time Sync',
          'Sync inventory across devices instantly',
          Icons.sync,
          secondaryColor,
        ),
        _buildFeatureCard(
          'Barcode Scanning',
          'Scan and manage inventory items using Barcodes',
          Icons.camera_alt,
          accentColor,
        ),
        _buildFeatureCard(
          'Expense Tracking',
          'Track your inventory expenses',
          Icons.attach_money,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color color) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: lightTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, Widget page, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () => _navigateToPage(page),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: color.withOpacity(0.4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context, String text, Widget page) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: () => _navigateToPage(page),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.transparent,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }


}