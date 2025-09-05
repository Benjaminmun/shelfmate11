import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AddItemPage extends StatefulWidget {
  final String householdId;

  const AddItemPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  String _scanResult = '';
  bool _isScanning = false;
  final ImagePicker _picker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  // Using the same color scheme as DashboardPage
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color backgroundColor = Color(0xFFF8FAFC);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color lightTextColor = Color(0xFF64748B);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);

  Future<void> _scanBarcode() async {
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
        _fetchProductInfo(barcodeValue);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No barcode found'),
            backgroundColor: primaryColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: $e'),
          backgroundColor: primaryColor,
        ),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _fetchProductInfo(String barcode) async {
    final url =
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          _showProductDetails(product);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product not found'),
              backgroundColor: primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching product info: $e'),
          backgroundColor: primaryColor,
        ),
      );
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          product['product_name']?.toString() ?? 'Unknown Product',
          style: TextStyle(color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product['image_url'] != null)
                Image.network(product['image_url'].toString()),
              const SizedBox(height: 12),
              Text(
                'Brand: ${product['brands']?.toString() ?? 'Unknown'}',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Quantity: ${product['quantity']?.toString() ?? 'N/A'}',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 8),
              if (product['categories'] != null)
                Text(
                  'Category: ${product['categories']}',
                  style: TextStyle(color: textColor),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: lightTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save to Firestore with widget.householdId
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Item added to household'),
                  backgroundColor: primaryColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            child: Text('Add to Household'),
          ),
        ],
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
          'Add Item',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, Color(0xFF5A8BA8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
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
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Scan barcode or add manually',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Options
            Expanded(
              child: Column(
                children: [
                  _buildOptionCard(
                    title: 'Scan Barcode',
                    icon: Icons.qr_code_scanner,
                    description: 'Scan product barcode to quickly add items',
                    onTap: _isScanning ? null : _scanBarcode,
                    isLoading: _isScanning,
                  ),
                  SizedBox(height: 20),
                  _buildOptionCard(
                    title: 'Add Manually',
                    icon: Icons.edit,
                    description: 'Enter item details manually',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Manual entry form'),
                          backgroundColor: primaryColor,
                        ),
                      );
                    },
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
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon, 
                    size: 30, 
                    color: primaryColor
                  ),
                ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: lightTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}