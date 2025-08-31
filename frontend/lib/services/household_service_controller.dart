import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/family_member.dart';
import '../pages/dashboard_page.dart';
import '../pages/login_page.dart';

class HouseholdServiceController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the user's households with details
  Future<List<Map<String, dynamic>>> getUserHouseholdsWithDetails() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      var snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('households')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['householdName'] as String,
          'createdAt': doc['createdAt'] as Timestamp,
        };
      }).toList();
    } catch (e) {
      print('Error fetching households: $e');
      throw e;
    }
  }

  // Get family members for a given household
  Future<List<FamilyMember>> getFamilyMembers(String householdId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    try {
      var snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .orderBy('firstName')
          .get();

      return snapshot.docs.map((doc) {
        return FamilyMember.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching family members: $e');
      throw e;
    }
  }

  // Add a family member to a household
  Future<void> addFamilyMember(String householdId, FamilyMember member) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .add(member.toMap());
    } catch (e) {
      print('Error adding family member: $e');
      throw e;
    }
  }

  // Delete a family member from a household
  Future<void> deleteFamilyMember(String householdId, String memberId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .doc(memberId)
          .delete();
    } catch (e) {
      print('Error deleting family member: $e');
      throw e;
    }
  }

  // Create a new household and get the householdId
  Future<void> createNewHousehold(BuildContext context) async {
    User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    String householdName = '';
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create New Household',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D5D7C),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  onChanged: (value) => householdName = value,
                  decoration: InputDecoration(
                    labelText: 'Household Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (householdName.isNotEmpty) {
                          try {
                            // Add new household and capture the auto-generated ID
                            var docRef = await _firestore
                                .collection('users')
                                .doc(user.uid)
                                .collection('households')
                                .add({
                              'householdName': householdName,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            // Capture the generated household ID
                            String householdId = docRef.id;

                            Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Household "$householdName" created successfully'),
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                            );

                            // Pass the householdId to navigate or use it elsewhere
                            selectHousehold(householdName, context, householdId);
                          } catch (e) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating household: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Navigate to the DashboardPage and pass the household ID
  void selectHousehold(String householdName, BuildContext context, String householdId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardPage(
          selectedHousehold: householdName,
          householdId: householdId,
        ),
      ),
    );
  }

  // Logout the user and navigate to login page
  void logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}
