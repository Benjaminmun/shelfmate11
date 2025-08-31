import 'package:flutter/material.dart';
import '../services/household_service_controller.dart';
import '../models/family_member.dart';

class FamilyMembersPage extends StatefulWidget {
  final String householdId;

  const FamilyMembersPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _FamilyMembersPageState createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFE2E6E0);
  
  List<FamilyMember> _familyMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final members = await _controller.getFamilyMembers(widget.householdId);
      setState(() {
        _familyMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading family members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddFamilyMemberDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final relationshipController = TextEditingController();
    final genderController = TextEditingController();
    final ageController = TextEditingController();
    final contactController = TextEditingController();

    String selectedGender = 'Male';
    String selectedRelationship = 'Father';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Family Member',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRelationship,
                    items: ['Father', 'Mother', 'Son', 'Daughter', 'Grandfather', 'Grandmother', 'Other']
                        .map((relationship) => DropdownMenuItem<String>(
                              value: relationship,
                              child: Text(relationship),
                            ))
                        .toList(),
                    onChanged: (value) {
                      selectedRelationship = value!;
                    },
                    decoration: InputDecoration(
                      labelText: 'Relationship',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    items: ['Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem<String>(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) {
                      selectedGender = value!;
                    },
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Information (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        onPressed: () async {
                          if (firstNameController.text.isNotEmpty &&
                              lastNameController.text.isNotEmpty &&
                              ageController.text.isNotEmpty) {
                            try {
                              final newMember = FamilyMember(
                                firstName: firstNameController.text,
                                lastName: lastNameController.text,
                                relationship: selectedRelationship,
                                gender: selectedGender,
                                age: int.parse(ageController.text),
                                contactInformation: contactController.text,
                              );
                              
                              await _controller.addFamilyMember(widget.householdId, newMember);
                              Navigator.pop(context);
                              _loadFamilyMembers();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Family member added successfully'),
                                  backgroundColor: accentColor,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding family member: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Please fill all required fields'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Family Members",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : _familyMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.black38),
                      SizedBox(height: 16),
                      Text(
                        'No family members yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add your first family member to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _familyMembers[index];
                      return Card(
                        elevation: 3,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.2),
                            child: Icon(
                              member.relationship == 'Father' || member.relationship == 'Son' || member.relationship == 'Grandfather'
                                  ? Icons.man
                                  : Icons.woman,
                              color: primaryColor,
                            ),
                          ),
                          title: Text(
                            '${member.firstName} ${member.lastName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${member.relationship}, ${member.age} years old'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text('Are you sure you want to delete ${member.firstName} ${member.lastName}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  );
                                },
                              );
                              
                              if (confirmed == true) {
                                try {
                                  await _controller.deleteFamilyMember(widget.householdId, member.id!);
                                  _loadFamilyMembers();
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Family member deleted successfully'),
                                      backgroundColor: accentColor,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error deleting family member: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFamilyMemberDialog,
        backgroundColor: accentColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}