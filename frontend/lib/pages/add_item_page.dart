import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'inventory_edit_page.dart';

// =============================================
// MODEL CLASSES
// =============================================

class Product {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String originalCategory;
  final String quantity;
  final String imageUrl;
  final String description;
  final String ingredients;
  final String nutritionGrade;
  final String allergens;
  final String countries;
  final String source;
  final DateTime? lastUpdated;
  final int fetchCount;

  Product({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.originalCategory,
    required this.quantity,
    required this.imageUrl,
    required this.description,
    required this.ingredients,
    required this.nutritionGrade,
    required this.allergens,
    required this.countries,
    required this.source,
    this.lastUpdated,
    this.fetchCount = 0,
  });

  factory Product.fromMap(Map<String, dynamic> data, String barcode) {
    return Product(
      barcode: barcode,
      name: data['name']?.toString() ?? 'Unknown Product',
      brand: data['brand']?.toString() ?? 'Unknown Brand',
      category: data['category']?.toString() ?? 'Other',
      originalCategory: data['originalCategory']?.toString() ?? 'Unknown',
      quantity: data['quantity']?.toString() ?? 'N/A',
      imageUrl: data['imageUrl']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      ingredients: data['ingredients']?.toString() ?? '',
      nutritionGrade: data['nutritionGrade']?.toString() ?? '',
      allergens: data['allergens']?.toString() ?? '',
      countries: data['countries']?.toString() ?? '',
      source: data['source']?.toString() ?? 'manual',
      fetchCount: (data['fetchCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'category': category,
      'originalCategory': originalCategory,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'description': description,
      'ingredients': ingredients,
      'nutritionGrade': nutritionGrade,
      'allergens': allergens,
      'countries': countries,
      'source': source,
      'barcode': barcode,
      'lastUpdated': lastUpdated,
      'fetchCount': fetchCount,
    };
  }
}

// =============================================
// SERVICE CLASSES
// =============================================

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _cacheDuration = Duration(days: 30);
  static const List<String> _fixedCategories = [
    'Food', 'Beverages', 'Cleaning Supplies', 'Personal Care', 'Medication', 'Other'
  ];

  String mapToFixedCategory(String openFoodFactsCategory) {
    final String lowerCategory = openFoodFactsCategory.toLowerCase();

    if (lowerCategory.contains('food') || 
        lowerCategory.contains('grocery') || lowerCategory.contains('snack') ||
        lowerCategory.contains('dairy') || lowerCategory.contains('meat') ||
        lowerCategory.contains('fruit') || lowerCategory.contains('vegetable') ||
        lowerCategory.contains('bakery') || lowerCategory.contains('frozen') ||
        lowerCategory.contains('canned')) {
      return 'Food';
    }

    if (lowerCategory.contains('beverage') || lowerCategory.contains('drink') ||
        lowerCategory.contains('juice') || lowerCategory.contains('soda') ||
        lowerCategory.contains('water') || lowerCategory.contains('coffee') ||
        lowerCategory.contains('tea') || lowerCategory.contains('alcohol')) {
      return 'Beverages';
    }

    if (lowerCategory.contains('clean') || lowerCategory.contains('detergent') ||
        lowerCategory.contains('soap') || lowerCategory.contains('household') ||
        lowerCategory.contains('laundry') || lowerCategory.contains('disinfectant') ||
        lowerCategory.contains('paper') || lowerCategory.contains('trash')) {
      return 'Cleaning Supplies';
    }

    if (lowerCategory.contains('personal') || lowerCategory.contains('care') ||
        lowerCategory.contains('beauty') || lowerCategory.contains('cosmetic') ||
        lowerCategory.contains('hygiene') || lowerCategory.contains('shampoo') ||
        lowerCategory.contains('lotion') || lowerCategory.contains('deodorant') ||
        lowerCategory.contains('toiletries')) {
      return 'Personal Care';
    }

    if (lowerCategory.contains('medication') || lowerCategory.contains('pharmacy') ||
        lowerCategory.contains('drug') || lowerCategory.contains('health') ||
        lowerCategory.contains('vitamin') || lowerCategory.contains('supplement') ||
        lowerCategory.contains('first aid')) {
      return 'Medication';
    }

    return 'Other';
  }

  Future<Product?> getCachedProduct(String barcode) async {
    try {
      final productDoc = await _firestore.collection('products').doc(barcode).get();
      
      if (productDoc.exists) {
        final productData = productDoc.data()!;
        final dynamic lastUpdatedData = productData['lastUpdated'];
        
        DateTime? lastUpdated;
        if (lastUpdatedData is Timestamp) {
          lastUpdated = lastUpdatedData.toDate();
        } else if (lastUpdatedData is DateTime) {
          lastUpdated = lastUpdatedData;
        }
        
        if (lastUpdated != null) {
          final DateTime now = DateTime.now();
          final Duration difference = now.difference(lastUpdated);
          
          if (difference < _cacheDuration) {
            return Product.fromMap(productData, barcode);
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error checking product cache: $e');
      return null;
    }
  }

  Future<Product?> fetchProductFromAPI(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
        headers: {'User-Agent': 'HouseholdInventoryApp/1.0'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 1) {
          return _parseOpenFoodFactsData(data['product'], barcode);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error fetching from OpenFoodFacts: $e');
      return null;
    }
  }

  Product _parseOpenFoodFactsData(Map<String, dynamic> product, String barcode) {
    final String rawCategory = _getCategory(product['categories'] ?? 'Uncategorized');
    final String mappedCategory = mapToFixedCategory(rawCategory);

    return Product(
      barcode: barcode,
      name: product['product_name'] ?? 'Unknown Product',
      brand: product['brands'] ?? 'Unknown Brand',
      category: mappedCategory,
      originalCategory: rawCategory,
      quantity: product['quantity'] ?? 'N/A',
      imageUrl: product['image_url'] ?? product['image_front_url'] ?? '',
      description: product['generic_name'] ?? product['product_name'] ?? '',
      ingredients: product['ingredients_text'] ?? '',
      nutritionGrade: product['nutriscore_grade'] ?? '',
      allergens: product['allergens'] ?? '',
      countries: product['countries'] ?? '',
      source: 'openfoodfacts',
      lastUpdated: DateTime.now(),
      fetchCount: 1,
    );
  }

  String _getCategory(String categories) {
    if (categories.contains(',')) {
      return categories.split(',').first.trim();
    }
    return categories.trim();
  }

  Future<void> saveProductToCache(Product product) async {
    try {
      final productData = product.toMap()
        ..addAll({
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'fetchCount': FieldValue.increment(1),
        });

      await _firestore
          .collection('products')
          .doc(product.barcode)
          .set(productData, SetOptions(merge: true));
      
      print('💾 Product cached: ${product.barcode}');
    } catch (e) {
      print('❌ Error saving product to cache: $e');
      throw e;
    }
  }

  Future<String> addToHouseholdInventory({
    required Product product,
    required String householdId,
    required String householdName,
    required String userId,
    required String userName,
  }) async {
    try {
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();

      if (!householdDoc.exists) {
        throw Exception('Household does not exist');
      }

      String finalCategory = product.category;
      if (!_fixedCategories.contains(finalCategory)) {
        finalCategory = 'Other';
      }

      final inventoryData = {
        'barcode': product.barcode,
        'productRef': _firestore.collection('products').doc(product.barcode),
        'name': product.name,
        'category': finalCategory,
        'brand': product.brand,
        'quantity': 1,
        'minStockLevel': 1,
        'location': '',
        'expiryDate': null,
        'purchaseDate': FieldValue.serverTimestamp(),
        'imageUrl': product.imageUrl,
        'description': product.description,
        'addedAt': FieldValue.serverTimestamp(),
        'addedByUserId': userId,
        'addedByUserName': userName,
        'householdId': householdId,
        'householdName': householdName,
        'source': product.source,
        'lastUpdated': FieldValue.serverTimestamp(),
        'originalCategory': product.originalCategory,
      };

      final docRef = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .add(inventoryData);

      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        throw Exception('Failed to create inventory item');
      }

      return docRef.id;
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      rethrow;
    }
  }

  String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Check Firestore security rules.';
      case 'not-found':
        return 'Household document not found.';
      case 'unavailable':
        return 'Network unavailable. Please check your connection.';
      default:
        return 'Firestore error: ${e.message}';
    }
  }
}

class BarcodeService {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  final ImagePicker _picker = ImagePicker();

