import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_item_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user ID
  String? _getUserId() {
    return _auth.currentUser?.uid;
  }

  CollectionReference _getInventoryCollection(String householdId) {
    String? userId = _getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated');
    }
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('households')
        .doc(householdId)
        .collection('inventory');
  }

  // Create a new inventory item
  Future<String> addItem(String householdId, InventoryItem item) async {
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    var collection = _getInventoryCollection(householdId);
    var docRef = await collection.add(item.toMap());
    return docRef.id;
  }

  // Update an existing inventory item
  Future<void> updateItem(String householdId, InventoryItem item) async {
    if (householdId.isEmpty || item.id == null || item.id!.isEmpty) {
      throw Exception('Invalid parameters for update');
    }
    var collection = _getInventoryCollection(householdId);
    return collection.doc(item.id).update(item.toMap());
  }

  // Delete an inventory item
  Future<void> deleteItem(String householdId, String itemId) async {
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    var collection = _getInventoryCollection(householdId);
    return collection.doc(itemId).delete();
  }

  // Get a stream of inventory items for a household with sorting options
  Stream<QuerySnapshot> getItemsStream(String householdId, {
    String sortField = 'name', 
    bool sortAscending = true
  }) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    try {
      var collection = _getInventoryCollection(householdId);
      return collection.orderBy(sortField, descending: !sortAscending).snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // Get a single inventory item
  Future<InventoryItem> getItem(String householdId, String itemId) async {
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    var collection = _getInventoryCollection(householdId);
    var doc = await collection.doc(itemId).get();
    if (!doc.exists) {
      throw Exception('Item not found');
    }
    return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // Get all unique categories from inventory
  Future<List<String>> getCategories(String householdId) async {
    if (householdId.isEmpty) {
      return [];
    }
    
    try {
      final snapshot = await _getInventoryCollection(householdId).get();
      
      // Extract unique categories
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] as String? ?? 'Uncategorized';
          })
          .toSet() // Remove duplicates
          .toList();
      
      // Sort alphabetically
      categories.sort();
      
      return categories;
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get low stock items (quantity less than threshold)
  Stream<QuerySnapshot> getLowStockItemsStream(String householdId, {int threshold = 5}) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    try {
      var collection = _getInventoryCollection(householdId);
      return collection
          .where('quantity', isLessThan: threshold)
          .orderBy('quantity')
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // Get items by category
  Stream<QuerySnapshot> getItemsByCategoryStream(String householdId, String category) {
    if (householdId.isEmpty || category.isEmpty) {
      return Stream.error(Exception('Household ID or Category cannot be empty'));
    }
    try {
      var collection = _getInventoryCollection(householdId);
      return collection
          .where('category', isEqualTo: category)
          .orderBy('name')
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // Search items by name
  Stream<QuerySnapshot> searchItems(String householdId, String query) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    try {
      var collection = _getInventoryCollection(householdId);
      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation that works for exact matches
      return collection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .orderBy('name')
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // Get total inventory value
  Future<double> getTotalInventoryValue(String householdId) async {
    if (householdId.isEmpty) {
      return 0.0;
    }
    
    try {
      final snapshot = await _getInventoryCollection(householdId).get();
      
      double totalValue = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantity = (data['quantity'] ?? 0).toDouble();
        final price = (data['price'] ?? 0).toDouble();
        totalValue += quantity * price;
      }
      
      return totalValue;
    } catch (e) {
      print('Error calculating total value: $e');
      return 0.0;
    }
  }

  // Get items expiring soon
  Stream<QuerySnapshot> getExpiringSoonItemsStream(String householdId, {int days = 7}) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: days));
      
      var collection = _getInventoryCollection(householdId);
      return collection
          .where('expiryDate', isGreaterThanOrEqualTo: now)
          .where('expiryDate', isLessThanOrEqualTo: thresholdDate)
          .orderBy('expiryDate')
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // Update item quantity (for restocking or usage)
  Future<void> updateItemQuantity(String householdId, String itemId, int newQuantity) async {
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    
    var collection = _getInventoryCollection(householdId);
    return collection.doc(itemId).update({
      'quantity': newQuantity,
      'updatedAt': Timestamp.now(),
    });
  }

  // Get items that need restocking (below minimum stock level)
  Stream<QuerySnapshot> getItemsNeedingRestockStream(String householdId, {int threshold = 5}) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    
    try {
      var collection = _getInventoryCollection(householdId);
      return collection
          .where('quantity', isLessThan: threshold)
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // NEW: Get items with pagination
  // In your InventoryService class
Future<Map<String, dynamic>> getItemsPaginated(
  String householdId, {
  DocumentSnapshot? lastDocument,
  int limit = 20,
  String sortField = 'name',
  bool sortAscending = true,
}) async {
  if (householdId.isEmpty) {
    throw Exception('Household ID cannot be empty');
  }
  
  try {
    Query query = _getInventoryCollection(householdId)
        .orderBy(sortField, descending: !sortAscending)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final querySnapshot = await query.get();
    final items = querySnapshot.docs.map((doc) {
      return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
    
    return {
      'items': items,
      'lastDocument': querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
    };
  } catch (e) {
    print('Error getting paginated items: $e');
    throw Exception('Failed to load items');
  }
}

  // NEW: Get last document for pagination
  DocumentSnapshot getLastDocument(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) {
      throw Exception('No documents available');
    }
    return snapshot.docs.last;
  }
}