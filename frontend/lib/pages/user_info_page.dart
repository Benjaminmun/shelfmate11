import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'household_service.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser!.uid;
      final userData = {
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));

      // Save completion status locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('userInfoCompleted_$userId', true);

      // Navigate to HouseholdService
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HouseholdService()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving information: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE2E6E0),
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        backgroundColor: Color(0xFF2D5D7C),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 20),
                Text(
                  'We need some additional information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.7)),
                ),
                SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: firstNameController, label: 'First Name', icon: Icons.person_outline),
                      SizedBox(height: 20),
                      _buildTextField(controller: lastNameController, label: 'Last Name', icon: Icons.person_outline),
                      SizedBox(height: 20),
                      _buildTextField(controller: phoneController, label: 'Phone Number', icon: Icons.phone, keyboardType: TextInputType.phone),
                      SizedBox(height: 20),
                      _buildTextField(controller: addressController, label: 'Address', icon: Icons.home, maxLines: 2),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                _isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50))))
                    : SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _saveUserInfo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4CAF50),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text('Save Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
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
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(fontSize: 16),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF2D5D7C)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}