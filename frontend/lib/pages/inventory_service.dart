import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_item_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Track if service is in read-only mode
  bool _isReadOnly = false;
  
  // Set read-only mode
  void setReadOnly(bool readOnly) {
    _isReadOnly = readOnly;
  }
  
  // Check if service is in read-only mode and throw exception if trying to perform write operations
  void _checkReadOnly() {
    if (_isReadOnly) {
      throw Exception('Inventory service is in read-only mode. Modification operations are not allowed.');
    }
  }

  // Get the current user ID
  String? _getUserId() {
    return _auth.currentUser?.uid;
  }

  // Get the current user's display name
  Future<String?> _getUserDisplayName() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Try to get display name from auth first
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName;
      }
      
      // If not available in auth, try to get from Firestore user document
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          return data?['displayName'] as String?;
        }
      } catch (e) {
        print('Error fetching user display name: $e');
      }
    }
    return null;
  }

  CollectionReference _getInventoryCollection(String householdId) {
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory');
  }

  // Create a new inventory item with user's full name
  Future<String> addItem(String householdId, InventoryItem item) async {
    _checkReadOnly(); // Check if in read-only mode
    
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    
    // Get user's display name
    final String? addedByUserName = await _getUserDisplayName();
    
    // Prepare item data with user's name
    final Map<String, dynamic> itemData = item.toMap();
    if (addedByUserName != null) {
      itemData['addedByUserName'] = addedByUserName;
    }
    itemData['addedByUserId'] = _getUserId();
    
    var collection = _getInventoryCollection(householdId);
    var docRef = await collection.add(itemData);
    return docRef.id;
  }

  // Update an existing inventory item
  Future<void> updateItem(String householdId, InventoryItem item) async {
    _checkReadOnly(); // Check if in read-only mode
    
    if (householdId.isEmpty || item.id == null || item.id!.isEmpty) {
      throw Exception('Invalid parameters for update');
    }
    
    // Get user's display name for the update
    final String? updatedByUserName = await _getUserDisplayName();
    
    // Prepare update data
    final Map<String, dynamic> updateData = item.toMap();
    if (updatedByUserName != null) {
      updateData['updatedByUserName'] = updatedByUserName;
    }
    updateData['updatedByUserId'] = _getUserId();
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    var collection = _getInventoryCollection(householdId);
    return collection.doc(item.id).update(updateData);
  }

  // Delete an inventory item
  Future<void> deleteItem(String householdId, String itemId) async {
    _checkReadOnly(); // Check if in read-only mode
    
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
  _checkReadOnly(); // Check if in read-only mode
  
  if (householdId.isEmpty || itemId.isEmpty) {
    throw Exception('Household ID or Item ID cannot be empty');
  }
  
  // Get user's display name for the update
  final String? updatedByUserName = await _getUserDisplayName();
  
  var collection = _getInventoryCollection(householdId);
  final updateData = {
    'quantity': newQuantity,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  
  if (updatedByUserName != null) {
    updateData['updatedByUserName'] = updatedByUserName;
  }
; // Corrected here
  
  return collection.doc(itemId).update(updateData);
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

  // Get items with pagination
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

  // Get last document for pagination
  DocumentSnapshot getLastDocument(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) {
      throw Exception('No documents available');
    }
    return snapshot.docs.last;
  }
}