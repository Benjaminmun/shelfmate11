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
          const SnackBar(content: Text('No barcode found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: $e')),
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
            const SnackBar(content: Text('Product not found')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching product info: $e')),
      );
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['product_name']?.toString() ?? 'Unknown Product'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product['image_url'] != null)
                Image.network(product['image_url'].toString()),
              const SizedBox(height: 12),
              Text('Brand: ${product['brands']?.toString() ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Quantity: ${product['quantity']?.toString() ?? 'N/A'}'),
              const SizedBox(height: 8),
              if (product['categories'] != null)
                Text('Category: ${product['categories']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save to Firestore with widget.householdId
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added to household')),
              );
            },
            child: const Text('Add to Household'),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Add Item'),
        backgroundColor: const Color(0xFF2D5D7C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOptionCard(
              title: 'Scan Barcode',
              icon: Icons.qr_code_scanner,
              description: 'Scan product barcode to quickly add items',
              onTap: _isScanning ? null : _scanBarcode,
              isLoading: _isScanning,
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              title: 'Add Manually',
              icon: Icons.edit,
              description: 'Enter item details manually',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual entry form')),
                );
              },
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (isLoading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 48, color: const Color(0xFF2D5D7C)),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
