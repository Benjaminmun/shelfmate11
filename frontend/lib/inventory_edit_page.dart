import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();
  final InventoryService _inventoryService = InventoryService();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);

  // Form fields
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    // If editing an existing item, populate the form
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _categoryController.text = widget.item!.category;
      _quantityController.text = widget.item!.quantity.toString();
      _priceController.text = widget.item!.price.toString();
      _descriptionController.text = widget.item!.description;
      _expiryDate = widget.item!.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(_nameController, 'Item Name', Icons.inventory, TextInputType.text),
              SizedBox(height: 16),
              _buildTextField(_categoryController, 'Category', Icons.category, TextInputType.text),
              SizedBox(height: 16),
              _buildTextField(_quantityController, 'Quantity', Icons.format_list_numbered, TextInputType.number),
              SizedBox(height: 16),
              _buildTextField(_priceController, 'Price', Icons.attach_money, TextInputType.numberWithOptions(decimal: true)),
              SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Description', Icons.description, TextInputType.multiline, maxLines: 3),
              SizedBox(height: 16),
              _buildDateField(),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.item == null ? 'Add Item' : 'Update Item',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType keyboardType, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label == 'Quantity' && int.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        if (label == 'Price' && double.tryParse(value) == null) {
          return 'Please enter a valid price';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expiry Date (optional)',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _expiryDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (picked != null && picked != _expiryDate) {
              setState(() {
                _expiryDate = picked;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: primaryColor),
                SizedBox(width: 16),
                Text(
                  _expiryDate != null
                      ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                      : 'Select expiry date',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        if (_expiryDate != null)
          TextButton(
            onPressed: () {
              setState(() {
                _expiryDate = null;
              });
            },
            child: Text('Clear date', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  void _saveItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        final item = InventoryItem(
          id: widget.item?.id,
          name: _nameController.text,
          category: _categoryController.text,
          quantity: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          description: _descriptionController.text,
          expiryDate: _expiryDate,
          createdAt: widget.item?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (widget.item == null) {
          await _inventoryService.addItem(widget.householdId, item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
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
      }
    }
  }
}