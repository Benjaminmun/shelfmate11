class FamilyMember {
  final String? id;
  final String firstName;
  final String lastName;
  final String relationship;
  final String gender;
  final int age;
  final String contactInformation;

  FamilyMember({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.gender,
    required this.age,
    required this.contactInformation,
  });

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'relationship': relationship,
      'gender': gender,
      'age': age,
      'contactInformation': contactInformation,
    };
  }

  static FamilyMember fromMap(Map<String, dynamic> map, String id) {
    return FamilyMember(
      id: id,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      relationship: map['relationship'] ?? '',
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      contactInformation: map['contactInformation'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';
}