import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberItem {
  final String familyMemberId;
  final String itemId;
  final double quantityUsed;
  final DateTime dateUsed;
  final String status;

  FamilyMemberItem({
    required this.familyMemberId,
    required this.itemId,
    required this.quantityUsed,
    required this.dateUsed,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'familyMemberId': familyMemberId,
      'itemId': itemId,
      'quantityUsed': quantityUsed,
      'dateUsed': Timestamp.fromDate(dateUsed),
      'status': status,
    };
  }

  static FamilyMemberItem fromMap(Map<String, dynamic> map) {
    return FamilyMemberItem(
      familyMemberId: map['familyMemberId'] ?? '',
      itemId: map['itemId'] ?? '',
      quantityUsed: (map['quantityUsed'] ?? 0).toDouble(),
      dateUsed: (map['dateUsed'] as Timestamp).toDate(),
      status: map['status'] ?? '',
    );
  }
}