  Future<String?> scanBarcode() async {
    try {
      final pickedImage = await _picker.pickImage(source: ImageSource.camera);
      if (pickedImage == null) return null;

      final inputImage = InputImage.fromFilePath(pickedImage.path);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue ?? '';
      }
      return null;
    } catch (e) {
      print('❌ Barcode scanning error: $e');
      rethrow;
    }
  }

  void dispose() {
    _barcodeScanner.close();
  }
}

// =============================================
// UI COMPONENTS
// =============================================

class ProductDetailsDialog extends StatelessWidget {
  final Product product;
  final bool isAdding;
  final VoidCallback onAddToHousehold;
  final Color primaryColor;
  final Color cardColor;
  final Color textColor;
  final Color lightTextColor;
  final Color secondaryColor;

  const ProductDetailsDialog({
    Key? key,
    required this.product,
    required this.isAdding,
    required this.onAddToHousehold,
    required this.primaryColor,
    required this.cardColor,
    required this.textColor,
    required this.lightTextColor,
    required this.secondaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
            _buildProductImage(),
            _buildProductDetails(),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            image: product.imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(product.imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: product.imageUrl.isEmpty
              ? Center(child: Icon(Icons.inventory_2, size: 50, color: lightTextColor))
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
              colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
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
              Text(product.name, style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
              ), maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: 4),
              Row(
                children: [
                  if (product.nutritionGrade.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getNutritionGradeColor(product.nutritionGrade),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Nutri-Score: ${product.nutritionGrade.toUpperCase()}',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  SizedBox(width: 8),
                  Text('Barcode: ${product.barcode}', style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 12,
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetails() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Brand', product.brand, Icons.business),
          SizedBox(height: 12),
          _buildDetailRow('Category', product.category, Icons.category),
          SizedBox(height: 12),
          _buildDetailRow('Quantity', product.quantity, Icons.scale),
          if (product.description.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildDetailRow('Description', product.description, Icons.description),
          ],
          if (product.ingredients.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildDetailRow('Ingredients', 
              product.ingredients.length > 100 
                ? '${product.ingredients.substring(0, 100)}...' 
                : product.ingredients, 
              Icons.eco),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primaryColor),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 12, color: lightTextColor, fontWeight: FontWeight.w500,
              )),
              SizedBox(height: 4),
              Text(value, style: TextStyle(
                fontSize: 16, color: textColor, fontWeight: FontWeight.w600,
              ), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isAdding ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: primaryColor),
              ),
              child: Text('Cancel'),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isAdding ? null : onAddToHousehold,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isAdding
                  ? SizedBox(
                      width: 20, height: 20,
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
}

// =============================================
// MAIN PAGE
// =============================================

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
  // Services
  final ProductService _productService = ProductService();
  final BarcodeService _barcodeService = BarcodeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  String _scanResult = '';
  bool _isScanning = false;
  bool _isAddingToHousehold = false;
  bool _isFetchingFromAPI = false;

  // Color scheme
  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _backgroundColor = Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF1E293B);
  final Color _lightTextColor = Color(0xFF64748B);
  final Color _secondaryColor = Color(0xFF4CAF50);
  final Color _disabledColor = Color(0xFF9E9E9E);
  final Color _warningColor = Color(0xFFFF6B35);

  Future<void> _scanBarcode() async {
    if (widget.isReadOnly) return;
    
    setState(() => _isScanning = true);

    try {
      final barcode = await _barcodeService.scanBarcode();
      
      if (barcode != null) {
        setState(() => _scanResult = barcode);
        await _processBarcode(barcode);
      } else {
        _showSnackBar('No barcode found', false);
      }
    } catch (e) {
      _showSnackBar('Error scanning: $e', true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _processBarcode(String barcode) async {
    setState(() => _isFetchingFromAPI = true);

    try {
      Product? cachedProduct = await _productService.getCachedProduct(barcode);
      
      if (cachedProduct != null) {
        _showProductDetails(cachedProduct);
        return;
      }

      final apiProduct = await _productService.fetchProductFromAPI(barcode);
      
      if (apiProduct != null) {
        await _productService.saveProductToCache(apiProduct);
        _showProductDetails(apiProduct);
        _showSnackBar('✅ Product data fetched and cached', false);
      } else {
        _showProductNotFoundDialog(barcode);
      }
    } catch (e) {
      _showSnackBar('Error processing barcode: $e', true);
    } finally {
      setState(() => _isFetchingFromAPI = false);
    }
  }

  void _showProductDetails(Product product) {
    if (widget.isReadOnly) return;
    
    showDialog(
      context: context,
      builder: (context) => ProductDetailsDialog(
        product: product,
        isAdding: _isAddingToHousehold,
        onAddToHousehold: () => _addToHousehold(product),
        primaryColor: _primaryColor,
        cardColor: _cardColor,
        textColor: _textColor,
        lightTextColor: _lightTextColor,
        secondaryColor: _secondaryColor,
      ),
    );
  }

  Future<void> _addToHousehold(Product product) async {
    if (_isAddingToHousehold) return;
    
    setState(() => _isAddingToHousehold = true);

    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'Unknown User';
      
      if (userId == null) throw Exception('User not authenticated');

      final itemId = await _productService.addToHouseholdInventory(
        product: product,
        householdId: widget.householdId,
        householdName: widget.householdName,
        userId: userId,
        userName: userName,
      );

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      _showSnackBar('✅ Item successfully added to ${widget.householdName}', false);
      print('✅ Item added successfully with ID: $itemId');

    } catch (e) {
      _showSnackBar('❌ Error adding item: $e', true);
    } finally {
      setState(() => _isAddingToHousehold = false);
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.search_off, size: 60, color: _warningColor),
            SizedBox(height: 16),
            Text('Product Not Found', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: _textColor,
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This barcode was not found in our database.', 
                 textAlign: TextAlign.center, style: TextStyle(color: _lightTextColor)),
            SizedBox(height: 8),
            Text('Barcode: $barcode', style: TextStyle(
              fontSize: 12, color: _lightTextColor, fontFamily: 'monospace',
            )),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _lightTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditPageWithBarcode(barcode);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _warningColor),
            child: Text('Add Manually'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditPage() {
    if (widget.isReadOnly) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => InventoryEditPage(
        householdId: widget.householdId,
        householdName: widget.householdName,
        userRole: 'creator',
        barcode: null,
      ),
    ));
  }

  void _navigateToEditPageWithBarcode(String barcode) {
    if (widget.isReadOnly) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => InventoryEditPage(
        householdId: widget.householdId,
        householdName: widget.householdName,
        userRole: 'creator',
        barcode: barcode,
      ),
    ));
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        widget.isReadOnly ? 'View Item Options' : 'Add Item',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      backgroundColor: widget.isReadOnly ? _disabledColor : _primaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 24),
          Expanded(child: _buildOptions()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isReadOnly 
            ? [_disabledColor, Color(0xFFBDBDBD)] 
            : [_primaryColor, Color(0xFF5A8BA8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.isReadOnly ? _disabledColor : _primaryColor).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isReadOnly ? Icons.visibility : Icons.add, 
              color: Colors.white, 
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isReadOnly ? 'View Item Options' : 'Add New Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  widget.isReadOnly 
                    ? 'View item addition options (read-only)' 
                    : 'Scan barcode or add manually to your database',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                ),
                if (!widget.isReadOnly) SizedBox(height: 4),
                if (!widget.isReadOnly)
                  Text(
                    'Products are cached for faster future lookups',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        _buildOptionCard(
          title: 'Scan Barcode',
          icon: Icons.qr_code_scanner,
          description: widget.isReadOnly 
            ? 'Scan product barcode (read-only)' 
            : 'Scan barcode to fetch product details',
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
        builder: (context, value, child) => Transform.scale(scale: value, child: child),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isReadOnly ? Colors.grey[100] : _cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOptionIcon(icon, isLoading, isReadOnly),
                  SizedBox(height: 16),
                  Text(title, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: isReadOnly ? _disabledColor : _textColor,
                  )),
                  SizedBox(height: 8),
                  Text(description, textAlign: TextAlign.center, style: TextStyle(
                    fontSize: 14, color: isReadOnly ? _disabledColor : _lightTextColor,
                  )),
                  if (showApiStatus) _buildStatusText('Fetching from OpenFoodFacts...', Colors.green),
                  if (isLoading && !showApiStatus) _buildStatusText('Scanning...', _primaryColor),
                  if (isReadOnly) _buildStatusText('Read-only access', _disabledColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionIcon(IconData icon, bool isLoading, bool isReadOnly) {
    if (isLoading) {
      return Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: (isReadOnly ? _disabledColor : _primaryColor).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isReadOnly ? _disabledColor : _primaryColor
              ),
              strokeWidth: 3,
            ),
            Icon(icon, size: 24, color: (isReadOnly ? _disabledColor : _primaryColor).withOpacity(0.7)),
          ],
        ),
      );
    }
    
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: (isReadOnly ? _disabledColor : _primaryColor).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 30, color: isReadOnly ? _disabledColor : _primaryColor),
    );
  }

  Widget _buildStatusText(String text, Color color) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Text(text, style: TextStyle(
        fontSize: 12, color: color, fontStyle: FontStyle.italic,
      )),
    );
  }
}