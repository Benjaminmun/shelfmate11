import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/inventory_item_model.dart';
import '../../services/inventory_service.dart';
import 'inventory_edit_page.dart';
import 'dart:async';

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
      final days = DateTime.now().difference(expiryDate).inDays;
      return 'Expired ${days == 0 ? 'today' : '$days days ago'}';
    } else if (isExpiringSoon(expiryDate)) {
      final days = expiryDate.difference(DateTime.now()).inDays;
      return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
    } else {
      final days = expiryDate.difference(DateTime.now()).inDays;
      return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
    }
  }

  // Get days until expiry
  static int? getDaysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) {
      return -now.difference(expiryDate).inDays;
    }
    return expiryDate.difference(now).inDays;
  }
}

class InventoryListPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final bool isReadOnly;

  const InventoryListPage({
    Key? key,
    required this.householdId,
    required this.householdName,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  _InventoryListPageState createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final InventoryService _inventoryService = InventoryService();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF4CAF50);
  final Color accentColor = Color(0xFFFF9800);
  final Color backgroundColor = Color(0xFFF5F7F9);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF333333);
  final Color lightTextColor = Color(0xFF666666);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  bool _showLowStockOnly = false;
  bool _showExpiringSoonOnly = false;
  String _sortField = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _inventoryService.getCategories(widget.householdId);
      setState(() {
        _categories = ['All', ...categories];
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadCategories();
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16),
              _buildSortOption('Name', 'name'),
              _buildSortOption('Quantity', 'quantity'),
              _buildSortOption('Price', 'price'),
              _buildSortOption('Expiry Date', 'expiryDate'),
              _buildSortOption('Category', 'category'),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _sortAscending ? 'Ascending' : 'Descending',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Apply'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, String field) {
    return ListTile(
      leading: Icon(
        _sortField == field ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: _sortField == field ? primaryColor : lightTextColor,
      ),
      title: Text(title),
      onTap: () {
        setState(() {
          _sortField = field;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Show Low Stock Only'),
                subtitle: Text('Items with quantity less than 5'),
                value: _showLowStockOnly,
                onChanged: (value) {
                  setState(() {
                    _showLowStockOnly = value;
                    if (value) _showExpiringSoonOnly = false;
                  });
                  Navigator.pop(context);
                },
              ),
              SwitchListTile(
                title: Text('Show Expiring Soon Only'),
                subtitle: Text('Items expiring within 7 days'),
                value: _showExpiringSoonOnly,
                onChanged: (value) {
                  setState(() {
                    _showExpiringSoonOnly = value;
                    if (value) _showLowStockOnly = false;
                  });
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: Text(
          '${widget.householdName} Inventory',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
            tooltip: 'Filter items',
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort items',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh inventory',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryColor,
        child: Column(
          children: [
            // Search and filter section
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: Icon(Icons.search, color: lightTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((category) {
                              return Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.category,
                                        size: 16,
                                        color: _selectedCategory == category ? Colors.white : primaryColor,
                                      ),
                                      SizedBox(width: 4),
                                      Text(category),
                                    ],
                                  ),
                                  selected: _selectedCategory == category,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory = selected ? category : 'All';
                                    });
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: primaryColor,
                                  labelStyle: TextStyle(
                                    color: _selectedCategory == category ? Colors.white : lightTextColor,
                                    fontWeight: _selectedCategory == category ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: _selectedCategory == category ? primaryColor : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (_showLowStockOnly || _showExpiringSoonOnly)
                        IconButton(
                          icon: Icon(
                            Icons.filter_alt,
                            color: Colors.orange,
                          ),
                          onPressed: _showFilterOptions,
                          tooltip: 'Active filters',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Active filters indicator
            if (_showLowStockOnly || _showExpiringSoonOnly)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _showLowStockOnly && _showExpiringSoonOnly
                            ? 'Showing: Low Stock & Expiring Soon'
                            : _showLowStockOnly
                                ? 'Showing: Low Stock Only'
                                : 'Showing: Expiring Soon Only',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLowStockOnly = false;
                          _showExpiringSoonOnly = false;
                        });
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _inventoryService.getItemsStream(
                  widget.householdId, 
                  sortField: _sortField, 
                  sortAscending: _sortAscending
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState('Error loading inventory: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Process items directly from the stream
                  List<InventoryItem> items = snapshot.data!.docs.map((doc) {
                    return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  }).toList();

                  // Filter items based on search query, category, and active filters
                  final filteredItems = items.where((item) {
                    final matchesSearch = item.name.toLowerCase().contains(_searchQuery) ||
                        (item.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (item.category.toLowerCase().contains(_searchQuery));
                    final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
                    final matchesLowStock = !_showLowStockOnly || item.quantity < 5;
                    final matchesExpiringSoon = !_showExpiringSoonOnly || 
                        (item.expiryDate != null && ExpiryDateManager.isExpiringSoon(item.expiryDate));
                    
                    return matchesSearch && matchesCategory && matchesLowStock && matchesExpiringSoon;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      var item = filteredItems[index];
                      return _buildInventoryCard(item, context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Only show FAB if not in read-only mode
      floatingActionButton: widget.isReadOnly 
          ? null 
          : FloatingActionButton(
              onPressed: () {
                _navigateToEditPage();
              },
              backgroundColor: secondaryColor,
              child: Icon(Icons.add, color: Colors.white, size: 28),
              elevation: 4,
              tooltip: 'Add new item',
            ),
    );
  }

  void _navigateToEditPage({InventoryItem? item}) {
    // Don't navigate if in read-only mode
    if (widget.isReadOnly) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryEditPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          item: item,
          userRole: 'creator',
        ),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, BuildContext context) {
    final bool isLowStock = item.quantity < 5;
    final bool hasExpiryDate = item.expiryDate != null;
    final Color expiryStatusColor = ExpiryDateManager.getExpiryStatusColor(item.expiryDate);
    final String expiryStatusText = ExpiryDateManager.getExpiryStatusText(item.expiryDate);
    final bool isExpired = ExpiryDateManager.isExpired(item.expiryDate);
    final bool isExpiringSoon = ExpiryDateManager.isExpiringSoon(item.expiryDate);
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.isReadOnly 
            ? null // Disable tap in read-only mode
            : () {
                _navigateToEditPage(item: item);
              },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item thumbnail with expiry status indicator
              Stack(
                children: [
                  _buildItemThumbnail(item),
                  if (hasExpiryDate && (isExpired || isExpiringSoon))
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: expiryStatusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          isExpired ? Icons.error : Icons.warning,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              
              // Item details - This is the main content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name and expiry status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasExpiryDate)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: expiryStatusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: expiryStatusColor, width: 1),
                            ),
                            child: Text(
                              expiryStatusText,
                              style: TextStyle(
                                fontSize: 10,
                                color: expiryStatusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Category and status chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isLowStock) 
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, size: 14, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Low Stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isExpired)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 14, color: Colors.red),
                                SizedBox(width: 4),
                                Text(
                                  'Expired',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    
                    // Item details in a compact layout
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quantity and price
                        Row(
                          children: [
                            _buildDetailItem(Icons.format_list_numbered, '${item.quantity} units'),
                            SizedBox(width: 16),
                            _buildDetailItem(Icons.attach_money, 'RM ${item.price.toStringAsFixed(2)}'),
                          ],
                        ),
                        SizedBox(height: 8),
                        
                        // Expiry date with color coding
                        if (hasExpiryDate)
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: expiryStatusColor),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatDate(item.expiryDate!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: expiryStatusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'No expiry date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        
                        // Location
                        if (item.location != null && item.location!.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: lightTextColor),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.location!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: lightTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action buttons - Only show if not in read-only mode
              if (!widget.isReadOnly) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: primaryColor),
                      onPressed: () {
                        _navigateToEditPage(item: item);
                      },
                      tooltip: 'Edit item',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteDialog(item);
                      },
                      tooltip: 'Delete item',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(InventoryItem item) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildItemImage(item),
      ),
    );
  }

  Widget _buildItemImage(InventoryItem item) {
    // Priority: localImagePath > imageUrl > default icon
    if (item.localImagePath != null && item.localImagePath!.isNotEmpty) {
      return Image.file(
        File(item.localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon();
        },
      );
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return Image.network(
        item.imageUrl!,
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
          return _buildDefaultIcon();
        },
      );
    } else {
      return _buildDefaultIcon();
    }
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(Icons.inventory_2_outlined, color: primaryColor, size: 30),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: lightTextColor),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: lightTextColor),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading inventory...',
            style: TextStyle(fontSize: 16, color: lightTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: lightTextColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _refreshData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: lightTextColor.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              'No inventory items yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textColor),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first item to get started',
              style: TextStyle(fontSize: 16, color: lightTextColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            // Only show the button if not in read-only mode
            if (!widget.isReadOnly) ...[
              ElevatedButton(
                onPressed: () {
                  _navigateToEditPage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  'Add First Item',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: lightTextColor.withOpacity(0.5)),
          SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(fontSize: 14, color: lightTextColor),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedCategory = 'All';
                _showLowStockOnly = false;
                _showExpiringSoonOnly = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(InventoryItem item) {
    // Don't show delete dialog in read-only mode
    if (widget.isReadOnly) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'Delete Item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete "${item.name}"?',
                  style: TextStyle(fontSize: 16, color: lightTextColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: primaryColor)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            await _inventoryService.deleteItem(widget.householdId, item.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${item.name}" deleted successfully'),
                                backgroundColor: secondaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting item: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Delete', style: TextStyle(color: Colors.white)),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}