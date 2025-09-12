import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'inventory_item_model.dart';
import 'inventory_service.dart';

class InventoryEditPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final InventoryItem? item;
  final String userRole;

  const InventoryEditPage({
    Key? key,
    required this.householdId,
    required this.householdName,
    this.item,
    required this.userRole,
  }) : super(key: key);

  @override
  _InventoryEditPageState createState() => _InventoryEditPageState();
}

class _InventoryEditPageState extends State<InventoryEditPage> {
  final InventoryService _inventoryService = InventoryService();
  final _formKey = GlobalKey<FormState>();
  final List<String> _categories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other'
  ];

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _supplierController;
  late TextEditingController _barcodeController;
  late TextEditingController _minStockLevelController;

  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Color scheme
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);
  final Color backgroundColor = Color(0xFFF5F7F9);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF333333);
  final Color lightTextColor = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    
    _isEditMode = widget.item?.id != null;
    
    // Initialize controllers with existing item data or empty values
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _categoryController = TextEditingController(text: widget.item?.category ?? _categories[0]);
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '1');
    _priceController = TextEditingController(text: widget.item?.price.toStringAsFixed(2) ?? '0.00');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
    _locationController = TextEditingController(text: widget.item?.location ?? '');
    _supplierController = TextEditingController(text: widget.item?.supplier ?? '');
    _barcodeController = TextEditingController(text: widget.item?.barcode ?? '');
    _minStockLevelController = TextEditingController(text: widget.item?.minStockLevel?.toString() ?? '5');
    
    _purchaseDate = widget.item?.purchaseDate;
    _expiryDate = widget.item?.expiryDate;
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _supplierController.dispose();
    _barcodeController.dispose();
    _minStockLevelController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to the first error
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final item = InventoryItem(
        id: widget.item?.id,
        name: _nameController.text,
        category: _categoryController.text,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        supplier: _supplierController.text.isNotEmpty ? _supplierController.text : null,
        barcode: _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
        minStockLevel: _minStockLevelController.text.isNotEmpty ? double.parse(_minStockLevelController.text) : null,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
      );

      if (!_isEditMode) {
        // Add new item
        await _inventoryService.addItem(widget.householdId, item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} added successfully'),
            backgroundColor: secondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      } else {
        // Update existing item
        await _inventoryService.updateItem(widget.householdId, item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} updated successfully'),
            backgroundColor: secondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExpiryDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isExpiryDate ? (_expiryDate ?? DateTime.now().add(Duration(days: 30))) : (_purchaseDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit ${widget.item?.name}' : 'Add New Item',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 26),
              onPressed: () {
                _showDeleteDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                  SizedBox(height: 16),
                  Text('Saving item...', style: TextStyle(color: lightTextColor)),
                ],
              ),
            )
          : GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside of text fields
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Details Card
                      _buildSectionCard(
                        title: 'Item Details',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          _buildTextField(_nameController, 'Item Name', Icons.label_outline, true,
                              validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an item name';
                            }
                            return null;
                          }),
                          SizedBox(height: 16),
                          _buildCategoryField(),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildQuantityField(),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildTextField(_priceController, 'Price', Icons.attach_money, true,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    prefixText: '\$ ',
                                    validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a price';
                                  }
                                  if (double.tryParse(value) == null || double.parse(value) < 0) {
                                    return 'Please enter a valid price';
                                  }
                                  return null;
                                }),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _buildTextField(_minStockLevelController, 'Minimum Stock Level', Icons.inventory_2, true,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a minimum stock level';
                            }
                            if (int.tryParse(value) == null || int.parse(value) <= 0) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          }),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Additional Information Card
                      _buildSectionCard(
                        title: 'Additional Information',
                        icon: Icons.info_outline,
                        children: [
                          _buildTextField(_descriptionController, 'Description', Icons.description, false,
                              maxLines: 3),
                          SizedBox(height: 16),
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
                          _buildTextField(_locationController, 'Storage Location', Icons.location_on_outlined, false),
                          SizedBox(height: 16),
                          _buildTextField(_supplierController, 'Supplier', Icons.business_center_outlined, false),
                          SizedBox(height: 16),
                          _buildTextField(_barcodeController, 'Barcode/SKU', Icons.qr_code_scanner_outlined, false,
                              keyboardType: TextInputType.number),
                        ],
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            padding: EdgeInsets.symmetric(vertical: 14),
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
                              : Text(
                                  _isEditMode ? 'Update Item' : 'Add Item',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryColor),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isRequired,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, int maxLines = 1, String? prefixText}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        prefixIcon: Icon(icon, color: lightTextColor),
        prefixText: prefixText,
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
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
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

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      value: _categoryController.text.isNotEmpty ? _categoryController.text : _categories[0],
      decoration: InputDecoration(
        labelText: 'Category *',
        prefixIcon: Icon(Icons.category_outlined, color: lightTextColor),
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
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        labelStyle: TextStyle(color: lightTextColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      decoration: InputDecoration(
        labelText: 'Quantity *',
        prefixIcon: Icon(Icons.format_list_numbered, color: lightTextColor),
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
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        labelStyle: TextStyle(color: lightTextColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.remove, size: 18),
              onPressed: _decrementQuantity,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            Container(width: 1, height: 24, color: Colors.grey[300]),
            IconButton(
              icon: Icon(Icons.add, size: 18),
              onPressed: _incrementQuantity,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a quantity';
        }
        if (int.tryParse(value) == null || int.parse(value) <= 0) {
          return 'Please enter a valid quantity';
        }
        return null;
      },
      style: TextStyle(fontSize: 15, color: textColor),
    );
  }

  Widget _buildDateField(String label, DateTime? date, bool isExpiryDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: lightTextColor, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.grey[50],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.calendar_today_outlined, color: lightTextColor, size: 20),
                  onPressed: () => _selectDate(context, isExpiryDate),
                ),
                Expanded(
                  child: Text(
                    date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Not set',
                    style: TextStyle(fontSize: 15, color: date != null ? textColor : lightTextColor),
                  ),
                ),
                if (date != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: lightTextColor, size: 18),
                    onPressed: () => _clearDate(isExpiryDate),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 56, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'Delete Item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete "${widget.item?.name}"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: lightTextColor),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            setState(() {
                              _isLoading = true;
                            });
                            await _inventoryService.deleteItem(widget.householdId, widget.item!.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${widget.item?.name} deleted successfully'),
                                backgroundColor: secondaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting item: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          } finally {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        );
      },
    );
  }
}