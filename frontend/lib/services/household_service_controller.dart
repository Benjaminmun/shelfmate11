import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../pages/Dashboard/dashboard_page.dart';
import '../pages/Dashboard/member_dashboard_page.dart';
import '../pages/Dashboard/editor_dashboard_page.dart';
import '../pages/login_page.dart';

class PaginationResult {
  final List<Map<String, dynamic>> members;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  PaginationResult({
    required this.members,
    required this.lastDocument,
    required this.hasMore,
  });
}

class HouseholdServiceController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Get user role for a specific household - checks both locations
  Future<String> getUserRole(String householdId) async {
    if (currentUser == null) return 'member';

    try {
      // First check the main household members collection (source of truth)
      final householdMemberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(currentUser!.uid)
          .get();

      if (householdMemberDoc.exists) {
        return householdMemberDoc.data()?['userRole'] ?? 'member';
      }

      // Fallback to user's personal collection
      final userHouseholdDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .get();

      return userHouseholdDoc.data()?['userRole'] ?? 'member';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'member';
    }
  }

  // Check if user is household owner
  Future<bool> isHouseholdOwner(String householdId) async {
    final role = await getUserRole(householdId);
    return role == 'creator';
  }

  // Check if user is editor or admin
  Future<bool> hasEditorAccess(String householdId) async {
    final role = await getUserRole(householdId);
    return role == 'creator' || role == 'editor';
  }

  // Get households with user role information
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
          'userRole': data['userRole'] ?? 'member',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching households: $e');
      return [];
    }
  }

  // FIXED: Return Future<Map<String, dynamic>> instead of void
  Future<Map<String, dynamic>> createNewHousehold(BuildContext context) async {
    if (currentUser == null) {
      return {'success': false, 'error': 'User not logged in'};
    }

    String householdName = '';

    // Use a Completer to get the result from the dialog
    final completer = Completer<Map<String, dynamic>>();

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        completer.complete({
                          'success': false,
                          'error': 'Cancelled',
                        });
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (householdName.isEmpty) return;

                        try {
                          final docRef = _firestore
                              .collection('households')
                              .doc();

                          final invitationCode = _generateInvitationCode();

                          // Create main household document
                          await docRef.set({
                            'householdName': householdName,
                            'createdAt': FieldValue.serverTimestamp(),
                            'householdId': docRef.id,
                            'invitationCode': invitationCode,
                            'ownerId': currentUser!.uid,
                          });

                          // Add user as member with creator role
                          await docRef
                              .collection('members')
                              .doc(currentUser!.uid)
                              .set({
                                'userId': currentUser!.uid,
                                'joinedAt': FieldValue.serverTimestamp(),
                                'userRole': 'creator',
                                'email': currentUser!.email,
                              });

                          // Create user household reference
                          await _firestore
                              .collection('users')
                              .doc(currentUser!.uid)
                              .collection('households')
                              .doc(docRef.id)
                              .set({
                                'householdName': householdName,
                                'createdAt': FieldValue.serverTimestamp(),
                                'householdId': docRef.id,
                                'invitationCode': invitationCode,
                                'userRole': 'creator',
                                'joinedAt': FieldValue.serverTimestamp(),
                              });

                          Navigator.pop(ctx);

                          // Complete the completer with success data
                          completer.complete({
                            'success': true,
                            'householdId': docRef.id,
                            'householdName': householdName,
                            'invitationCode': invitationCode,
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Household "$householdName" created successfully',
                              ),
                              backgroundColor: const Color(0xFF4CAF50),
                            ),
                          );

                          _showInvitationDialog(
                            context,
                            invitationCode,
                            householdName,
                          );
                        } catch (e) {
                          Navigator.pop(ctx);
                          completer.complete({
                            'success': false,
                            'error': e.toString(),
                          });
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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

    return completer.future;
  }

  // Join household with invitation code
  Future<void> joinHousehold(
    BuildContext context,
    String invitationCode,
  ) async {
    if (currentUser == null) return;

    try {
      // Find household with the invitation code
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
      final householdName =
          householdData['householdName'] ?? 'Unknown Household';
      final householdId = householdDoc.id;
      final ownerId = householdData['ownerId'];

      // Check if user is the owner of this household
      if (currentUser!.uid == ownerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already the owner of this household'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

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

      // Add user to household members with member role
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(currentUser!.uid)
          .set({
            'userId': currentUser!.uid,
            'joinedAt': FieldValue.serverTimestamp(),
            'userRole': 'member',
            'email': currentUser!.email,
          });

      // Add household to user's collection
      await userHouseholdRef.set({
        'householdName': householdName,
        'createdAt': FieldValue.serverTimestamp(),
        'householdId': householdId,
        'invitationCode': invitationCode,
        'userRole': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined $householdName'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      Navigator.of(context).pop();

      // Navigate to appropriate dashboard based on role
      await selectHousehold(householdName, context, householdId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining household: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete household (only for owners)
  Future<void> deleteHousehold(String householdId) async {
    if (currentUser == null) return;

    try {
      final isOwner = await isHouseholdOwner(householdId);
      if (!isOwner) {
        throw Exception('Only household owners can delete households');
      }

      // Delete the household document from user's collection
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .doc(householdId)
          .delete();

      // Delete the main household document (security rules will prevent if not owner)
      await _firestore.collection('households').doc(householdId).delete();
    } catch (e) {
      debugPrint('Error deleting household: $e');
      rethrow;
    }
  }

  // Get all members from the household
  Future<List<Map<String, dynamic>>> getHouseholdMembers(
    String householdId,
  ) async {
    if (currentUser == null) return [];

    try {
      // Check if user has access to this household
      final memberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(currentUser!.uid)
          .get();

      if (!memberDoc.exists) {
        throw Exception('You do not have access to this household');
      }

      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .orderBy('joinedAt')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'email': data['email'],
          'userRole': data['userRole'],
          'joinedAt': data['joinedAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching household members: $e');
      return [];
    }
  }

  // Get paginated household members
  Future<PaginationResult> getHouseholdMembersPaginated(
    String householdId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // Check if user has access to this household
      final memberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(currentUser!.uid)
          .get();

      if (!memberDoc.exists) {
        throw Exception('You do not have access to this household');
      }

      Query query = _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .orderBy('joinedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<Map<String, dynamic>> members = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['userId'] = doc.id; // Add the document ID as userId
        members.add(data);
      }

      DocumentSnapshot? lastDoc = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      return PaginationResult(
        members: members,
        lastDocument: lastDoc,
        hasMore: members.length == limit,
      );
    } catch (e) {
      throw Exception('Error fetching paginated members: $e');
    }
  }

  // Remove a household member (only for owners)
  Future<void> removeHouseholdMember(String householdId, String userId) async {
    try {
      // Check if current user is the owner
      final role = await getUserRole(householdId);
      if (role != 'creator') {
        throw Exception('Only household owners can remove members');
      }

      // Remove from household members collection
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(userId)
          .delete();

      // Remove from user's households collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('households')
          .doc(householdId)
          .delete();
    } catch (e) {
      throw Exception('Error removing household member: $e');
    }
  }

  // Update member role (only for owners)
  Future<void> updateMemberRole(
    String householdId,
    String userId,
    String newRole,
  ) async {
    try {
      // Check if current user is the owner
      final currentUserRole = await getUserRole(householdId);
      if (currentUserRole != 'creator') {
        throw Exception('Only household owners can update member roles');
      }

      // Validate the new role
      if (!['member', 'editor', 'creator'].contains(newRole)) {
        throw Exception('Invalid role: $newRole');
      }

      // Cannot change owner's role
      if (newRole == 'creator') {
        throw Exception('Cannot assign creator role to members');
      }

      // Update role in household members collection
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(userId)
          .update({
            'userRole': newRole,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update role in user's personal collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('households')
          .doc(householdId)
          .update({
            'userRole': newRole,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Error updating member role: $e');
    }
  }

  // Generate random invitation code
  String _generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  void _showInvitationDialog(
    BuildContext context,
    String invitationCode,
    String householdName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
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
    final shareText =
        'Join my household "$householdName" on HomeHub! Use code: $invitationCode';
    Share.share(shareText);
  }

  // UPDATED: Role-based navigation with editor support
  Future<void> selectHousehold(
    String householdName,
    BuildContext context,
    String householdId,
  ) async {
    try {
      // Get the user's role for this household
      final userRole = await getUserRole(householdId);

      // Navigate to appropriate dashboard based on role
      switch (userRole) {
        case 'creator':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(
                selectedHousehold: householdName,
                householdId: householdId,
              ),
            ),
          );
          break;
        case 'editor':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EditorDashboardPage(
                selectedHousehold: householdName,
                householdId: householdId,
              ),
            ),
          );
          break;
        case 'member':
        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MemberDashboardPage(
                selectedHousehold: householdName,
                householdId: householdId,
              ),
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint('Error selecting household: $e');
      // Fallback to member dashboard if there's an error
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MemberDashboardPage(
            selectedHousehold: householdName,
            householdId: householdId,
          ),
        ),
      );
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

  void showJoinHouseholdDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  style: TextStyle(color: Colors.grey[700]),
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
                          joinHousehold(
                            context,
                            codeController.text.toUpperCase(),
                          );
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

  // Sync user role between main household and user collection
  Future<void> syncUserRole(String householdId) async {
    if (currentUser == null) return;

    try {
      // Get role from main household collection
      final householdMemberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(currentUser!.uid)
          .get();

      if (householdMemberDoc.exists) {
        final role = householdMemberDoc.data()?['userRole'] ?? 'member';

        // Update user's personal collection
        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('households')
            .doc(householdId)
            .update({'userRole': role});
      }
    } catch (e) {
      debugPrint('Error syncing user role: $e');
    }
  }

  // Repair role inconsistencies
  Future<void> repairRoleInconsistencies() async {
    if (currentUser == null) return;

    try {
      final userHouseholds = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('households')
          .get();

      for (var householdDoc in userHouseholds.docs) {
        final householdId = householdDoc.id;
        await syncUserRole(householdId);
      }
    } catch (e) {
      debugPrint('Error repairing role inconsistencies: $e');
    }
  }

  // Get household statistics
  Future<Map<String, dynamic>> getHouseholdStats(String householdId) async {
    try {
      // Get member count
      final membersSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .get();

      // Get inventory count
      final inventorySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      // Get recent activities count (last 7 days)
      final weekAgo = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: 7)),
      );
      final activitiesSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('activities')
          .where('timestamp', isGreaterThanOrEqualTo: weekAgo)
          .get();

      return {
        'memberCount': membersSnapshot.docs.length,
        'inventoryCount': inventorySnapshot.docs.length,
        'recentActivities': activitiesSnapshot.docs.length,
        'roles': {
          'creator': membersSnapshot.docs
              .where((doc) => doc['userRole'] == 'creator')
              .length,
          'editor': membersSnapshot.docs
              .where((doc) => doc['userRole'] == 'editor')
              .length,
          'member': membersSnapshot.docs
              .where((doc) => doc['userRole'] == 'member')
              .length,
        },
      };
    } catch (e) {
      debugPrint('Error getting household stats: $e');
      return {};
    }
  }
}
