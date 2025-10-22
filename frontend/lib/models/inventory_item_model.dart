import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue;

/// Represents an item stored in the inventory.
class InventoryItem {
  final String? id;
  final String name;
  final String category;
  final int quantity;
  final String? description;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? location;
  final String? barcode;
  final int? minStockLevel;
  final String? imageUrl;
  final String? localImagePath; // ✅ Only stored in household inventory
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? addedByUserId;
  final String? addedByUserName;
  final String householdId;
  final String householdName;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.description,
    this.purchaseDate,
    this.expiryDate,
    this.location,
    this.barcode,
    this.minStockLevel,
    this.imageUrl,
    this.localImagePath, // ✅ Only for household inventory
    required this.createdAt,
    this.updatedAt,
    this.addedByUserId,
    this.addedByUserName,
    required this.householdId,
    required this.householdName,
  });

  get price => null;

  /// Converts object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'description': description,
      'purchaseDate': _dateToTimestamp(purchaseDate),
      'expiryDate': _dateToTimestamp(expiryDate),
      'location': location,
      'barcode': barcode,
      'minStockLevel': minStockLevel,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath, // ✅ Only in household inventory
      'createdAt': _dateToTimestamp(createdAt) ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'householdId': householdId,
      'householdName': householdName,
    };
  }

  /// Helper method to convert DateTime to Timestamp
  Timestamp? _dateToTimestamp(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }

  /// Converts Firestore document into InventoryItem object
  static InventoryItem fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      quantity: (map['quantity'] ?? 0).toInt(),
      description: map['description'],
      purchaseDate: _timestampToDate(map['purchaseDate']),
      expiryDate: _timestampToDate(map['expiryDate']),
      location: map['location'],
      barcode: map['barcode'],
      minStockLevel: map['minStockLevel']?.toInt(),
      imageUrl: map['imageUrl'],
      localImagePath: map['localImagePath'], // ✅ Load from household inventory
      createdAt: _timestampToDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _timestampToDate(map['updatedAt']),
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      householdId: map['householdId'] ?? '',
      householdName: map['householdName'] ?? '',
    );
  }

  /// Helper method to convert Timestamp to DateTime
  static DateTime? _timestampToDate(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  /// Creates a copy of the item with updated fields
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    String? description,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? location,
    String? barcode,
    int? minStockLevel,
    String? imageUrl,
    String? localImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedByUserId,
    String? addedByUserName,
    String? householdId,
    String? householdName,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      location: location ?? this.location,
      barcode: barcode ?? this.barcode,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      householdId: householdId ?? this.householdId,
      householdName: householdName ?? this.householdName,
    );
  }

  /// Creates a map for update operations (only includes changed fields)
  Map<String, dynamic> toUpdateMap({
    String? name,
    String? category,
    int? quantity,
    String? description,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? location,
    String? barcode,
    int? minStockLevel,
    String? imageUrl,
    String? localImagePath,
  }) {
    final map = <String, dynamic>{};
    
    if (name != null) map['name'] = name;
    if (category != null) map['category'] = category;
    if (quantity != null) map['quantity'] = quantity;
    if (description != null) map['description'] = description;
    if (purchaseDate != null) map['purchaseDate'] = _dateToTimestamp(purchaseDate);
    if (expiryDate != null) map['expiryDate'] = _dateToTimestamp(expiryDate);
    if (location != null) map['location'] = location;
    if (barcode != null) map['barcode'] = barcode;
    if (minStockLevel != null) map['minStockLevel'] = minStockLevel;
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    if (localImagePath != null) map['localImagePath'] = localImagePath;
    
    // Always update the updatedAt timestamp
    map['updatedAt'] = FieldValue.serverTimestamp();
    
    return map;
  }
}

/// Represents a product in the global products collection (without localImagePath)
class Product {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String? description;
  final String? imageUrl; // ✅ Only Firebase Storage URL, no localImagePath
  final DateTime lastUpdated;

  Product({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    this.description,
    this.imageUrl, // ❌ No localImagePath in products collection
    required this.lastUpdated,
  });

  /// Converts object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'category': category,
      'description': description,
      'imageUrl': imageUrl, // ✅ Only URL, no local path
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Converts Firestore document into Product object
  static Product fromMap(Map<String, dynamic> map, String barcode) {
    return Product(
      barcode: barcode,
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      category: map['category'] ?? 'Other',
      description: map['description'],
      imageUrl: map['imageUrl'], // ✅ Only URL from products collection
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }
}