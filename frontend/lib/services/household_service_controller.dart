import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/family_member.dart';
import '../pages/dashboard_page.dart';
import '../pages/login_page.dart';

class HouseholdServiceController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<List<Map<String, dynamic>>> getUserHouseholdsWithDetails() async {
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'householdId': doc.id,
          'name': data['householdName'] ?? 'Unnamed',
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'invitationCode': data['invitationCode'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching households: $e');
      return [];
    }
  }

  // Get invitation code for a specific household
  Future<String> getInvitationCode(String householdId) async {
    if (currentUser == null) return '';
    
    try {
      final householdDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .get();
          
      return householdDoc.data()?['invitationCode'] ?? '';
    } catch (e) {
      debugPrint('Error getting invitation code: $e');
      return '';
    }
  }

  Future<List<FamilyMember>> getFamilyMembers(String householdId) async {
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .orderBy('firstName')
          .get();

      return snapshot.docs
          .map((doc) => FamilyMember.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching family members: $e');
      return [];
    }
  }

  Future<void> addFamilyMember(String householdId, FamilyMember member) async {
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .add(member.toMap());
    } catch (e) {
      debugPrint('Error adding family member: $e');
    }
  }

  Future<void> deleteFamilyMember(String householdId, String memberId) async {
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .doc(memberId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting family member: $e');
    }
  }

  // Generate a random invitation code
  String _generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  Future<void> createNewHousehold(BuildContext context) async {
    if (currentUser == null) return;

    String householdName = '';
    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create New Household',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D5D7C),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (value) => householdName = value.trim(),
                  decoration: InputDecoration(
                    labelText: 'Household Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (householdName.isEmpty) return;

                        try {
                          final docRef = _firestore
                              .collection('users')
                              .doc(currentUser!.uid)
                              .collection('households')
                              .doc();

                          final invitationCode = _generateInvitationCode();

                          await docRef.set({
                            'householdName': householdName,
                            'createdAt': FieldValue.serverTimestamp(),
                            'householdId': docRef.id,
                            'invitationCode': invitationCode,
                            'ownerId': currentUser!.uid,
                          });

                          // Also create a reference in the main households collection
                          await _firestore
                              .collection('households')
                              .doc(docRef.id)
                              .set({
                            'householdName': householdName,
                            'createdAt': FieldValue.serverTimestamp(),
                            'householdId': docRef.id,
                            'invitationCode': invitationCode,
                            'ownerId': currentUser!.uid,
                            'members': [currentUser!.uid],
                          });

                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Household "$householdName" created successfully'),
                              backgroundColor: const Color(0xFF4CAF50),
                            ),
                          );

                          // Show invitation code after creation
                          _showInvitationDialog(context, invitationCode, householdName);

                          selectHousehold(householdName, context, docRef.id);
                        } catch (e) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating household: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Create'),
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

  void _showInvitationDialog(BuildContext context, String invitationCode, String householdName) {
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
                Text(
                  'Household Created!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5D7C),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Share this code with family members to join your household:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF2D5D7C), width: 2),
                  ),
                  child: Text(
                    invitationCode,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5D7C),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close),
                      label: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[800],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _shareInvitationCode(invitationCode, householdName);
                      },
                      icon: Icon(Icons.share),
                      label: Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D5D7C),
                        foregroundColor: Colors.white,
                      ),
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

  void _shareInvitationCode(String invitationCode, String householdName) {
    final shareText = 'Join my household "$householdName" on HomeHub! Use code: $invitationCode';
    Share.share(shareText);
  }

  Future<void> joinHousehold(BuildContext context, String invitationCode) async {
    if (currentUser == null) return;

    try {
      // Find household with the invitation code in the main households collection
      final querySnapshot = await _firestore
          .collection('households')
          .where('invitationCode', isEqualTo: invitationCode)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid invitation code'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final householdDoc = querySnapshot.docs.first;
      final householdData = householdDoc.data();
      final householdName = householdData['householdName'] ?? 'Unknown Household';
      final householdId = householdDoc.id;

      // Check if user already has this household
      final userHouseholdRef = _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId);

      final userHouseholdDoc = await userHouseholdRef.get();

      if (userHouseholdDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You already belong to this household'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add household to user's collection
      await userHouseholdRef.set({
        'householdName': householdName,
        'createdAt': FieldValue.serverTimestamp(),
        'householdId': householdId,
        'invitationCode': invitationCode,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add user to the household's members list
      await _firestore
          .collection('households')
          .doc(householdId)
          .update({
            'members': FieldValue.arrayUnion([currentUser!.uid])
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined $householdName'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      // Refresh the household list
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining household: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void selectHousehold(
      String householdName, BuildContext context, String householdId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          selectedHousehold: householdName,
          householdId: householdId,
        ),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: $e")),
      );
    }
  }

  Future<void> deleteHousehold(String householdId) async {
    if (currentUser == null) return;

    try {
      // Delete the household document from user's collection
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .delete();

      // Also delete all family members under this household
      final familyMembersSnapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .collection('familyMembers')
          .get();

      final batch = _firestore.batch();
      for (var doc in familyMembersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // Remove user from the main household's members list
      await _firestore
          .collection('households')
          .doc(householdId)
          .update({
            'members': FieldValue.arrayRemove([currentUser!.uid])
          });
    } catch (e) {
      debugPrint('Error deleting household: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllHouseholdsWithIds() async {
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'householdId': doc.id,
          'name': data['householdName'] ?? 'Unnamed',
          'createdAt': data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate().toIso8601String()
              : 'Unknown',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all households: $e');
      return [];
    }
  }

  // Show dialog to join a household with an invitation code
  void showJoinHouseholdDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

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
                Text(
                  'Join a Household',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5D7C),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Enter the invitation code provided by the household owner:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Invitation Code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (codeController.text.isNotEmpty) {
                          joinHousehold(context, codeController.text.toUpperCase());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D5D7C),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Join'),
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
}