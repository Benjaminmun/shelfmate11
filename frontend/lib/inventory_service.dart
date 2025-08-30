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

  // Get reference to the inventory collection for a household
  CollectionReference _getInventoryCollection(String householdId) {
    String? userId = _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('households')
        .doc(householdId)
        .collection('inventory');
  }

  // Create a new inventory item
  Future<void> addItem(String householdId, InventoryItem item) {
    var collection = _getInventoryCollection(householdId);
    return collection.add(item.toMap());
  }

  // Update an existing inventory item
  Future<void> updateItem(String householdId, InventoryItem item) {
    var collection = _getInventoryCollection(householdId);
    return collection.doc(item.id).update(item.toMap());
  }

  // Delete an inventory item
  Future<void> deleteItem(String householdId, String itemId) {
    var collection = _getInventoryCollection(householdId);
    return collection.doc(itemId).delete();
  }

  // Get a stream of inventory items for a household
  Stream<QuerySnapshot> getItemsStream(String householdId) {
    var collection = _getInventoryCollection(householdId);
    return collection.orderBy('name').snapshots();
  }

  // Get a single inventory item
  Future<InventoryItem> getItem(String householdId, String itemId) async {
    var collection = _getInventoryCollection(householdId);
    var doc = await collection.doc(itemId).get();
    return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}