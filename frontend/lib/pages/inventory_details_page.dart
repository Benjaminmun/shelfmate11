import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item_model.dart';

class InventoryDetailsPage extends StatefulWidget {
  final InventoryItem item;
  final String householdName;
  final String userRole;

  const InventoryDetailsPage({
    Key? key,
    required this.item,
    required this.householdName,
    required this.userRole,
  }) : super(key: key);

  @override
  _InventoryDetailsPageState createState() => _InventoryDetailsPageState();
}

class _InventoryDetailsPageState extends State<InventoryDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Enhanced Color scheme (consistent with edit page)
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
  final Color lowStockColor = Color(0xFFFF6B35);
  final Color expiredColor = Color(0xFFE74C3C);

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
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isLowStock {
    return widget.item.minStockLevel != null && 
           widget.item.quantity <= widget.item.minStockLevel!;
  }

  bool get _isExpired {
    return widget.item.expiryDate != null && 
           widget.item.expiryDate!.isBefore(DateTime.now());
  }

  bool get _isExpiringSoon {
    if (widget.item.expiryDate == null) return false;
    final now = DateTime.now();
    final difference = widget.item.expiryDate!.difference(now);
    return difference.inDays <= 7 && difference.inDays >= 0;
  }

  Widget _buildHeader() {
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
                // Status badges
                if (_isExpired)
                  _buildStatusBadge('Expired', expiredColor)
                else if (_isExpiringSoon)
                  _buildStatusBadge('Expiring Soon', warningColor)
                else if (_isLowStock)
                  _buildStatusBadge('Low Stock', lowStockColor)
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Item Details',
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
                    '${widget.item.quantity} in stock',
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

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(left: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

  Widget _buildDetailRow(String label, String value, {IconData? icon, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: lightTextColor, size: 20),
            SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: lightTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Not specified',
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? textColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
            color: lightTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        
        if (widget.item.localImagePath != null || widget.item.imageUrl != null)
          _buildImagePreview()
        else
          _buildImagePlaceholder(),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: lightTextColor,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No Image Available',
            style: TextStyle(
              color: lightTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          child: widget.item.localImagePath != null
              ? Image.file(
                  File(widget.item.localImagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImageError();
                  },
                )
              : widget.item.imageUrl != null
                  ? Image.network(
                      widget.item.imageUrl!,
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

  void _previewImage() {
    if (widget.item.localImagePath == null && widget.item.imageUrl == null) return;

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
                        child: widget.item.localImagePath != null
                            ? Image.file(
                                File(widget.item.localImagePath!),
                                fit: BoxFit.contain,
                              )
                            : widget.item.imageUrl != null
                                ? Image.network(
                                    widget.item.imageUrl!,
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

  Widget _buildStockStatusCard() {
    Color statusColor = successColor;
    String statusText = 'In Stock';
    String statusDescription = 'Item stock level is good';

    if (_isExpired) {
      statusColor = expiredColor;
      statusText = 'Expired';
      statusDescription = 'This item has expired';
    } else if (_isExpiringSoon) {
      statusColor = warningColor;
      statusText = 'Expiring Soon';
      statusDescription = 'This item will expire within 7 days';
    } else if (_isLowStock) {
      statusColor = lowStockColor;
      statusText = 'Low Stock';
      statusDescription = 'Stock level is below minimum threshold';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isExpired ? Icons.error_outline : 
              _isExpiringSoon ? Icons.warning_amber_rounded :
              _isLowStock ? Icons.inventory_2_outlined : Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: lightTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stock Status Card
                      if (_isExpired || _isExpiringSoon || _isLowStock)
                        Column(
                          children: [
                            _buildStockStatusCard(),
                            SizedBox(height: 20),
                          ],
                        ),

                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.inventory_2_outlined,
                        children: [
                          _buildDetailRow('Item Name', widget.item.name, icon: Icons.label_outline),
                          _buildDetailRow('Category', widget.item.category, icon: Icons.category_outlined),
                          _buildDetailRow('Quantity', '${widget.item.quantity}', icon: Icons.format_list_numbered),
                          _buildDetailRow('Price', '\$${widget.item.price.toStringAsFixed(2)}', icon: Icons.attach_money),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      _buildSectionCard(
                        title: 'Media',
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
                          _buildDetailRow(
                            'Current Stock', 
                            '${widget.item.quantity}',
                            icon: Icons.inventory_2_outlined,
                            valueColor: _isLowStock ? lowStockColor : null,
                          ),
                          _buildDetailRow(
                            'Minimum Stock Level', 
                            widget.item.minStockLevel?.toString() ?? 'Not set',
                            icon: Icons.warning_amber,
                          ),
                          _buildDetailRow(
                            'Barcode', 
                            widget.item.barcode ?? 'Not set',
                            icon: Icons.qr_code,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      _buildSectionCard(
                        title: 'Additional Details',
                        icon: Icons.description_outlined,
                        children: [
                          _buildDetailRow(
                            'Description', 
                            widget.item.description ?? 'Not provided',
                            icon: Icons.notes,
                          ),
                          _buildDetailRow(
                            'Purchase Date', 
                            widget.item.purchaseDate != null 
                                ? DateFormat('MMM dd, yyyy').format(widget.item.purchaseDate!)
                                : 'Not set',
                            icon: Icons.calendar_today_outlined,
                          ),
                          _buildDetailRow(
                            'Expiry Date', 
                            widget.item.expiryDate != null 
                                ? DateFormat('MMM dd, yyyy').format(widget.item.expiryDate!)
                                : 'Not set',
                            icon: Icons.event_busy_outlined,
                            valueColor: _isExpired ? expiredColor : _isExpiringSoon ? warningColor : null,
                          ),
                          _buildDetailRow(
                            'Storage Location', 
                            widget.item.location ?? 'Not specified',
                            icon: Icons.location_on_outlined,
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      _buildSectionCard(
                        title: 'System Information',
                        icon: Icons.info_outline,
                        children: [
                          _buildDetailRow(
                            'Created', 
                            DateFormat('MMM dd, yyyy - HH:mm').format(widget.item.createdAt),
                            icon: Icons.add_circle_outline,
                          ),
                          if (widget.item.updatedAt != null)
                            _buildDetailRow(
                              'Last Updated', 
                              DateFormat('MMM dd, yyyy - HH:mm').format(widget.item.updatedAt!),
                              icon: Icons.update,
                            ),
                        ],
                      ),
                      
                      SizedBox(height: 32),
                    ],
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