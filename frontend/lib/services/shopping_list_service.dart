import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShoppingListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🛒 ADD ITEM TO SHOPPING LIST (ULTRA-SAFE - NO ICONDATA)
  Future<Map<String, dynamic>> addToShoppingList(
    String householdId,
    String itemName,
    int quantity,
    String itemId, {
    String category = 'general',
    double estimatedPrice = 0.0,
    String priority = 'medium',
    Map<String, dynamic>? recommendationData,
  }) async {
    try {
      print('🛒 === STARTING addToShoppingList ===');
      print('📦 Input Parameters:');
      print('   - householdId: $householdId');
      print('   - itemName: $itemName');
      print('   - quantity: $quantity');
      print('   - itemId: $itemId');
      print('   - category: $category');
      print('   - estimatedPrice: $estimatedPrice');
      print('   - priority: $priority');

      // 🚨 ULTRA-SAFE: Completely remove any non-serializable data
      final safeRecommendationData = _removeAllNonSerializableData(recommendationData);
      print('✅ Safe recommendationData: $safeRecommendationData');

      // Validate inputs
      if (householdId.isEmpty) {
        throw Exception('Household ID cannot be empty');
      }
      if (itemName.isEmpty) {
        throw Exception('Item name cannot be empty');
      }
      if (quantity <= 0) {
        throw Exception('Quantity must be greater than 0');
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to add items to shopping list');
      }
      print('👤 User authenticated: ${user.uid}');

      // Check if household exists
      print('🏠 Checking household existence...');
      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      if (!householdDoc.exists) {
        print('❌ Household document does not exist!');
        throw Exception('Household does not exist. Please create a household first.');
      }
      print('✅ Household exists: ${householdDoc.data()}');

      // Generate a unique document ID
      final String documentId = itemId.startsWith('custom_') || itemId.isEmpty 
          ? 'shopping_${DateTime.now().millisecondsSinceEpoch}_${user.uid}'
          : itemId;

      print('📝 Generated document ID: $documentId');

      // 🚨 ULTRA-SAFE: Create data with ONLY Firestore-safe types
      final shoppingItem = {
        'itemId': documentId,
        'itemName': itemName.trim(),
        'quantity': quantity,
        'category': category,
        'estimatedPrice': estimatedPrice,
        'priority': priority,
        'completed': false,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'householdId': householdId,
        // 🚨 Only include if it exists and is safe
        if (safeRecommendationData.isNotEmpty) 'recommendationData': safeRecommendationData,
      };

      print('💾 Writing to Firestore...');
      print('   Collection: households/$householdId/shopping_list');
      print('   Document: $documentId');
      print('   Data: $shoppingItem');

      // Add to shopping list subcollection
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(documentId)
          .set(shoppingItem, SetOptions(merge: true));

      print('✅ Successfully wrote to Firestore!');

      // Verify the write
      print('🔍 Verifying write operation...');
      final verifyDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(documentId)
          .get();

      if (verifyDoc.exists) {
        print('✅ Verification PASSED - Document exists in Firestore');
        print('📊 Document data: ${verifyDoc.data()}');
        
        return {
          'success': true,
          'message': 'Added $itemName to shopping list',
          'documentId': documentId,
          'item': shoppingItem,
        };
      } else {
        print('❌ Verification FAILED - Document does not exist after write!');
        return {
          'success': false,
          'error': 'Document not found after write operation',
          'message': 'Failed to verify item was added',
        };
      }
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in addToShoppingList:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to add item to shopping list: ${e.toString()}',
      };
    }
  }

  /// 🚨 ULTRA-SAFE: Remove ALL non-serializable data including IconData
  Map<String, dynamic> _removeAllNonSerializableData(Map<String, dynamic>? data) {
    if (data == null) return {};
    
    final safeData = <String, dynamic>{};
    
    data.forEach((key, value) {
      // Skip entirely if value is IconData or any other non-serializable type
      if (_isFirestoreSafe(value)) {
        safeData[key] = value;
      } else {
        print('🚨 REMOVED non-serializable data: $key = $value (${value.runtimeType})');
        // 🚨 COMPLETELY IGNORE - don't add to safeData
      }
    });
    
    return safeData;
  }

  /// 🚨 ULTRA-SAFE: Check if value is Firestore-safe
  bool _isFirestoreSafe(dynamic value) {
    // Firestore can only handle these basic types
    return value == null ||
        value is String ||
        value is int ||
        value is double ||
        value is bool ||
        value is Timestamp ||
        value is DateTime ||
        value is FieldValue ||
        _isSafeList(value) ||
        _isSafeMap(value);
  }

  bool _isSafeList(dynamic value) {
    if (value is! List) return false;
    
    // Check if all elements in the list are safe
    for (final element in value) {
      if (!_isFirestoreSafe(element)) return false;
    }
    return true;
  }

  bool _isSafeMap(dynamic value) {
    if (value is! Map) return false;
    
    // Check if all keys and values are safe
    for (final entry in value.entries) {
      if (!_isFirestoreSafe(entry.key) || !_isFirestoreSafe(entry.value)) {
        return false;
      }
    }
    return true;
  }

  /// 🛒 GET SHOPPING LIST ITEMS
  Future<List<Map<String, dynamic>>> getShoppingList(String householdId) async {
    try {
      print('📋 Getting shopping list for household: $householdId');
      
      if (householdId.isEmpty) {
        throw Exception('Household ID cannot be empty');
      }

      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .orderBy('createdAt', descending: true)
          .get();

      print('📋 Found ${querySnapshot.docs.length} items in shopping list');

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          'updatedAt': data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
        };
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error getting shopping list: $e');
      print('   Stack trace: $stackTrace');
      throw Exception('Failed to load shopping list: ${e.toString()}');
    }
  }

  /// 🛒 GET SHOPPING LIST COUNT
  Future<int> getShoppingListCount(String householdId) async {
    try {
      if (householdId.isEmpty) return 0;

      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .where('completed', isEqualTo: false)
          .get();

      return querySnapshot.size;
    } catch (e) {
      print('❌ Error getting shopping list count: $e');
      return 0;
    }
  }

  /// 🛒 UPDATE SHOPPING LIST ITEM QUANTITY
  Future<Map<String, dynamic>> updateItemQuantity(
    String householdId,
    String itemId,
    int newQuantity,
  ) async {
    try {
      if (householdId.isEmpty || itemId.isEmpty) {
        throw Exception('Household ID and Item ID cannot be empty');
      }

      if (newQuantity <= 0) {
        // If quantity is 0 or negative, remove the item
        return await removeFromShoppingList(householdId, itemId);
      }

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Quantity updated successfully',
      };
    } catch (e) {
      print('❌ Error updating shopping list quantity: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🛒 REMOVE ITEM FROM SHOPPING LIST
  Future<Map<String, dynamic>> removeFromShoppingList(
    String householdId,
    String itemId,
  ) async {
    try {
      if (householdId.isEmpty || itemId.isEmpty) {
        throw Exception('Household ID and Item ID cannot be empty');
      }

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .delete();

      return {
        'success': true,
        'message': 'Item removed from shopping list',
      };
    } catch (e) {
      print('❌ Error removing item from shopping list: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🛒 TOGGLE ITEM COMPLETION STATUS
  Future<Map<String, dynamic>> toggleItemStatus(
    String householdId,
    String itemId,
    bool completed,
  ) async {
    try {
      print('🔄 Toggling item status: $itemId to $completed');
      
      if (householdId.isEmpty || itemId.isEmpty) {
        throw Exception('Household ID and Item ID cannot be empty');
      }

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .update({
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
      });

      print('✅ Successfully toggled item status');

      return {
        'success': true,
        'message': 'Item status updated',
      };
    } catch (e) {
      print('❌ Error toggling shopping list item status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🛒 MARK ITEM AS PURCHASED (SPECIAL METHOD)
  Future<Map<String, dynamic>> markItemAsPurchased(
    String householdId,
    String itemId,
  ) async {
    try {
      print('🛍️ Marking item as purchased: $itemId');
      
      if (householdId.isEmpty || itemId.isEmpty) {
        throw Exception('Household ID and Item ID cannot be empty');
      }

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .update({
        'completed': true,
        'purchasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully marked item as purchased');

      return {
        'success': true,
        'message': 'Item marked as purchased',
      };
    } catch (e) {
      print('❌ Error marking item as purchased: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🛒 CLEAR COMPLETED ITEMS
  Future<Map<String, dynamic>> clearCompletedItems(String householdId) async {
    try {
      if (householdId.isEmpty) {
        throw Exception('Household ID cannot be empty');
      }

      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .where('completed', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Cleared ${querySnapshot.size} completed items',
        'clearedCount': querySnapshot.size,
      };
    } catch (e) {
      print('❌ Error clearing completed shopping list items: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🛒 GET SHOPPING LIST STATISTICS
  Future<Map<String, dynamic>> getShoppingListStats(String householdId) async {
    try {
      if (householdId.isEmpty) {
        throw Exception('Household ID cannot be empty');
      }

      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .get();

      int totalItems = querySnapshot.size;
      int completedItems = 0;
      int urgentItems = 0;
      double totalEstimatedCost = 0.0;
      final Map<String, int> categoryCount = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final completed = data['completed'] ?? false;
        final priority = data['priority'] ?? 'medium';
        final estimatedPrice = (data['estimatedPrice'] ?? 0.0).toDouble();
        final category = data['category'] ?? 'general';
        final quantity = (data['quantity'] ?? 1) as int;

        if (completed) completedItems++;

        if (priority == 'emergency' || priority == 'critical' || priority == 'high') {
          urgentItems++;
        }

        totalEstimatedCost += estimatedPrice * quantity;

        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      final int pendingItems = totalItems - completedItems;

      return {
        'success': true,
        'totalItems': totalItems,
        'completedItems': completedItems,
        'pendingItems': pendingItems,
        'urgentItems': urgentItems,
        'totalEstimatedCost': totalEstimatedCost,
        'completionRate': totalItems > 0 ? (completedItems / totalItems) * 100 : 0,
        'categoryDistribution': categoryCount,
        'summary': _generateStatsSummary(
          totalItems,
          completedItems,
          urgentItems,
          totalEstimatedCost,
        ),
      };
    } catch (e) {
      print('❌ Error getting shopping list stats: $e');
      return {
        'success': false,
        'error': e.toString(),
        'totalItems': 0,
        'completedItems': 0,
        'pendingItems': 0,
        'urgentItems': 0,
        'totalEstimatedCost': 0.0,
      };
    }
  }

  /// 🛒 BULK ADD ITEMS TO SHOPPING LIST
  Future<Map<String, dynamic>> bulkAddToShoppingList(
    String householdId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      if (householdId.isEmpty) {
        throw Exception('Household ID cannot be empty');
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in');
      }

      final batch = _firestore.batch();
      final List<String> addedItems = [];

      for (final item in items) {
        final String documentId = item['itemId']?.toString().startsWith('custom_') ?? false
            ? item['itemId'].toString()
            : 'shopping_${DateTime.now().millisecondsSinceEpoch}_${user.uid}_${addedItems.length}';

        // 🚨 ULTRA-SAFE: Remove non-serializable data
        final safeRecommendationData = _removeAllNonSerializableData(
          item['recommendationData'] is Map<String, dynamic> ? item['recommendationData'] : null
        );

        final shoppingItem = {
          'itemId': documentId,
          'itemName': item['itemName']?.toString().trim() ?? 'Unknown Item',
          'quantity': item['quantity'] ?? 1,
          'category': item['category'] ?? 'general',
          'estimatedPrice': (item['estimatedPrice'] ?? 0.0).toDouble(),
          'priority': item['priority'] ?? 'medium',
          'completed': false,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'householdId': householdId,
          // 🚨 Only include if safe and not empty
          if (safeRecommendationData.isNotEmpty) 'recommendationData': safeRecommendationData,
        };

        final docRef = _firestore
            .collection('households')
            .doc(householdId)
            .collection('shopping_list')
            .doc(documentId);

        batch.set(docRef, shoppingItem, SetOptions(merge: true));
        addedItems.add(item['itemName']?.toString() ?? 'Unknown Item');
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Added ${addedItems.length} items to shopping list',
        'addedCount': addedItems.length,
        'addedItems': addedItems,
      };
    } catch (e) {
      print('❌ Error in bulk add to shopping list: $e');
      return {
        'success': false,
        'error': e.toString(),
        'addedCount': 0,
        'addedItems': [],
      };
    }
  }

  /// 🛒 SEARCH SHOPPING LIST ITEMS
  Future<List<Map<String, dynamic>>> searchShoppingList(
    String householdId,
    String query,
  ) async {
    try {
      if (householdId.isEmpty || query.isEmpty) {
        return await getShoppingList(householdId);
      }

      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .orderBy('itemName')
          .get();

      final lowerQuery = query.toLowerCase();
      return querySnapshot.docs
          .where((doc) {
            final data = doc.data();
            final itemName = (data['itemName'] ?? '').toString().toLowerCase();
            final category = (data['category'] ?? '').toString().toLowerCase();
            return itemName.contains(lowerQuery) || category.contains(lowerQuery);
          })
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
              'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
              'updatedAt': data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
            };
          })
          .toList();
    } catch (e) {
      print('❌ Error searching shopping list: $e');
      return [];
    }
  }

  // Helper method to generate stats summary
  String _generateStatsSummary(
    int totalItems,
    int completedItems,
    int urgentItems,
    double totalCost,
  ) {
    if (totalItems == 0) {
      return 'No items in shopping list';
    }

    final pending = totalItems - completedItems;
    final List<String> parts = [];

    if (pending > 0) {
      parts.add('$pending items pending');
    }

    if (completedItems > 0) {
      parts.add('$completedItems completed');
    }

    if (urgentItems > 0) {
      parts.add('$urgentItems urgent');
    }

    if (totalCost > 0) {
      parts.add('Total: RM${totalCost.toStringAsFixed(2)}');
    }

    return parts.join(' • ');
  }

  /// 🛒 DEBUG: Check data for IconData before calling service
  static void debugDataForIconData(Map<String, dynamic>? data, {String context = ''}) {
    if (data == null) {
      print('🔍 DEBUG: Data is null $context');
      return;
    }
    
    print('🔍 DEBUG: Checking for IconData $context');
    bool foundIconData = false;
    
    void checkValue(dynamic value, String path) {
      if (value == null) return;
      
      if (value is IconData) {
        print('❌ FOUND ICONDATA at $path: $value');
        foundIconData = true;
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          checkValue(value[i], '$path[$i]');
        }
      } else if (value is Map) {
        value.forEach((key, val) {
          checkValue(val, '$path.$key');
        });
      }
    }
    
    data.forEach((key, value) {
      checkValue(value, key);
    });
    
    if (foundIconData) {
      print('🚨 ACTION REQUIRED: Remove ALL IconData before calling ShoppingListService!');
    } else {
      print('✅ No IconData found - safe for Firestore');
    }
  }

  Future getShoppingListItems(String householdId) async {}
}