import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String? id;
  final String firstName;
  final String lastName;
  final String relationship;
  final String gender;
  final int age;
  final String contactInformation;
  final DateTime createdAt;

  FamilyMember({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.gender,
    required this.age,
    required this.contactInformation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert a FamilyMember to a Map
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'relationship': relationship,
      'gender': gender,
      'age': age,
      'contactInformation': contactInformation,
      'createdAt': Timestamp.fromDate(createdAt),
      if (id != null) 'id': id,
    };
  }

  // Create a FamilyMember from a Map
  factory FamilyMember.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMember(
      id: id,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      relationship: map['relationship'] ?? '',
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      contactInformation: map['contactInformation'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create a copy of a FamilyMember with updated values
  FamilyMember copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? relationship,
    String? gender,
    int? age,
    String? contactInformation,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      relationship: relationship ?? this.relationship,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      contactInformation: contactInformation ?? this.contactInformation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'FamilyMember(id: $id, firstName: $firstName, lastName: $lastName, relationship: $relationship, gender: $gender, age: $age, contactInformation: $contactInformation, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is FamilyMember &&
        other.id == id &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.relationship == relationship &&
        other.gender == gender &&
        other.age == age &&
        other.contactInformation == contactInformation &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        relationship.hashCode ^
        gender.hashCode ^
        age.hashCode ^
        contactInformation.hashCode ^
        createdAt.hashCode;
  }
}