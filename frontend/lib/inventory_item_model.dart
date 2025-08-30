class InventoryItem {
  String? id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String description;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.description = '',
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert InventoryItem to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'description': description,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create InventoryItem from Firestore document
  static InventoryItem fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      price: map['price'].toDouble(),
      description: map['description'],
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}