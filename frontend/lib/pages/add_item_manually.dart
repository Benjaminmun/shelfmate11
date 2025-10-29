import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/inventory_item_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddItemManually extends StatefulWidget {
  final String householdId;
  final String householdName;
  final String userRole;
  final String? barcode;
  final InventoryItem? existingItem;
  final Map<String, dynamic>? productData; // New parameter for product data

  const AddItemManually({
    Key? key,
    required this.householdId,
    required this.householdName,
    required this.userRole,
    this.barcode,
    this.existingItem,
    this.productData, // Accept product data
  }) : super(key: key);

  @override
  _AddItemManuallyState createState() => _AddItemManuallyState();
}

class _AddItemManuallyState extends State<AddItemManually> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String _selectedCategory = 'Other';
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _hasExpiryDate = false;
  bool _isLoading = false;
  bool _isReadOnly = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Image handling
  XFile? _pickedImage;
  String? _localImagePath;
  String? _uploadedImageUrl;

  final List<String> _categories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other'
  ];

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
    
    _isReadOnly = widget.userRole == 'member';
    _initializeForm();
    _animationController.forward();
  }

  void _initializeForm() {
    if (widget.existingItem != null) {
      // Editing existing item - use InventoryItem model
      _nameController.text = widget.existingItem!.name;
      _categoryController.text = widget.existingItem!.category;
      _quantityController.text = widget.existingItem!.quantity.toString();
      _priceController.text = widget.existingItem!.price.toString();
      _locationController.text = widget.existingItem!.location ?? '';
      _minStockController.text = widget.existingItem!.minStockLevel?.toString() ?? '1';
      _descriptionController.text = widget.existingItem!.description ?? '';
      _supplierController.text = widget.existingItem!.supplier ?? '';
      _selectedCategory = widget.existingItem!.category;
      _imageUrlController.text = widget.existingItem!.imageUrl ?? '';
      _uploadedImageUrl = widget.existingItem!.imageUrl;
      _localImagePath = widget.existingItem!.localImagePath;
      
      // Handle expiry date
      if (widget.existingItem!.expiryDate != null) {
        _expiryDate = widget.existingItem!.expiryDate;
        _hasExpiryDate = true;
      }
      
      // Handle purchase date
      if (widget.existingItem!.purchaseDate != null) {
        _purchaseDate = widget.existingItem!.purchaseDate;
      } else {
        _purchaseDate = DateTime.now();
      }
    } else if (widget.productData != null) {
      // New item with product data from barcode scan
      _nameController.text = widget.productData!['name'] ?? '';
      _selectedCategory = widget.productData!['category'] ?? 'Other';
      _descriptionController.text = widget.productData!['description'] ?? '';
      _imageUrlController.text = widget.productData!['imageUrl'] ?? '';
      _supplierController.text = widget.productData!['brand'] ?? '';
      _purchaseDate = DateTime.now();
      _minStockController.text = '1';
      _quantityController.text = '1';
      _priceController.text = '0.0';
      
      // Set uploaded image URL if available
      if (widget.productData!['imageUrl'] != null && widget.productData!['imageUrl'].isNotEmpty) {
        _uploadedImageUrl = widget.productData!['imageUrl'];
      }
    } else if (widget.barcode != null) {
      // New item with barcode but no product data
      _purchaseDate = DateTime.now();
      _minStockController.text = '1';
      _quantityController.text = '1';
      _priceController.text = '0.0';
    } else {
      // New manual item - set default purchase date to today
      _purchaseDate = DateTime.now();
      _minStockController.text = '1';
      _quantityController.text = '1';
      _priceController.text = '0.0';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExpiryDate) async {
    if (_isReadOnly) return;
    
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
    if (_isReadOnly) return;
    
    setState(() {
      if (isExpiryDate) {
        _expiryDate = null;
      } else {
        _purchaseDate = null;
      }
    });
  }

  void _incrementQuantity() {
    if (_isReadOnly) return;
    
    int current = int.tryParse(_quantityController.text) ?? 1;
    setState(() {
      _quantityController.text = (current + 1).toString();
    });
  }

  void _decrementQuantity() {
    if (_isReadOnly) return;
    
    int current = int.tryParse(_quantityController.text) ?? 1;
    if (current > 1) {
      setState(() {
        _quantityController.text = (current - 1).toString();
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isReadOnly) return;

    try {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showErrorSnackBar('Gallery permission is required to pick images');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _pickedImage = image;
          _localImagePath = image.path;
          _imageUrlController.clear(); // Clear URL when picking local image
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _takePhotoWithCamera() async {
    if (_isReadOnly) return;

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showErrorSnackBar('Camera permission is required to take photos');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _pickedImage = image;
          _localImagePath = image.path;
          _imageUrlController.clear(); // Clear URL when taking photo
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: $e');
    }
  }

  Future<String?> _uploadImageToFirebase() async {
    if (_localImagePath == null) return null;

    try {
      setState(() => _isLoading = true);
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child('item_images/$fileName');
      final UploadTask uploadTask = storageRef.putFile(File(_localImagePath!));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      _showErrorSnackBar('Error uploading image: $e');
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeImage() {
    if (_isReadOnly) return;

    setState(() {
      _pickedImage = null;
      _localImagePath = null;
      _uploadedImageUrl = null;
      _imageUrlController.clear();
    });
  }

  void _showImageSourceDialog() {
    if (_isReadOnly) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  'Choose Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primaryColor),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: primaryColor),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoWithCamera();
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'Unknown User';
      
      if (userId == null) throw Exception('User not authenticated');

      String? finalImageUrl = _uploadedImageUrl;

      // Upload new image if one was picked
      if (_localImagePath != null) {
        finalImageUrl = await _uploadImageToFirebase();
      } else if (_imageUrlController.text.isNotEmpty) {
        finalImageUrl = _imageUrlController.text.trim();
      }

      // Create InventoryItem object
      final inventoryItem = InventoryItem(
        id: widget.existingItem?.id, // Keep existing ID for updates
        name: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        price: double.tryParse(_priceController.text) ?? 0.0,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        purchaseDate: _purchaseDate,
        expiryDate: _hasExpiryDate ? _expiryDate : null,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        barcode: widget.barcode,
        minStockLevel: int.tryParse(_minStockController.text),
        imageUrl: finalImageUrl,
        localImagePath: _localImagePath,
        createdAt: widget.existingItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        addedByUserId: widget.existingItem?.addedByUserId ?? userId,
        addedByUserName: widget.existingItem?.addedByUserName ?? userName,
        updatedByUserId: userId,
        updatedByUserName: userName,
      );

      if (widget.existingItem != null) {
        // Update existing item using update map (only changed fields)
        final updateMap = inventoryItem.toUpdateMap(
          name: inventoryItem.name,
          category: inventoryItem.category,
          quantity: inventoryItem.quantity,
          price: inventoryItem.price,
          description: inventoryItem.description,
          purchaseDate: inventoryItem.purchaseDate,
          expiryDate: inventoryItem.expiryDate,
          location: inventoryItem.location,
          supplier: inventoryItem.supplier,
          barcode: inventoryItem.barcode,
          minStockLevel: inventoryItem.minStockLevel,
          imageUrl: inventoryItem.imageUrl,
          localImagePath: inventoryItem.localImagePath,
        );

        await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('inventory')
            .doc(widget.existingItem!.id)
            .update(updateMap);
      } else {
        // Add new item using full map
        final itemMap = inventoryItem.toMap();
        // Add household-specific fields
        itemMap.addAll({
          'householdId': widget.householdId,
          'householdName': widget.householdName,
        });

        await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('inventory')
            .add(itemMap);
      }

      // Schedule notifications if expiry date is set
      if (_hasExpiryDate && _expiryDate != null) {
        await _scheduleExpiryNotifications(_expiryDate!, _nameController.text);
      }

      _showSuccessSnackBar(widget.existingItem != null ? 
          'Item updated successfully' : 
          'Item added successfully');

      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Error saving item: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleExpiryNotifications(DateTime expiryDate, String itemName) async {
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;
    
    print('📅 Scheduling notifications for $itemName');
    print('   Expiry date: $expiryDate');
    print('   Days until expiry: $daysUntilExpiry');
    
    if (daysUntilExpiry <= 7) {
      print('   🔔 Will notify user about expiring item');
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
    final isEditMode = widget.existingItem != null;
    final hasProductData = widget.productData != null;
    
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
                if (hasProductData)
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
                if (isEditMode && !_isReadOnly)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: 22),
                      color: Colors.white,
                      onPressed: _showDeleteDialog,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              isEditMode ? 'Item Details' : 'Add New Item',
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
            if (hasProductData) ...[
              SizedBox(height: 8),
              Text(
                'Product details pre-filled from barcode scan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
            if (isEditMode && widget.existingItem != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '${widget.existingItem!.quantity} in stock',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
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
                  'Saving...',
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
            color: _isReadOnly ? disabledColor : lightTextColor,
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
      enabled: !_isReadOnly,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? (isRequired ? '$label *' : label) : null,
        prefixIcon: Icon(icon, color: _isReadOnly ? disabledColor : lightTextColor),
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
        fillColor: _isReadOnly ? Colors.grey[100] : Colors.white,
        labelStyle: TextStyle(color: _isReadOnly ? disabledColor : lightTextColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: _isReadOnly ? null : validator,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15, color: _isReadOnly ? disabledColor : textColor),
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
            color: _isReadOnly ? disabledColor : lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
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
            fillColor: _isReadOnly ? Colors.grey[100] : Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: Icon(Icons.category_outlined, color: _isReadOnly ? disabledColor : lightTextColor),
          ),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category, style: TextStyle(fontSize: 15, color: _isReadOnly ? disabledColor : textColor)),
            );
          }).toList(),
          onChanged: _isReadOnly ? null : (String? newValue) {
            setState(() {
              _selectedCategory = newValue!;
            });
          },
          validator: _isReadOnly ? null : (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
          dropdownColor: Colors.white,
          style: TextStyle(fontSize: 15, color: _isReadOnly ? disabledColor : textColor),
          icon: Icon(Icons.arrow_drop_down, color: _isReadOnly ? disabledColor : lightTextColor),
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: _isReadOnly ? Colors.grey[100] : Colors.white,
      ),
      child: Row(
        children: [
          if (!_isReadOnly)
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
              enabled: !_isReadOnly,
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
              validator: _isReadOnly ? null : (value) {
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
                color: _isReadOnly ? disabledColor : textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          if (!_isReadOnly)
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

  Widget _buildDateField(String label, DateTime? date, bool isExpiryDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: _isReadOnly ? disabledColor : lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _isReadOnly ? null : () => _selectDate(context, isExpiryDate),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: _isReadOnly ? Colors.grey[100] : Colors.white,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: _isReadOnly ? disabledColor : lightTextColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Select date',
                      style: TextStyle(
                        fontSize: 15,
                        color: date != null ? (_isReadOnly ? disabledColor : textColor) : (_isReadOnly ? disabledColor : lightTextColor),
                      ),
                    ),
                  ),
                  if (date != null && !_isReadOnly)
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
          color: _isReadOnly ? disabledColor : textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _hasExpiryDate 
            ? 'Product will expire and send notifications'
            : 'Product does not expire',
        style: TextStyle(
          fontSize: 14,
          color: _isReadOnly ? disabledColor : lightTextColor,
        ),
      ),
      value: _hasExpiryDate,
      onChanged: _isReadOnly ? null : (value) {
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Image',
          style: TextStyle(
            fontSize: 14,
            color: _isReadOnly ? disabledColor : lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        
        if (_localImagePath != null || _imageUrlController.text.isNotEmpty || _uploadedImageUrl != null)
          _buildImagePreview()
        else
          _buildImagePlaceholder(),
          
        SizedBox(height: 16),
        
        _buildImageUrlField(),
        
        if (_localImagePath != null || _imageUrlController.text.isNotEmpty || _uploadedImageUrl != null)
          SizedBox(height: 12),
          
        if (!_isReadOnly && (_localImagePath != null || _imageUrlController.text.isNotEmpty || _uploadedImageUrl != null))
          _buildImageActions(),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return GestureDetector(
      onTap: _isReadOnly ? null : _showImageSourceDialog,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isReadOnly ? disabledColor : primaryColor.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: _isReadOnly ? disabledColor : primaryColor,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'Add Item Image',
              style: TextStyle(
                color: _isReadOnly ? disabledColor : primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap to choose from gallery or camera',
              style: TextStyle(
                color: _isReadOnly ? disabledColor : lightTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _previewImage,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.grey[50],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _localImagePath != null
              ? Image.file(
                  File(_localImagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImageError();
                  },
                )
              : _imageUrlController.text.isNotEmpty || _uploadedImageUrl != null
                  ? Image.network(
                      _uploadedImageUrl ?? _imageUrlController.text,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImageError();
                      },
                    )
                  : _buildImageError(),
        ),
      ),
    );
  }

  Widget _buildImageUrlField() {
    return TextFormField(
      controller: _imageUrlController,
      enabled: !_isReadOnly,
      decoration: InputDecoration(
        labelText: 'Image URL (Optional)',
        prefixIcon: Icon(Icons.link, color: _isReadOnly ? disabledColor : lightTextColor),
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
        filled: true,
        fillColor: _isReadOnly ? Colors.grey[100] : Colors.white,
        labelStyle: TextStyle(color: _isReadOnly ? disabledColor : lightTextColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: 'https://example.com/image.jpg',
      ),
      onChanged: (value) {
        if (value.isNotEmpty) {
          setState(() {
            _pickedImage = null;
            _localImagePath = null;
          });
        }
      },
      style: TextStyle(fontSize: 15, color: _isReadOnly ? disabledColor : textColor),
    );
  }

  Widget _buildImageError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.grey, size: 48),
        SizedBox(height: 8),
        Text('Image not available', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildImageActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showImageSourceDialog,
            icon: Icon(Icons.edit, size: 18),
            label: Text('Change Image'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _removeImage,
            icon: Icon(Icons.delete_outline, size: 18),
            label: Text('Remove'),
            style: OutlinedButton.styleFrom(
              foregroundColor: errorColor,
              side: BorderSide(color: errorColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _previewImage() {
    if (_localImagePath == null && _imageUrlController.text.isEmpty && _uploadedImageUrl == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Image Preview',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: lightTextColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[50],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _localImagePath != null
                            ? Image.file(
                                File(_localImagePath!),
                                fit: BoxFit.contain,
                              )
                            : _imageUrlController.text.isNotEmpty || _uploadedImageUrl != null
                                ? Image.network(
                                    _uploadedImageUrl ?? _imageUrlController.text,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: primaryColor,
                                        ),
                                      );
                                    },
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return _buildImageError();
                                    },
                                  )
                                : _buildImageError(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                      elevation: 2,
                    ),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final isEditMode = widget.existingItem != null;
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
            child: _isLoading
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
                      Icon(isEditMode ? Icons.update : Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        isEditMode ? 'Update Item' : 'Add to Inventory',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
        if (isEditMode) ...[
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

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: warningColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_forever, color: Colors.white, size: 30),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Delete Item',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This action cannot be undone',
                      style: TextStyle(fontSize: 15, color: lightTextColor),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to delete "${_nameController.text}"?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: textColor, height: 1.5),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: lightTextColor,
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: errorColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('inventory')
            .doc(widget.existingItem!.id)
            .delete();

        _showSuccessSnackBar('Item deleted successfully');
        Navigator.pop(context);
      } catch (e) {
        _showErrorSnackBar('Error deleting item: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog() {
    if (_isReadOnly) return;
    _deleteItem();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    _supplierController.dispose();
    _imageUrlController.dispose();
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
                                  title: 'Basic Information',
                                  icon: Icons.inventory_2_outlined,
                                  children: [
                                    _buildTextFieldWithLabel(
                                      label: 'Item Name *',
                                      controller: _nameController,
                                      icon: Icons.label_outline,
                                      isRequired: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter an item name';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 20),
                                    _buildCategoryField(),
                                    SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Quantity *',
                                            controller: _quantityController,
                                            icon: Icons.format_list_numbered,
                                            isQuantity: true,
                                            isRequired: true,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter quantity';
                                              }
                                              if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                                return 'Please enter valid quantity';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: _buildTextFieldWithLabel(
                                            label: 'Price *',
                                            controller: _priceController,
                                            icon: Icons.attach_money_outlined,
                                            isRequired: true,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter price';
                                              }
                                              if (double.tryParse(value) == null || double.parse(value) < 0) {
                                                return 'Please enter valid price';
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
                                            controller: _minStockController,
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
                                      label: 'Description',
                                      controller: _descriptionController,
                                      icon: Icons.notes_outlined,
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 20),
                                
                                _buildSectionCard(
                                  title: 'Item Image',
                                  icon: Icons.photo_library_outlined,
                                  children: [
                                    _buildImageSection(),
                                  ],
                                ),
                                
                                SizedBox(height: 20),
                                
                                _buildSectionCard(
                                  title: 'Stock Management',
                                  icon: Icons.analytics_outlined,
                                  children: [
                                    _buildTextFieldWithLabel(
                                      label: 'Storage Location',
                                      controller: _locationController,
                                      icon: Icons.location_on_outlined,
                                    ),
                                    SizedBox(height: 20),
                                    if (widget.barcode != null)
                                      _buildTextFieldWithLabel(
                                        label: 'Barcode',
                                        controller: TextEditingController(text: widget.barcode),
                                        icon: Icons.qr_code_outlined,
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
                                
                                if (!_isReadOnly) _buildActionButtons(),
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