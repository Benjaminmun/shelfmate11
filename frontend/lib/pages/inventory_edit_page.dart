// inventory_edit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'inventory_item_model.dart';
import 'inventory_service.dart';

class InventoryEditPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final InventoryItem? item;

  const InventoryEditPage({
    Key? key,
    required this.householdId,
    required this.householdName,
    this.item,
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
    'Electronics',
    'Clothing',
    'Furniture',
    'Medication',
    'Office Supplies',
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

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing item data or empty values
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _categoryController = TextEditingController(text: widget.item?.category ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '1');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '0.00');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
    _locationController = TextEditingController(text: widget.item?.location ?? '');
    _supplierController = TextEditingController(text: widget.item?.supplier ?? '');
    _barcodeController = TextEditingController(text: widget.item?.barcode ?? '');
    _minStockLevelController = TextEditingController(text: widget.item?.minStockLevel?.toString() ?? '');
    
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
        createdAt: widget.item?.createdAt,
      );

      if (widget.item?.id == null) {
        // Add new item
        await _inventoryService.addItem(widget.householdId, item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing item
        await _inventoryService.updateItem(widget.householdId, item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $e'),
          backgroundColor: Colors.red,
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
      initialDate: isExpiryDate ? (_expiryDate ?? DateTime.now()) : (_purchaseDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item?.id == null ? 'Add New Item' : 'Edit ${widget.item?.name}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFF2D5D7C),
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (widget.item?.id != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                _showDeleteDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(_nameController, 'Item Name', Icons.inventory, true,
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
                          child: _buildTextField(_quantityController, 'Quantity', Icons.format_list_numbered, true,
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
                          }),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(_priceController, 'Price', Icons.attach_money, true,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                    _buildTextField(_minStockLevelController, 'Minimum Stock Level (optional)', Icons.warning, false,
                        keyboardType: TextInputType.numberWithOptions(decimal: true)),
                    SizedBox(height: 24),
                    Text(
                      'Additional Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(_descriptionController, 'Description (optional)', Icons.description, false,
                        maxLines: 3),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField('Purchase Date (optional)', _purchaseDate, false),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildDateField('Expiry Date (optional)', _expiryDate, true),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildTextField(_locationController, 'Storage Location (optional)', Icons.location_on, false),
                    SizedBox(height: 16),
                    _buildTextField(_supplierController, 'Supplier (optional)', Icons.business, false),
                    SizedBox(height: 16),
                    _buildTextField(_barcodeController, 'Barcode/SKU (optional)', Icons.qr_code, false,
                        keyboardType: TextInputType.number),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          widget.item?.id == null ? 'Add Item' : 'Update Item',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isRequired,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
      decoration: InputDecoration(
        labelText: 'Category *',
        prefixIcon: Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
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
    );
  }

  Widget _buildDateField(String label, DateTime? date, bool isExpiryDate) {
    return InkWell(
      onTap: () => _selectDate(context, isExpiryDate),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Select date',
              style: TextStyle(fontSize: 16),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text('Are you sure you want to delete ${widget.item?.name}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _inventoryService.deleteItem(widget.householdId, widget.item!.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.item?.name} deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting item: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}