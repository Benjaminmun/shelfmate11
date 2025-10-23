import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'add_item_manually.dart'; // Import the separate file

// Initialize cameras list
List<CameraDescription> cameras = [];

// =============================================
// EXPIRY DATE MANAGEMENT & NOTIFICATIONS
// =============================================

class ExpiryDateManager {
  
  // Check if item is expiring soon (within 7 days)
  static bool isExpiringSoon(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    return difference.inDays <= 7 && difference.inDays >= 0;
  }
  
  // Check if item is expired
  static bool isExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return expiryDate.isBefore(DateTime.now());
  }
  
  // Get expiry status color
  static Color getExpiryStatusColor(DateTime? expiryDate) {
    if (expiryDate == null) return Colors.grey; // No expiry date
    
    if (isExpired(expiryDate)) {
      return Colors.red; // Expired
    } else if (isExpiringSoon(expiryDate)) {
      return Colors.orange; // Expiring soon
    } else {
      return Colors.green; // Not expiring soon
    }
  }
  
  // Get expiry status text
  static String getExpiryStatusText(DateTime? expiryDate) {
    if (expiryDate == null) return 'No Expiry';
    
    if (isExpired(expiryDate)) {
      return 'Expired';
    } else if (isExpiringSoon(expiryDate)) {
      final days = expiryDate.difference(DateTime.now()).inDays;
      return 'Expires in $days days';
    } else {
      final days = expiryDate.difference(DateTime.now()).inDays;
      return 'Expires in $days days';
    }
  }
}

// =============================================
// REAL-TIME BARCODE SCANNER - FULL SCREEN
// =============================================

class RealTimeBarcodeScanner extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final VoidCallback onCancel;

  const RealTimeBarcodeScanner({
    Key? key,
    required this.onBarcodeDetected,
    required this.onCancel,
  }) : super(key: key);

  @override
  _RealTimeBarcodeScannerState createState() => _RealTimeBarcodeScannerState();
}

