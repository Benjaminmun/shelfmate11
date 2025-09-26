import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/inventory_item_model.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isReadOnly = false;
  
  void setReadOnly(bool readOnly) {
    _isReadOnly = readOnly;
  }
  
  void _checkReadOnly() {
    if (_isReadOnly) {
      throw Exception('Inventory service is in read-only mode. Modification operations are not allowed.');
    }
  }

  String? _getUserId() {
    return _auth.currentUser?.uid;
  }

  Future<String?> _getUserDisplayName() async {
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName;
      }
      
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          return data?['displayName'] as String?;
        }
      } catch (e) {
        print('Error fetching user display name: $e');
      }
    }
    return null;
  }

  // ========== PRODUCTS COLLECTION (GLOBAL) ==========
  
  Future<bool> doesProductExist(String barcode) async {
    try {
      final doc = await _firestore.collection('products').doc(barcode).get();
      return doc.exists;
    } catch (e) {
      print('Error checking product existence: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProduct(String barcode) async {
    try {
      final doc = await _firestore.collection('products').doc(barcode).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  Future<void> addProductToGlobal(String barcode, Map<String, dynamic> productData) async {
    _checkReadOnly();
    
    try {
      await _firestore.collection('products').doc(barcode).set({
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _getUserId(),
      });
    } catch (e) {
      print('Error adding product to global collection: $e');
      throw Exception('Failed to add product to database');
    }
  }

  // ========== HOUSEHOLD INVENTORY COLLECTION ==========
  
  CollectionReference _getInventoryCollection(String householdId) {
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory');
  }

  Future<String> addItem(String householdId, InventoryItem item) async {
    _checkReadOnly();
    
    if (householdId.isEmpty) {
      throw Exception('Household ID cannot be empty');
    }
    
    final String? addedByUserName = await _getUserDisplayName();
    
    final Map<String, dynamic> itemData = item.toMap();
    if (addedByUserName != null) {
      itemData['addedByUserName'] = addedByUserName;
    }
    itemData['addedByUserId'] = _getUserId();
    
    // If item has a barcode, ensure it exists in global products
    if (item.barcode != null && item.barcode!.isNotEmpty) {
      final productExists = await doesProductExist(item.barcode!);
      if (!productExists) {
        await addProductToGlobal(item.barcode!, {
          'name': item.name,
          'category': item.category,
          'brand': item.supplier ?? '',
          'description': item.description,
          'imageUrl': item.imageUrl,
        });
      }
    }
    
    var collection = _getInventoryCollection(householdId);
    var docRef = await collection.add(itemData);
    return docRef.id;
  }

  Future<void> updateItem(String householdId, InventoryItem item) async {
    _checkReadOnly();
    
    if (householdId.isEmpty || item.id == null || item.id!.isEmpty) {
      throw Exception('Invalid parameters for update');
    }
    
    final String? updatedByUserName = await _getUserDisplayName();
    
    final Map<String, dynamic> updateData = item.toMap();
    if (updatedByUserName != null) {
      updateData['updatedByUserName'] = updatedByUserName;
    }
    updateData['updatedByUserId'] = _getUserId();
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    var collection = _getInventoryCollection(householdId);
    return collection.doc(item.id).update(updateData);
  }

  Future<void> deleteItem(String householdId, String itemId) async {
    _checkReadOnly();
    
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    var collection = _getInventoryCollection(householdId);
    return collection.doc(itemId).delete();
  }

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

  Future<List<String>> getCategories(String householdId) async {
    if (householdId.isEmpty) {
      return [];
    }
    
    try {
      final snapshot = await _getInventoryCollection(householdId).get();
      
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] as String? ?? 'Uncategorized';
          })
          .toSet()
          .toList();
      
      categories.sort();
      return categories;
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

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

  Stream<QuerySnapshot> searchItems(String householdId, String query) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }
    try {
      var collection = _getInventoryCollection(householdId);
      return collection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .orderBy('name')
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

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

  Future<void> updateItemQuantity(String householdId, String itemId, int newQuantity) async {
    _checkReadOnly();
    
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    
    final String? updatedByUserName = await _getUserDisplayName();
    
    var collection = _getInventoryCollection(householdId);
    final updateData = {
      'quantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (updatedByUserName != null) {
      updateData['updatedByUserName'] = updatedByUserName;
    }
    updateData['updatedByUserId'] = _getUserId() as Object;
    
    return collection.doc(itemId).update(updateData);
  }

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
}