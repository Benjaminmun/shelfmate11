import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ItemInfoPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final String barcode;
  final Map<String, dynamic>? preFilledData;
  final bool isEditing;

  const ItemInfoPage({
    Key? key,
    required this.householdId,
    required this.householdName,
    required this.barcode,
    this.preFilledData,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _ItemInfoPageState createState() => _ItemInfoPageState();
}

class _ItemInfoPageState extends State<ItemInfoPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _supplierController;
  late TextEditingController _minStockLevelController;

  // Dates
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _hasExpiryDate = false;

  // Fixed categories
  final List<String> _categories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other'
  ];

  bool _isSaving = false;
  bool _isLoading = true;

  // Enhanced Color scheme
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color primaryLight = Color(0xFF5A8BA6);
  final Color primaryDark = Color(0xFF1A3A4D);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color secondaryLight = Color(0xFF80E27E);
  final Color accentColor = Color(0xFFFF9800);
  final Color warningColor = Color(0xFFFF6B35);
  final Color backgroundColor = Color(0xFFF8FBFF);
  final Color surfaceColor = Colors.white;
  final Color textColor = Color(0xFF2C3E50);
  final Color lightTextColor = Color(0xFF7F8C8D);
  final Color disabledColor = Color(0xFFBDC3C7);
  final Color successColor = Color(0xFF27AE60);
  final Color errorColor = Color(0xFFE74C3C);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _initializeControllers();
    _loadExistingData();
    _animationController.forward();
  }

  void _initializeControllers() {
    _barcodeController = TextEditingController(text: widget.barcode);
    _nameController = TextEditingController();
    _categoryController = TextEditingController();
    _descriptionController = TextEditingController();
    _imageUrlController = TextEditingController();
    _quantityController = TextEditingController(text: '1'); // Default value set to 1
    _priceController = TextEditingController();
    _locationController = TextEditingController();
    _supplierController = TextEditingController();
    _minStockLevelController = TextEditingController(text: '1');

    // Set purchase date to today by default
    _purchaseDate = DateTime.now();
  }

  Future<void> _loadExistingData() async {
    try {
      // Try to get existing product data
      final productDoc = await _firestore
          .collection('products')
          .doc(widget.barcode)
          .get();

      Map<String, dynamic> data = {};

      if (productDoc.exists) {
        // Use existing product data
        data = productDoc.data()!;
      } else if (widget.preFilledData != null) {
        // Use pre-filled data from scan
        data = widget.preFilledData!;
      }

      // Populate form with data
      setState(() {
        _nameController.text = data['name'] ?? '';
        _categoryController.text = data['category'] ?? 'Other';
        _descriptionController.text = data['description'] ?? '';
        _imageUrlController.text = data['imageUrl'] ?? '';
        _quantityController.text = (data['quantity'] ?? 1).toString();
        _priceController.text = (data['price'] ?? '').toString();
        _locationController.text = data['location'] ?? '';
        _supplierController.text = data['supplier'] ?? '';
        _minStockLevelController.text = (data['minStockLevel'] ?? 1).toString();

        // Handle dates
        if (data['expiryDate'] != null) {
          _expiryDate = (data['expiryDate'] as Timestamp).toDate();
          _hasExpiryDate = true;
        }
        if (data['purchaseDate'] != null) {
          _purchaseDate = (data['purchaseDate'] as Timestamp).toDate();
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading existing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Parse quantity with proper validation - default to 1 if invalid
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      
      // Determine source
      String source = 'manual';
      if (widget.preFilledData != null) {
        source = widget.preFilledData!['source'] == 'openfoodfacts' 
            ? 'openfoodfacts' 
            : 'scanned';
      }

      // Prepare product data
      final productData = {
        'barcode': widget.barcode,
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'quantity': quantity,
        'price': double.tryParse(_priceController.text),
        'location': _locationController.text.trim(),
        'supplier': _supplierController.text.trim(),
        'expiryDate': _hasExpiryDate && _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'purchaseDate': _purchaseDate != null ? Timestamp.fromDate(_purchaseDate!) : Timestamp.now(),
        'minStockLevel': int.tryParse(_minStockLevelController.text) ?? 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': source,
        'lastUpdatedBy': userId,
      };

      // Remove null values
      productData.removeWhere((key, value) => value == null);

      // Use the enhanced saving function
      await _saveProductToFirestore(widget.barcode, productData);

      // Also add to household inventory
      final inventoryData = {
        'barcode': widget.barcode,
        'productRef': _firestore.collection('products').doc(widget.barcode),
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'quantity': quantity,
        'price': double.tryParse(_priceController.text),
        'location': _locationController.text.trim(),
        'supplier': _supplierController.text.trim(),
        'expiryDate': _hasExpiryDate && _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'purchaseDate': _purchaseDate != null ? Timestamp.fromDate(_purchaseDate!) : Timestamp.now(),
        'minStockLevel': int.tryParse(_minStockLevelController.text) ?? 1,
        'imageUrl': _imageUrlController.text.trim(),
        'description': _descriptionController.text.trim(),
        'addedAt': FieldValue.serverTimestamp(),
        'addedByUserId': userId,
        'addedByUserName': _auth.currentUser?.displayName ?? 'Unknown User',
        'householdId': widget.householdId,
        'householdName': widget.householdName,
        'source': source,
        'lastUpdated': FieldValue.serverTimestamp(),
        'hasExpiryDate': _hasExpiryDate && _expiryDate != null,
      };

      // Remove null values from inventory data
      inventoryData.removeWhere((key, value) => value == null);

      await _firestore
          .collection('households')
          .doc(widget.householdId)
          .collection('inventory')
          .add(inventoryData);

      // Setup expiry notification if expiry date is set
      if (_hasExpiryDate && _expiryDate != null) {
        await _setupExpiryNotification(widget.barcode, _expiryDate!);
      }

      _showSuccessSnackBar('Product saved successfully!');
      Navigator.pop(context);
      
    } catch (e) {
      print('❌ Error saving product: $e');
      _showErrorSnackBar('Error saving product: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Enhanced product saving with debugging
  Future<void> _saveProductToFirestore(String barcode, Map<String, dynamic> productData) async {
    try {
      print('💾 Attempting to save product to Firestore: $barcode');
      
      // Add timestamp and ensure all required fields
      final dataToSave = {
        ...productData,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('products')
          .doc(barcode)
          .set(dataToSave, SetOptions(merge: true));
      
      // Debug: Verify the save was successful
      final savedDoc = await _firestore
          .collection('products')
          .doc(barcode)
          .get();
      
      if (savedDoc.exists) {
        print('✅ Product successfully saved to Firestore with barcode: $barcode');
        print('📦 Saved product data: ${savedDoc.data()}');
      } else {
        print('❌ Failed to save product to Firestore - document does not exist after save');
      }
      
    } catch (e) {
      print('❌ Error saving product to Firestore: $e');
      throw e;
    }
  }

  Future<void> _setupExpiryNotification(String barcode, DateTime expiryDate) async {
    try {
      // Calculate notification date (7 days before expiry)
      final notificationDate = expiryDate.subtract(Duration(days: 7));
      
      // Only setup notification if it's in the future
      if (notificationDate.isAfter(DateTime.now())) {
        await _firestore.collection('expiry_notifications').add({
          'barcode': barcode,
          'productName': _nameController.text.trim(),
          'expiryDate': Timestamp.fromDate(expiryDate),
          'notificationDate': Timestamp.fromDate(notificationDate),
          'householdId': widget.householdId,
          'isNotified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('🔔 Expiry notification scheduled for ${_nameController.text}');
      }
    } catch (e) {
      print('❌ Error setting up expiry notification: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExpiryDate) async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDatePickerBottomSheet(isExpiryDate),
    );
    
    if (picked != null) {
      setState(() {
        if (isExpiryDate) {
          _expiryDate = picked;
        } else {
          _purchaseDate = picked;
        }
      });
    }
  }

  Widget _buildDatePickerBottomSheet(bool isExpiryDate) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isExpiryDate ? 'Select Expiry Date' : 'Select Purchase Date',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: lightTextColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: CalendarDatePicker(
              initialDate: isExpiryDate ? (_expiryDate ?? DateTime.now().add(Duration(days: 30))) : (_purchaseDate ?? DateTime.now()),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (date) {
                Navigator.pop(context, date);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _clearDate(bool isExpiryDate) {
    setState(() {
      if (isExpiryDate) {
        _expiryDate = null;
      } else {
        _purchaseDate = null;
      }
    });
  }

  void _incrementQuantity() {
    int current = int.tryParse(_quantityController.text) ?? 1;
    setState(() {
      _quantityController.text = (current + 1).toString();
    });
  }

  void _decrementQuantity() {
    int current = int.tryParse(_quantityController.text) ?? 1;
    if (current > 1) {
      setState(() {
        _quantityController.text = (current - 1).toString();
      });
    }
  }

  void _showValidationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Please fix the errors in the form')),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHeader() {
    final hasPreFilledData = widget.preFilledData != null;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryLight, primaryColor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                Spacer(),
                if (hasPreFilledData)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Scanned',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              widget.isEditing ? 'Edit Product' : 'Add Product',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.householdName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            if (hasPreFilledData) ...[
              SizedBox(height: 8),
              Text(
                'Product details pre-filled from barcode scan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.barcode_reader, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Barcode: ${widget.barcode}',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: 12),
                Text(
                  'Loading...',
                  style: TextStyle(color: lightTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithLabel({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
    bool isQuantity = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontSize: 14,
            color: lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        if (isQuantity)
          _buildQuantityField()
        else
          _buildTextField(controller, '', icon, isRequired,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              validator: validator),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isRequired,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? (isRequired ? '$label *' : label) : null,
        prefixIcon: Icon(icon, color: lightTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: lightTextColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15, color: textColor),
    );
  }

  Widget _buildQuantityField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.remove, size: 20, color: primaryColor),
              onPressed: _decrementQuantity,
            ),
          ),
          
          Expanded(
            child: TextFormField(
              controller: _quantityController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: false,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter valid quantity';
                }
                return null;
              },
              style: TextStyle(
                fontSize: 16, 
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.add, size: 20, color: primaryColor),
              onPressed: _incrementQuantity,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category *',
          style: TextStyle(
            fontSize: 14,
            color: lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _categoryController.text.isNotEmpty ? _categoryController.text : 'Other',
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorColor, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: Icon(Icons.category_outlined, color: lightTextColor),
          ),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category, style: TextStyle(fontSize: 15, color: textColor)),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _categoryController.text = newValue!;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
          dropdownColor: Colors.white,
          style: TextStyle(fontSize: 15, color: textColor),
          icon: Icon(Icons.arrow_drop_down, color: lightTextColor),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, bool isExpiryDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context, isExpiryDate),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: lightTextColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Select date',
                      style: TextStyle(
                        fontSize: 15,
                        color: date != null ? textColor : lightTextColor,
                      ),
                    ),
                  ),
                  if (date != null)
                    GestureDetector(
                      onTap: () => _clearDate(isExpiryDate),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.clear, color: lightTextColor, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryToggle() {
    return SwitchListTile(
      title: Text(
        'Has Expiry Date',
        style: TextStyle(
          fontSize: 16,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _hasExpiryDate 
            ? 'Product will expire and send notifications'
            : 'Product does not expire',
        style: TextStyle(
          fontSize: 14,
          color: lightTextColor,
        ),
      ),
      value: _hasExpiryDate,
      onChanged: (value) {
        setState(() {
          _hasExpiryDate = value;
          if (value && _expiryDate == null) {
            _expiryDate = DateTime.now().add(Duration(days: 30));
          }
        });
      },
      activeColor: primaryColor,
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barcode',
          style: TextStyle(
            fontSize: 14,
            color: lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code, color: lightTextColor, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.barcode,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'READ ONLY',
                  style: TextStyle(
                    fontSize: 10,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.isEditing ? Icons.update : Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        widget.isEditing ? 'Update Product' : 'Add to Inventory',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
        if (widget.isEditing) ...[
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: lightTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Cancel'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _supplierController.dispose();
    _minStockLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionCard(
                                  title: 'Product Information',
                                  icon: Icons.inventory_2_outlined,
                                  children: [
                                    _buildBarcodeField(),
                                    SizedBox(height: 20),
                                    _buildTextFieldWithLabel(
                                      label: 'Product Name *',
                                      controller: _nameController,
                                      icon: Icons.label_outline,
                                      isRequired: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a product name';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 20),
                                    _buildCategoryField(),
                                    SizedBox(height: 20),
                                    _buildTextFieldWithLabel(
                                      label: 'Description',
                                      controller: _descriptionController,
                                      icon: Icons.notes_outlined,
                                      maxLines: 3,
                                    ),
                                    SizedBox(height: 20),
                                    _buildTextFieldWithLabel(
                                      label: 'Image URL',
                                      controller: _imageUrlController,
                                      icon: Icons.link,
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 20),
                                
                                _buildSectionCard(
                                  title: 'Inventory Details',
                                  icon: Icons.analytics_outlined,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Quantity *',
                                            controller: _quantityController,
                                            icon: Icons.format_list_numbered,
                                            isQuantity: true,
                                            isRequired: true,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Price',
                                            controller: _priceController,
                                            icon: Icons.attach_money_outlined,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                            validator: (value) {
                                              if (value != null && value.isNotEmpty) {
                                                if (double.tryParse(value) == null || double.parse(value) < 0) {
                                                  return 'Please enter valid price';
                                                }
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Min Stock Level',
                                            controller: _minStockLevelController,
                                            icon: Icons.warning_amber_outlined,
                                            validator: (value) {
                                              if (value != null && value.isNotEmpty) {
                                                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                                  return 'Please enter valid number';
                                                }
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Supplier',
                                            controller: _supplierController,
                                            icon: Icons.business_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    _buildTextFieldWithLabel(
                                      label: 'Location',
                                      controller: _locationController,
                                      icon: Icons.location_on_outlined,
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 20),
                                
                                _buildSectionCard(
                                  title: 'Dates',
                                  icon: Icons.calendar_today_outlined,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDateField('Purchase Date', _purchaseDate, false),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDateField('Expiry Date', _expiryDate, true),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    _buildExpiryToggle(),
                                  ],
                                ),
                                
                                SizedBox(height: 32),
                                
                                _buildActionButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}