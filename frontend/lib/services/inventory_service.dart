import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/pages/dashboard_page.dart';
import '../models/inventory_audit_log.dart';
import '../models/inventory_item_model.dart' show InventoryItem;

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DashboardService _dashboardService = DashboardService();
  
  bool _isReadOnly = false;
  
  static Future<void> enableOfflineSync() async {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
  
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

  // Enhanced method to get user display name with full name support
  Future<Map<String, String>> _getUserDisplayInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'userName': 'Unknown', 'fullName': 'Unknown User'};
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final userName = data?['userName'] as String? ?? user.displayName ?? user.email?.split('@').first ?? 'Unknown';
        final fullName = data?['fullName'] as String? ?? data?['displayName'] as String? ?? userName;
        
        return {
          'userName': userName,
          'fullName': fullName,
        };
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    
    // Fallback to Firebase Auth display name
    final fallbackName = user.displayName ?? user.email?.split('@').first ?? 'Unknown';
    return {
      'userName': fallbackName,
      'fullName': fallbackName,
    };
  }

  // ========== AUDIT LOGGING METHODS ==========
  
  Future<void> _logInventoryChange(
    String householdId,
    String itemId,
    String fieldName,
    dynamic oldValue,
    dynamic newValue,
    String updatedByUserName,
    String updatedByFullName, // Add fullName parameter
  ) async {
    final userId = _getUserId();
    if (userId == null) {
      print("Error: User ID is null");
      return;
    }

    // Fetch item details for the audit log
    String itemName = 'Unknown Item';
    String itemImageUrl = '';
    
    try {
      final itemDoc = await _getInventoryCollection(householdId).doc(itemId).get();
      if (itemDoc.exists) {
        final itemData = itemDoc.data() as Map<String, dynamic>?;
        itemName = itemData?['name'] ?? 'Unknown Item';
        itemImageUrl = itemData?['imageUrl'] ?? '';
      }
    } catch (e) {
      print('Error fetching item details for audit log: $e');
    }

    final auditLog = InventoryAuditLog(
      itemId: itemId,
      itemName: itemName,
      itemImageUrl: itemImageUrl,
      fieldName: fieldName,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      updatedByUserId: userId,
      updatedByUserName: updatedByUserName,
      updatedByFullName: updatedByFullName, // Include full name
    );

    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory_audit_logs')
          .add(auditLog.toMap());
      print('Inventory change logged successfully');
    } catch (e) {
      print('Error logging inventory change: $e');
    }
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
        // Ensure localImagePath is included if provided
        'localImagePath': productData['localImagePath'] ?? '',
      });
    } catch (e) {
      print('Error adding product to global collection: $e');
      throw Exception('Failed to add product to database');
    }
  }

  // NEW: Method to update local image path for a product
  Future<void> updateProductLocalImage(String barcode, String localImagePath) async {
    _checkReadOnly();
    
    try {
      await _firestore.collection('products').doc(barcode).update({
        'localImagePath': localImagePath,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _getUserId(),
      });
    } catch (e) {
      print('Error updating product local image: $e');
      throw Exception('Failed to update product image');
    }
  }

  // NEW: Method to get products with local images
  Future<List<Map<String, dynamic>>> getProductsWithLocalImages(String householdId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('localImagePath', isNotEqualTo: '')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting products with local images: $e');
      return [];
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
    
    final userInfo = await _getUserDisplayInfo();
    final addedByUserName = userInfo['userName']!;
    final addedByFullName = userInfo['fullName']!;
    
    final Map<String, dynamic> itemData = item.toMap();
    itemData['addedByUserName'] = addedByUserName;
    itemData['addedByFullName'] = addedByFullName; // Store full name
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
          'localImagePath': item.localImagePath ?? '', // Include local image path
        });
      } else if (item.localImagePath != null && item.localImagePath!.isNotEmpty) {
        // Update existing product with local image path
        await updateProductLocalImage(item.barcode!, item.localImagePath!);
      }
    }
    
    var collection = _getInventoryCollection(householdId);
    var docRef = await collection.add(itemData);
    
    // Log the addition to activities
    await _dashboardService.logActivity(
      householdId,
      '$addedByFullName added ${item.name} to inventory',
      'add',
      userId: _getUserId(),
      userName: addedByUserName,
      fullName: addedByFullName, // Include full name
    );
    
    // Log the addition to audit logs
    await _logInventoryChange(
      householdId,
      docRef.id,
      'created',
      null,
      item.name,
      addedByUserName,
      addedByFullName, // Include full name
    );
    
    return docRef.id;
  }

  Future<String> addItemWithErrorHandling(
    String householdId, 
    InventoryItem item,
    BuildContext context,
  ) async {
    try {
      final id = await addItem(householdId, item);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      return id;
    } catch (e) {
      print('Error adding item: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add ${item.name}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> updateItem(String householdId, InventoryItem item) async {
    _checkReadOnly();
    
    if (householdId.isEmpty || item.id == null || item.id!.isEmpty) {
      throw Exception('Invalid parameters for update');
    }

    // Fetch existing item before updating
    var docRef = _getInventoryCollection(householdId).doc(item.id);
    final existingItem = await docRef.get();
    
    if (existingItem.exists) {
      final Map<String, dynamic> existingData = existingItem.data() as Map<String, dynamic>;

      // Get user display info for audit logging
      final userInfo = await _getUserDisplayInfo();
      final updatedByUserName = userInfo['userName']!;
      final updatedByFullName = userInfo['fullName']!;

      // Prepare updated data
      final Map<String, dynamic> updateData = item.toMap();
      updateData['updatedByUserId'] = _getUserId();
      updateData['updatedByUserName'] = updatedByUserName;
      updateData['updatedByFullName'] = updatedByFullName; // Store full name
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      // If item has a barcode and local image, update the global product
      if (item.barcode != null && item.barcode!.isNotEmpty && 
          item.localImagePath != null && item.localImagePath!.isNotEmpty) {
        await updateProductLocalImage(item.barcode!, item.localImagePath!);
      }

      // Log activity for the update
      await _dashboardService.logActivity(
        householdId,
        '$updatedByFullName updated ${item.name}',
        'update',
        userId: _getUserId(),
        userName: updatedByUserName,
        fullName: updatedByFullName, // Include full name
      );

      // If there are any changes, log them to audit logs
      for (var field in updateData.keys) {
        if (field != 'updatedByUserId' && field != 'updatedByUserName' && 
            field != 'updatedByFullName' && field != 'updatedAt' && 
            existingData[field] != updateData[field]) {
          await _logInventoryChange(
            householdId,
            item.id!,
            field,
            existingData[field], // old value
            updateData[field],    // new value
            updatedByUserName,
            updatedByFullName, // Include full name
          );
        }
      }

      // Finally, update the item in the Firestore collection
      await docRef.update(updateData);
    }
  }

  Future<void> updateItemWithErrorHandling(
    String householdId, 
    InventoryItem item,
    BuildContext context,
  ) async {
    try {
      await updateItem(householdId, item);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating item: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update ${item.name}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> deleteItem(String householdId, String itemId) async {
    _checkReadOnly();
    
    if (householdId.isEmpty || itemId.isEmpty) {
      throw Exception('Household ID or Item ID cannot be empty');
    }
    
    // Fetch item details before deletion for logging
    String itemName = 'Unknown Item';
    try {
      final itemDoc = await _getInventoryCollection(householdId).doc(itemId).get();
      if (itemDoc.exists) {
        final itemData = itemDoc.data() as Map<String, dynamic>?;
        itemName = itemData?['name'] ?? 'Unknown Item';
      }
    } catch (e) {
      print('Error fetching item details for deletion log: $e');
    }
    
    // Get user display info
    final userInfo = await _getUserDisplayInfo();
    final updatedByUserName = userInfo['userName']!;
    final updatedByFullName = userInfo['fullName']!;
    
    // Log the deletion to activities
    await _dashboardService.logActivity(
      householdId,
      '$updatedByFullName deleted $itemName from inventory',
      'delete',
      userId: _getUserId(),
      userName: updatedByUserName,
      fullName: updatedByFullName, // Include full name
    );
    
    // Log the deletion to audit logs
    await _logInventoryChange(
      householdId,
      itemId,
      'deleted',
      itemName, // old value - item existed
      null,     // new value - item deleted
      updatedByUserName,
      updatedByFullName, // Include full name
    );
    
    var collection = _getInventoryCollection(householdId);
    return collection.doc(itemId).delete();
  }

  Future<void> deleteItemWithErrorHandling(
    String householdId, 
    String itemId,
    BuildContext context,
  ) async {
    try {
      await deleteItem(householdId, itemId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting item: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  // ========== AUDIT LOG QUERY METHODS ==========
  
  Stream<QuerySnapshot> getAuditLogs(String householdId, String itemId) {
    if (householdId.isEmpty || itemId.isEmpty) {
      return Stream.error(Exception('Household ID or Item ID cannot be empty'));
    }

    try {
      var collection = _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory_audit_logs')
          .where('itemId', isEqualTo: itemId)
          .orderBy('timestamp', descending: true);

      return collection.snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  Stream<QuerySnapshot> getAllAuditLogs(String householdId, {int limit = 50}) {
    if (householdId.isEmpty) {
      return Stream.error(Exception('Household ID cannot be empty'));
    }

    try {
      var collection = _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory_audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      return collection.snapshots();
    } catch (e) {
      return Stream.error(e);
    }
  }

  // ========== EXISTING METHODS (UPDATED FOR FULL NAME SUPPORT) ==========
  
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

  // Get AI suggestions for low stock items
  Future<List<InventoryItem>> getAISuggestions(String householdId) async {
    try {
      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .where('quantity', isLessThan: 3)
          .get();

      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('Error getting AI suggestions: $e');
      return [];
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
    
    // Fetch existing item to get old quantity and name
    var docRef = _getInventoryCollection(householdId).doc(itemId);
    final existingItem = await docRef.get();
    
    if (existingItem.exists) {
      final existingData = existingItem.data() as Map<String, dynamic>;
      final oldQuantity = existingData['quantity'] ?? 0;
      final itemName = existingData['name'] ?? 'Unknown Item';
      
      // Get user display info
      final userInfo = await _getUserDisplayInfo();
      final updatedByUserName = userInfo['userName']!;
      final updatedByFullName = userInfo['fullName']!;
      
      // Log low stock warning if applicable
      if (newQuantity < 5 && oldQuantity >= 5) {
        await _dashboardService.logActivity(
          householdId,
          '$itemName is running low (${newQuantity} left)',
          'warning',
          userId: _getUserId(),
          userName: updatedByUserName,
          fullName: updatedByFullName, // Include full name
        );
      }
      
      var collection = _getInventoryCollection(householdId);
      final updateData = {
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUserId': _getUserId(),
        'updatedByUserName': updatedByUserName,
        'updatedByFullName': updatedByFullName, // Store full name
      };
      
      // Log the quantity change to activities
      if (oldQuantity != newQuantity) {
        await _dashboardService.logActivity(
          householdId,
          '$updatedByFullName updated $itemName quantity from $oldQuantity to $newQuantity',
          'update',
          userId: _getUserId(),
          userName: updatedByUserName,
          fullName: updatedByFullName, // Include full name
        );
        
        // Log to audit logs
        await _logInventoryChange(
          householdId,
          itemId,
          'quantity',
          oldQuantity,
          newQuantity,
          updatedByUserName,
          updatedByFullName, // Include full name
        );
      }
      
      return collection.doc(itemId).update(updateData);
    }
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

  // NEW: Method to get inventory items with local images
  Future<List<InventoryItem>> getItemsWithLocalImages(String householdId) async {
    try {
      final snapshot = await _getInventoryCollection(householdId)
          .where('localImagePath', isNotEqualTo: '')
          .get();

      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting items with local images: $e');
      return [];
    }
  }

  // NEW: Method to update local image path for an inventory item
  Future<void> updateItemLocalImage(String householdId, String itemId, String localImagePath) async {
    _checkReadOnly();
    
    try {
      await _getInventoryCollection(householdId).doc(itemId).update({
        'localImagePath': localImagePath,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUserId': _getUserId(),
      });
    } catch (e) {
      print('Error updating item local image: $e');
      throw Exception('Failed to update item image');
    }
  }
}