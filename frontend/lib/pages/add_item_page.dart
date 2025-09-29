import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'inventory_edit_page.dart';

class AddItemPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final bool isReadOnly;

  const AddItemPage({
    Key? key, 
    required this.householdId, 
    required this.householdName,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  String _scanResult = '';
  bool _isScanning = false;
  bool _isAddingToHousehold = false;
  bool _isFetchingFromAPI = false;
  final ImagePicker _picker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ FIXED CATEGORIES
  final List<String> _fixedCategories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other'
  ];

  // ✅ CATEGORY MAPPING FUNCTION
  String _mapToFixedCategory(String openFoodFactsCategory) {
    final String lowerCategory = openFoodFactsCategory.toLowerCase();

    if (lowerCategory.contains('food') || 
        lowerCategory.contains('grocery') ||
        lowerCategory.contains('snack') ||
        lowerCategory.contains('dairy') ||
        lowerCategory.contains('meat') ||
        lowerCategory.contains('fruit') ||
        lowerCategory.contains('vegetable') ||
        lowerCategory.contains('bakery') ||
        lowerCategory.contains('frozen') ||
        lowerCategory.contains('canned')) {
      return 'Food';
    }

    if (lowerCategory.contains('beverage') || 
        lowerCategory.contains('drink') ||
        lowerCategory.contains('juice') ||
        lowerCategory.contains('soda') ||
        lowerCategory.contains('water') ||
        lowerCategory.contains('coffee') ||
        lowerCategory.contains('tea') ||
        lowerCategory.contains('alcohol')) {
      return 'Beverages';
    }

    if (lowerCategory.contains('clean') || 
        lowerCategory.contains('detergent') ||
        lowerCategory.contains('soap') ||
        lowerCategory.contains('household') ||
        lowerCategory.contains('laundry') ||
        lowerCategory.contains('disinfectant') ||
        lowerCategory.contains('paper') ||
        lowerCategory.contains('trash')) {
      return 'Cleaning Supplies';
    }

    if (lowerCategory.contains('personal') || 
        lowerCategory.contains('care') ||
        lowerCategory.contains('beauty') ||
        lowerCategory.contains('cosmetic') ||
        lowerCategory.contains('hygiene') ||
        lowerCategory.contains('shampoo') ||
        lowerCategory.contains('lotion') ||
        lowerCategory.contains('deodorant') ||
        lowerCategory.contains('toiletries')) {
      return 'Personal Care';
    }

    if (lowerCategory.contains('medication') || 
        lowerCategory.contains('pharmacy') ||
        lowerCategory.contains('drug') ||
        lowerCategory.contains('health') ||
        lowerCategory.contains('vitamin') ||
        lowerCategory.contains('supplement') ||
        lowerCategory.contains('first aid')) {
      return 'Medication';
    }

    return 'Other';
  }

  // Color scheme
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);
  final Color disabledColor = Color(0xFF9E9E9E);
  final Color warningColor = Color(0xFFFF6B35);

  Future<void> _scanBarcode() async {
    if (widget.isReadOnly) return;
    
    setState(() => _isScanning = true);

    try {
      final pickedImage = await _picker.pickImage(source: ImageSource.camera);
      if (pickedImage == null) {
        setState(() => _isScanning = false);
        return;
      }

      final inputImage = InputImage.fromFile(File(pickedImage.path));
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        final barcodeValue = barcodes.first.rawValue ?? '';
        setState(() => _scanResult = barcodeValue);
        await _checkBarcodeInFirestore(barcodeValue);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No barcode found'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  // ✅ ENHANCED: Better caching with timestamp checking
  Future<void> _checkBarcodeInFirestore(String barcode) async {
    if (widget.isReadOnly) return;
    
    try {
      final productDoc = await _firestore
          .collection('products')
          .doc(barcode)
          .get();

      if (productDoc.exists) {
        final productData = productDoc.data()!;
        final Timestamp? lastUpdated = productData['lastUpdated'] as Timestamp?;
        final DateTime now = DateTime.now();
        
        // ✅ Check if cache is fresh (less than 30 days old)
        if (lastUpdated != null) {
          final DateTime updateTime = lastUpdated.toDate();
          final Duration difference = now.difference(updateTime);
          
          if (difference.inDays < 30) {
            // ✅ Use cached data (fresh)
            print('🔄 Using cached product data for barcode: $barcode');
            _showProductDetails(productData, barcode);
            return;
          } else {
            // ✅ Cache is stale, fetch fresh data
            print('🔄 Cached data is stale, fetching fresh data for: $barcode');
            await _fetchFromOpenFoodFacts(barcode);
            return;
          }
        }
        
        // ✅ No timestamp, use cached data but mark as potentially stale
        print('🔄 Using cached product data (no timestamp) for barcode: $barcode');
        _showProductDetails(productData, barcode);
      } else {
        // ✅ Product not found in Firestore, try OpenFoodFacts API
        print('🔍 Product not in cache, fetching from API: $barcode');
        await _fetchFromOpenFoodFacts(barcode);
      }
    } catch (e) {
      print('❌ Error checking product cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking product: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ✅ ENHANCED: Better API fetching with error handling
  Future<void> _fetchFromOpenFoodFacts(String barcode) async {
    if (widget.isReadOnly) return;
    
    setState(() => _isFetchingFromAPI = true);

    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
        headers: {'User-Agent': 'HouseholdInventoryApp/1.0'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 1) {
          // ✅ Product found in OpenFoodFacts
          final productData = _parseOpenFoodFactsData(data['product'], barcode);
          await _saveProductToFirestore(barcode, productData);
          _showProductDetails(productData, barcode);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Product data fetched and cached'),
              backgroundColor: secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // ✅ Product not found in OpenFoodFacts
          _showProductNotFoundDialog(barcode);
        }
      } else {
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // ✅ Network error - try to use cached data if available
      print('🌐 Network error: $e');
      await _tryUseCachedData(barcode);
    } on TimeoutException catch (e) {
      // ✅ Timeout - try to use cached data if available
      print('⏰ API timeout: $e');
      await _tryUseCachedData(barcode);
    } catch (e) {
      print('❌ Error fetching from OpenFoodFacts: $e');
      await _tryUseCachedData(barcode);
    } finally {
      setState(() => _isFetchingFromAPI = false);
    }
  }

  // ✅ NEW: Fallback to cached data when API fails
  Future<void> _tryUseCachedData(String barcode) async {
    try {
      final productDoc = await _firestore
          .collection('products')
          .doc(barcode)
          .get();

      if (productDoc.exists) {
        final productData = productDoc.data()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 Using cached data (API unavailable)'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showProductDetails(productData, barcode);
      } else {
        _showProductNotFoundDialog(barcode);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ API unavailable and no cached data found'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showProductNotFoundDialog(barcode);
    }
  }

  // ✅ UPDATED: Category mapping applied with enhanced data
  Map<String, dynamic> _parseOpenFoodFactsData(Map<String, dynamic> product, String barcode) {
    String openFoodFactsCategory = _getCategory(product['categories'] ?? 'Uncategorized');
    String mappedCategory = _mapToFixedCategory(openFoodFactsCategory);

    return {
      'name': product['product_name'] ?? 'Unknown Product',
      'brand': product['brands'] ?? 'Unknown Brand',
      'category': mappedCategory, // ✅ fixed category
      'originalCategory': openFoodFactsCategory, // keep raw for reference
      'quantity': product['quantity'] ?? 'N/A',
      'imageUrl': product['image_url'] ?? product['image_front_url'] ?? '',
      'description': product['generic_name'] ?? product['product_name'] ?? '',
      'ingredients': product['ingredients_text'] ?? '',
      'nutritionGrade': product['nutriscore_grade'] ?? '',
      'allergens': product['allergens'] ?? '',
      'countries': product['countries'] ?? '',
      'source': 'openfoodfacts',
      'barcode': barcode,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(), // ✅ Cache timestamp
      'fetchCount': FieldValue.increment(1), // ✅ Track how many times fetched
    };
  }

  String _getCategory(String categories) {
    // Take the first category if multiple are provided
    if (categories.contains(',')) {
      return categories.split(',').first.trim();
    }
    return categories.trim();
  }

  // ✅ ENHANCED: Better product saving with merge
  Future<void> _saveProductToFirestore(String barcode, Map<String, dynamic> productData) async {
    try {
      // ✅ Merge data to preserve existing fields while updating new ones
      await _firestore
          .collection('products')
          .doc(barcode)
          .set(productData, SetOptions(merge: true));
      
      print('💾 Product saved/cached to Firestore: $barcode');
      print('📦 Product data: ${productData['name']} - ${productData['category']}');
    } catch (e) {
      print('❌ Error saving product to Firestore: $e');
      throw e;
    }
  }

  void _showProductDetails(Map<String, dynamic> product, String barcode) {
    if (widget.isReadOnly) return;
    
    // ✅ Show cache indicator
    final bool isCached = product['source'] != 'openfoodfacts' || 
                         product['lastUpdated'] != null;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      image: product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(product['imageUrl'].toString()),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product['imageUrl'] == null || product['imageUrl'].isEmpty
                        ? Center(
                            child: Icon(
                              Icons.inventory_2,
                              size: 50,
                              color: lightTextColor,
                            ),
                          )
                        : null,
                  ),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name']?.toString() ?? 'Unknown Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            if (product['nutritionGrade'] != null && product['nutritionGrade'].isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getNutritionGradeColor(product['nutritionGrade']),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nutri-Score: ${product['nutritionGrade'].toUpperCase()}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            SizedBox(width: 8),
                            Text(
                              'Barcode: $barcode',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (isCached)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cached, size: 10, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'From Cache',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (product['source'] == 'openfoodfacts')
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'From OpenFoodFacts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Brand',
                      product['brand']?.toString() ?? 'Not specified',
                      Icons.business,
                    ),
                    SizedBox(height: 12),
                    _buildDetailRow(
                      'Category',
                      product['category']?.toString() ?? 'Uncategorized',
                      Icons.category,
                    ),
                    SizedBox(height: 12),
                    _buildDetailRow(
                      'Quantity',
                      product['quantity']?.toString() ?? 'N/A',
                      Icons.scale,
                    ),
                    SizedBox(height: 12),
                    if (product['description'] != null && product['description'].isNotEmpty)
                      _buildDetailRow(
                        'Description',
                        product['description'].toString(),
                        Icons.description,
                      ),
                    SizedBox(height: 12),
                    if (product['ingredients'] != null && product['ingredients'].isNotEmpty)
                      _buildDetailRow(
                        'Ingredients',
                        product['ingredients'].toString().length > 100 
                            ? '${product['ingredients'].toString().substring(0, 100)}...' 
                            : product['ingredients'].toString(),
                        Icons.eco,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isAddingToHousehold ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: primaryColor),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAddingToHousehold ? null : () {
                          _addToHousehold(product, barcode);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAddingToHousehold
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text('Add to Household'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNutritionGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'a': return Colors.green;
      case 'b': return Colors.lightGreen;
      case 'c': return Colors.yellow;
      case 'd': return Colors.orange;
      case 'e': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 60,
                  color: warningColor,
                ),
                SizedBox(height: 16),
                Text(
                  'Product Not Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This barcode was not found in our database or OpenFoodFacts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: lightTextColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Barcode: $barcode',
                  style: TextStyle(
                    fontSize: 12,
                    color: lightTextColor,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: lightTextColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToEditPageWithBarcode(barcode);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: warningColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Add Manually'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ UPDATED: Category validation before saving
  Future<void> _addToHousehold(Map<String, dynamic> product, String barcode) async {
    if (_isAddingToHousehold) return;
    
    setState(() {
      _isAddingToHousehold = true;
    });

    try {
      // Get current user ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify household exists
      final householdDoc = await _firestore
          .collection('households')
          .doc(widget.householdId)
          .get();

      if (!householdDoc.exists) {
        throw Exception('Household does not exist');
      }

      // ✅ VALIDATE CATEGORY: Ensure it's one of the fixed categories
      String finalCategory = product['category'] ?? 'Other';
      if (!_fixedCategories.contains(finalCategory)) {
        finalCategory = 'Other';
      }

      // Create inventory item with product reference
      final inventoryData = {
        'barcode': barcode,
        'productRef': _firestore.collection('products').doc(barcode),
        'name': product['name'] ?? 'Unknown Product',
        'category': finalCategory, // ✅ guaranteed safe category
        'brand': product['brand'] ?? 'Unknown Brand',
        'quantity': 1, // Default quantity
        'minStockLevel': 1,
        'location': '', // User can set this later
        'expiryDate': null,
        'purchaseDate': FieldValue.serverTimestamp(),
        'imageUrl': product['imageUrl'] ?? '',
        'description': product['description'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
        'addedByUserId': userId,
        'addedByUserName': _auth.currentUser?.displayName ?? 'Unknown User',
        'householdId': widget.householdId,
        'householdName': widget.householdName,
        'source': product['source'] ?? 'manual',
        'lastUpdated': FieldValue.serverTimestamp(),
        'originalCategory': product['originalCategory'] ?? 'Unknown', // Keep original for reference
      };

      final docRef = await _firestore
          .collection('households')
          .doc(widget.householdId)
          .collection('inventory')
          .add(inventoryData);

      // Verify the document was created
      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        throw Exception('Failed to create inventory item');
      }

      // Close the product details dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Item successfully added to ${widget.householdName}'),
          backgroundColor: secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
        ),
      );

      print('✅ Item added successfully with ID: ${docRef.id}');
      print('📊 Inventory data: $inventoryData');

    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = '❌ Permission denied. Check Firestore security rules.';
          break;
        case 'not-found':
          errorMessage = '❌ Household document not found.';
          break;
        case 'unavailable':
          errorMessage = '❌ Network unavailable. Please check your connection.';
          break;
        default:
          errorMessage = '❌ Firestore error: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 5),
        ),
      );
      print('🔥 Firestore Error: ${e.code} - ${e.message}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Unexpected error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 5),
        ),
      );
      print('💥 Unexpected Error: $e');
    } finally {
      setState(() {
        _isAddingToHousehold = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: primaryColor,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: lightTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToEditPage() {
    if (widget.isReadOnly) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryEditPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          userRole: 'creator',
          barcode: null,
        ),
      ),
    );
  }

  void _navigateToEditPageWithBarcode(String barcode) {
    if (widget.isReadOnly) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryEditPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          userRole: 'creator',
          barcode: barcode,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          widget.isReadOnly ? 'View Item Options' : 'Add Item',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5
          ),
        ),
        backgroundColor: widget.isReadOnly ? disabledColor : primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isReadOnly 
                    ? [disabledColor, Color(0xFFBDBDBD)] 
                    : [primaryColor, Color(0xFF5A8BA8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isReadOnly ? disabledColor : primaryColor).withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isReadOnly ? Icons.visibility : Icons.add, 
                      color: Colors.white, 
                      size: 28
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isReadOnly ? 'View Item Options' : 'Add New Item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.isReadOnly 
                            ? 'View item addition options (read-only)' 
                            : 'Scan barcode or add manually to your database',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        if (!widget.isReadOnly) SizedBox(height: 4),
                        if (!widget.isReadOnly)
                          Text(
                            'Products are cached for faster future lookups',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            Expanded(
              child: Column(
                children: [
                  _buildOptionCard(
                    title: 'Scan Barcode',
                    icon: Icons.qr_code_scanner,
                    description: widget.isReadOnly 
                      ? 'Scan product barcode (read-only)' 
                      : '    Scan barcode to fetch product details      ',
                    onTap: widget.isReadOnly ? null : _scanBarcode,
                    isLoading: _isScanning || _isFetchingFromAPI,
                    isReadOnly: widget.isReadOnly,
                    showApiStatus: _isFetchingFromAPI,
                  ),
                  SizedBox(height: 20),
                  _buildOptionCard(
                    title: 'Add Manually',
                    icon: Icons.edit,
                    description: widget.isReadOnly 
                      ? 'View manual entry options (read-only)' 
                      : 'Add new product to your database manually',
                    onTap: widget.isReadOnly ? null : _navigateToEditPage,
                    isReadOnly: widget.isReadOnly,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isReadOnly = false,
    bool showApiStatus = false,
  }) {
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 200),
        tween: Tween(begin: 1.0, end: onTap == null ? 0.95 : 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isReadOnly ? Colors.grey[100] : cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: (isReadOnly ? disabledColor : primaryColor).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isReadOnly ? disabledColor : primaryColor
                            ),
                            strokeWidth: 3,
                          ),
                          Icon(
                            icon,
                            size: 24,
                            color: (isReadOnly ? disabledColor : primaryColor).withOpacity(0.7),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: (isReadOnly ? disabledColor : primaryColor).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon, 
                        size: 30, 
                        color: isReadOnly ? disabledColor : primaryColor
                      ),
                    ),
                  SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isReadOnly ? disabledColor : textColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, 
                      color: isReadOnly ? disabledColor : lightTextColor,
                    ),
                  ),
                  if (showApiStatus) SizedBox(height: 12),
                  if (showApiStatus)
                    Text(
                      'Fetching from OpenFoodFacts...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (isLoading && !showApiStatus) SizedBox(height: 12),
                  if (isLoading && !showApiStatus)
                    Text(
                      'Scanning...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isReadOnly ? disabledColor : primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (isReadOnly) SizedBox(height: 12),
                  if (isReadOnly)
                    Text(
                      'Read-only access',
                      style: TextStyle(
                        fontSize: 12,
                        color: disabledColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}