class _RealTimeBarcodeScannerState extends State<RealTimeBarcodeScanner> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _barcodeFound = false;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      final CameraDescription camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      _startPeriodicScanning();
      
    } catch (e) {
      print('❌ Camera initialization error: $e');
      _showErrorSnackBar('Failed to initialize camera: $e');
    }
  }

  void _startPeriodicScanning() {
    _scanTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) async {
      if (!_isProcessing && !_barcodeFound && _isCameraInitialized) {
        await _captureAndScan();
      }
    });
  }

  Future<void> _captureAndScan() async {
    if (_isProcessing || _barcodeFound || !_isCameraInitialized) return;

    setState(() => _isProcessing = true);

    try {
      if (_cameraController.value.isTakingPicture) return;
      
      final XFile imageFile = await _cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty && !_barcodeFound) {
        final String barcode = barcodes.first.rawValue ?? '';
        if (barcode.isNotEmpty) {
          setState(() => _barcodeFound = true);
          _scanTimer?.cancel();
          widget.onBarcodeDetected(barcode);
        }
      }
    
      
    } catch (e) {
      print('❌ Barcode scanning error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen camera preview
          if (_isCameraInitialized)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_cameraController),
            )
          else
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Scanner overlay - centered with transparent cutout
          _buildScannerOverlay(),

          // Close button - positioned in top left with safe area
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: widget.onCancel,
              ),
            ),
          ),

          // Status indicator - positioned at bottom center
          if (_isProcessing)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Scanning...',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_barcodeFound)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Barcode Found!',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instructions - positioned at bottom with safe area
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Position barcode within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    final size = MediaQuery.of(context).size;
    final scannerSize = size.width * 0.7;

    return Stack(
      children: [
        // Semi-transparent overlay
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              // Transparent cutout for scanner area
              Center(
                child: Container(
                  width: scannerSize,
                  height: scannerSize * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanner frame and animation
        Center(
          child: Container(
            width: scannerSize,
            height: scannerSize * 0.6,
            decoration: BoxDecoration(
              border: Border.all(
                color: _barcodeFound ? Colors.green : Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                isScanning: !_barcodeFound,
                scannerHeight: scannerSize * 0.6,
              ),
            ),
          ),
        ),

        // Corner accents
        Center(
          child: Container(
            width: scannerSize,
            height: scannerSize * 0.6,
            child: CustomPaint(
              painter: ScannerCornersPainter(
                color: _barcodeFound ? Colors.green : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final bool isScanning;
  final double scannerHeight;

  ScannerOverlayPainter({required this.isScanning, required this.scannerHeight});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw scanning line
    if (isScanning) {
      final scanningPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final lineY = (DateTime.now().millisecondsSinceEpoch / 20) % scannerHeight;
      canvas.drawLine(
        Offset(0, lineY),
        Offset(size.width, lineY),
        scanningPaint,
      );

      // Add a glow effect to the scanning line
      final glowPaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..strokeWidth = 8;

      canvas.drawLine(
        Offset(0, lineY),
        Offset(size.width, lineY),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isScanning != isScanning;
  }
}

class ScannerCornersPainter extends CustomPainter {
  final Color color;

  ScannerCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style; PaintingStyle.stroke;

    final cornerLength = 25.0;


    // Top-left corner
    canvas.drawLine(Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCornersPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// =============================================
// INVENTORY LIST ITEM WIDGET WITH EXPIRY STATUS
// =============================================

class InventoryListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final bool isReadOnly;

  const InventoryListItem({
    Key? key,
    required this.item,
    required this.onTap,
    this.onEdit,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateTime? expiryDate = item['expiryDate'] != null 
        ? (item['expiryDate'] as Timestamp).toDate() 
        : null;
    
    final Color statusColor = ExpiryDateManager.getExpiryStatusColor(expiryDate);
    final String statusText = ExpiryDateManager.getExpiryStatusText(expiryDate);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: _buildItemLeading(expiryDate, statusColor),
        title: Text(
          item['name'] ?? 'Unknown Item',
          style: TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: ${item['quantity'] ?? 1}'),
            if (item['location'] != null && item['location'].isNotEmpty)
              Text('Location: ${item['location']}'),
            if (expiryDate != null)
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: isReadOnly ? null : IconButton(
          icon: Icon(Icons.edit, color: Colors.grey),
          onPressed: onEdit,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildItemLeading(DateTime? expiryDate, Color statusColor) {
    if (expiryDate == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.inventory_2, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.inventory_2, color: statusColor),
        ),
        if (ExpiryDateManager.isExpired(expiryDate) || 
            ExpiryDateManager.isExpiringSoon(expiryDate))
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================
// MAIN ADD ITEM PAGE WITH SIMPLE FADE IN ANIMATION
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

class _AddItemPageState extends State<AddItemPage> with SingleTickerProviderStateMixin {
  bool _isAddingToHousehold = false;
  bool _isFetchingFromAPI = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Fixed categories
  final List<String> _fixedCategories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other'
  ];

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

  @override
  void initState() {
    super.initState();
    
    // Initialize simple fade animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500), // Shorter duration for fade
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Updated scan method using real-time scanner
  Future<void> _scanBarcode() async {
    if (widget.isReadOnly) return;
    
    try {
      // Show real-time barcode scanner
      final String? barcode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RealTimeBarcodeScanner(
            onBarcodeDetected: (detectedBarcode) {
              Navigator.pop(context, detectedBarcode);
            },
            onCancel: () {
              Navigator.pop(context, null);
            },
          ),
        ),
      );

      if (barcode != null && barcode.isNotEmpty) {
        await _checkBarcodeInFirestore(barcode);
      } else if (barcode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode scanning cancelled'),
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
          content: Text('Error during scanning: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Category mapping function
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

  // Enhanced caching with timestamp checking
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
        
        // Check if cache is fresh (less than 30 days old)
        if (lastUpdated != null) {
          final DateTime updateTime = lastUpdated.toDate();
          final Duration difference = now.difference(updateTime);
          
          if (difference.inDays < 30) {
            // Use cached data (fresh)
            print('🔄 Using cached product data for barcode: $barcode');
            _showProductDetails(productData, barcode);
            return;
          } else {
            // Cache is stale, fetch fresh data
            print('🔄 Cached data is stale, fetching fresh data for: $barcode');
            await _fetchFromOpenFoodFacts(barcode);
            return;
          }
        }
        
        // No timestamp, use cached data but mark as potentially stale
        print('🔄 Using cached product data (no timestamp) for barcode: $barcode');
        _showProductDetails(productData, barcode);
      } else {
        // Product not found in Firestore, try OpenFoodFacts API
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

  // Enhanced API fetching with automatic navigation
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
          // Product found in OpenFoodFacts
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
          // Product not found in OpenFoodFacts - AUTO NAVIGATE TO EDIT PAGE
          print('🔍 Product not found in OpenFoodFacts, navigating to edit page');
          _autoNavigateToEditPageWithBarcode(barcode);
        }
      } else {
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // Network error - try to use cached data if available
      print('🌐 Network error: $e');
      await _tryUseCachedDataOrNavigate(barcode);
    } on TimeoutException catch (e) {
      // Timeout - try to use cached data if available
      print('⏰ API timeout: $e');
      await _tryUseCachedDataOrNavigate(barcode);
    } catch (e) {
      print('❌ Error fetching from OpenFoodFacts: $e');
      await _tryUseCachedDataOrNavigate(barcode);
    } finally {
      setState(() => _isFetchingFromAPI = false);
    }
  }

  // Updated fallback method that navigates to edit page when no cached data
  Future<void> _tryUseCachedDataOrNavigate(String barcode) async {
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
        // No cached data available - AUTO NAVIGATE TO EDIT PAGE
        print('🔍 No cached data found, navigating to edit page');
        _autoNavigateToEditPageWithBarcode(barcode);
      }
    } catch (e) {
      // Any error - AUTO NAVIGATE TO EDIT PAGE
      print('❌ Error accessing cache, navigating to edit page: $e');
      _autoNavigateToEditPageWithBarcode(barcode);
    }
  }

  // New method for automatic navigation to edit page
  void _autoNavigateToEditPageWithBarcode(String barcode) {
    if (widget.isReadOnly) return;
    
    // Close any open dialogs first
    Navigator.popUntil(context, (route) => route is! PopupRoute);
    
    // Show a brief snackbar message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📝 Product not found. Please enter details manually.'),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Navigate to edit page after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      _navigateToEditPageWithBarcode(barcode);
    });
  }

  // Category mapping applied with enhanced data
  Map<String, dynamic> _parseOpenFoodFactsData(Map<String, dynamic> product, String barcode) {
    String openFoodFactsCategory = _getCategory(product['categories'] ?? 'Uncategorized');
    String mappedCategory = _mapToFixedCategory(openFoodFactsCategory);

    return {
      'name': product['product_name'] ?? 'Unknown Product',
      'brand': product['brands'] ?? 'Unknown Brand',
      'category': mappedCategory, // fixed category
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
      'lastUpdated': FieldValue.serverTimestamp(), // Cache timestamp
      'fetchCount': FieldValue.increment(1), // Track how many times fetched
    };
  }

  String _getCategory(String categories) {
    // Take the first category if multiple are provided
    if (categories.contains(',')) {
      return categories.split(',').first.trim();
    }
    return categories.trim();
  }

  // Enhanced product saving with merge
  Future<void> _saveProductToFirestore(String barcode, Map<String, dynamic> productData) async {
    try {
      // Merge data to preserve existing fields while updating new ones
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
    
    // Show cache indicator
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

  // Category validation before saving
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

      // VALIDATE CATEGORY: Ensure it's one of the fixed categories
      String finalCategory = product['category'] ?? 'Other';
      if (!_fixedCategories.contains(finalCategory)) {
        finalCategory = 'Other';
      }

      // Create inventory item with product reference
      final inventoryData = {
        'barcode': barcode,
        'productRef': _firestore.collection('products').doc(barcode),
        'name': product['name'] ?? 'Unknown Product',
        'category': finalCategory, // guaranteed safe category
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
        'hasExpiryDate': false, // Default to no expiry date
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
        builder: (context) => AddItemManually(
          householdId: widget.householdId,
          householdName: widget.householdName,
          userRole: widget.isReadOnly ? 'member' : 'creator',
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
        builder: (context) => AddItemManually(
          householdId: widget.householdId,
          householdName: widget.householdName,
          userRole: widget.isReadOnly ? 'member' : 'creator',
          barcode: barcode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            // Enhanced App Bar with better visual hierarchy
            SliverAppBar(
              automaticallyImplyLeading: false, // Disable the default back button
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: widget.isReadOnly ? disabledColor : primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 20, bottom: 16, right: 20),
                title: Row(
                  children: [
                    // Title and subtitle (without the back button)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isReadOnly ? 'View Item Options' : 'Add New Item',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            widget.householdName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.isReadOnly ? disabledColor : primaryColor,
                        widget.isReadOnly ? Color(0xFFBDBDBD) : Color(0xFF5A8BA8),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 40,
                        bottom: -30,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card with improved design
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 24),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isReadOnly 
                            ? [disabledColor.withOpacity(0.9), disabledColor.withOpacity(0.7)] 
                            : [primaryColor.withOpacity(0.9), Color(0xFF5A8BA8).withOpacity(0.8)],
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
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isReadOnly ? Icons.visibility : Icons.add_circle_outline, 
                              color: Colors.white, 
                              size: 30
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isReadOnly ? 'View Inventory Options' : 'Add to Inventory',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  widget.isReadOnly 
                                    ? 'Browse item addition options in read-only mode' 
                                    : 'Choose your preferred method to add items to your household inventory',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.4,
                                  ),
                                ),
                                if (!widget.isReadOnly) SizedBox(height: 6),
                                if (!widget.isReadOnly)
                                  Wrap(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Smart Caching',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Fast Lookup',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
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

                    // Options Grid with improved layout
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.60,
                      children: [
                        _buildEnhancedOptionCard(
                          title: 'Scan Barcode',
                          icon: Icons.qr_code_scanner_rounded,
                          description: widget.isReadOnly 
                            ? 'Scan product barcode (read-only)' 
                            : 'Real-time barcode scanning with camera',
                          gradientColors: widget.isReadOnly 
                            ? [disabledColor, Color(0xFFBDBDBD)]
                            : [Color(0xFF2D5D7C), Color(0xFF4CAF50)],
                          onTap: widget.isReadOnly ? null : _scanBarcode,
                          isLoading: _isFetchingFromAPI,
                          isReadOnly: widget.isReadOnly,
                          showApiStatus: _isFetchingFromAPI,
                          badgeText: 'FAST',
                        ),
                        _buildEnhancedOptionCard(
                          title: 'Add Manually',
                          icon: Icons.edit_note_rounded,
                          description: widget.isReadOnly 
                            ? 'View manual entry options (read-only)' 
                            : 'Add new product manually with custom details',
                          gradientColors: widget.isReadOnly 
                            ? [disabledColor, Color(0xFFBDBDBD)]
                            : [Color(0xFF2D5D7C), Color(0xFFFF9800)],
                          onTap: widget.isReadOnly ? null : _navigateToEditPage,
                          isReadOnly: widget.isReadOnly,
                          badgeText: 'FLEXIBLE',
                        ),
                      ],
                    ),

                    // Additional Information Section
                    if (!widget.isReadOnly)
                      Container(
                        margin: EdgeInsets.only(top: 24),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: primaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildFeatureRow(
                              'Smart Caching',
                              'Products are cached for 30 days for faster access',
                              Icons.cached,
                            ),
                            SizedBox(height: 8),
                            _buildFeatureRow(
                              'Auto Category Mapping',
                              'Categories are automatically mapped for consistency',
                              Icons.category,
                            ),
                            SizedBox(height: 8),
                            _buildFeatureRow(
                              'Offline Support',
                              'Works with cached data when offline',
                              Icons.wifi_off,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedOptionCard({
    required String title,
    required IconData icon,
    required String description,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isReadOnly = false,
    bool showApiStatus = false,
    String? badgeText,
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
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon with background
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: isLoading
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 3,
                                      ),
                                      Icon(
                                        icon,
                                        size: 24,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ],
                                  )
                                : Icon(
                                    icon,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                          ),
                          SizedBox(height: 16),
                          
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          // Description
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          // Status indicators
                          if (showApiStatus) ...[
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Fetching data...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          if (isReadOnly) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Read-only',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      // Badge
                      if (badgeText != null && !isReadOnly)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: primaryColor),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: lightTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}