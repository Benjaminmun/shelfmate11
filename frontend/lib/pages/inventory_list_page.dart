import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item_model.dart';
import 'inventory_service.dart';
import 'inventory_edit_page.dart';
import 'dart:async';

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
  String _sortField = 'name';
  bool _sortAscending = true;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  List<InventoryItem> _allItems = [];
  bool _hasMoreItems = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _inventoryService.getItemsPaginated(
        widget.householdId,
        lastDocument: _lastDocument,
        limit: 20,
        sortField: _sortField,
        sortAscending: _sortAscending,
      );

      final newItems = result['items'] as List<InventoryItem>;
      final newLastDocument = result['lastDocument'] as DocumentSnapshot?;

      if (newItems.isEmpty) {
        setState(() {
          _hasMoreItems = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _allItems.addAll(newItems);
        _lastDocument = newLastDocument;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more items: $e');
    }
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
    setState(() {
      _lastDocument = null;
      _allItems = [];
      _hasMoreItems = true;
    });
    await _loadMoreItems();
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
                        _refreshData();
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
        _refreshData();
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        iconTheme: IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
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
                      IconButton(
                        icon: Icon(
                          Icons.warning,
                          color: _showLowStockOnly ? Colors.orange : lightTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _showLowStockOnly = !_showLowStockOnly;
                          });
                        },
                        tooltip: 'Show low stock items only',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _showLowStockOnly
                    ? _inventoryService.getLowStockItemsStream(widget.householdId, threshold: 5)
                    : _inventoryService.getItemsStream(widget.householdId, sortField: _sortField, sortAscending: _sortAscending),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState('Error loading inventory: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting && _allItems.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (!snapshot.hasData || (snapshot.data!.docs.isEmpty && _allItems.isEmpty)) {
                    return _showLowStockOnly ? _buildNoLowStockState() : _buildEmptyState();
                  }

                  // Process items
                  List<InventoryItem> items = [];
                  if (_allItems.isEmpty && snapshot.hasData) {
                    items = snapshot.data!.docs.map((doc) {
                      return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    }).toList();
                    _allItems = items;
                    
                    if (snapshot.data!.docs.isNotEmpty) {
                      _lastDocument = snapshot.data!.docs.last;
                    }
                  } else {
                    items = _allItems;
                  }

                  // Filter items based on search query and category
                  final filteredItems = items.where((item) {
                    final matchesSearch = item.name.toLowerCase().contains(_searchQuery) ||
                        (item.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                        (item.category.toLowerCase().contains(_searchQuery));
                    final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
                    final matchesLowStock = !_showLowStockOnly || item.quantity < 5;
                    return matchesSearch && matchesCategory && matchesLowStock;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: filteredItems.length + (_isLoadingMore ? 1 : 0) + (_hasMoreItems ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index == filteredItems.length) {
                        return _isLoadingMore
                            ? _buildLoadingMoreIndicator()
                            : _buildEndOfListIndicator();
                      }
                      
                      if (index > filteredItems.length) {
                        return SizedBox.shrink();
                      }
                      
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
    ).then((_) {
      // Refresh data when returning from edit page
      _refreshData();
    });
  }

  Widget _buildInventoryCard(InventoryItem item, BuildContext context) {
    final bool isLowStock = item.quantity < 5;
    final bool isExpiringSoon = item.expiryDate != null && 
        item.expiryDate!.isAfter(DateTime.now()) &&
        item.expiryDate!.difference(DateTime.now()).inDays <= 7;
    
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
              // Item thumbnail with fallback to icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: item.imageUrl != null ? DecorationImage(
                    image: NetworkImage(item.imageUrl!),
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: item.imageUrl == null 
                    ? Icon(Icons.inventory_2_outlined, color: primaryColor, size: 30)
                    : null,
              ),
              SizedBox(width: 16),
              
              // Item details - This is the main content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
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
                        if (isExpiringSoon)
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
                                  'Expiring Soon',
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
                    SizedBox(height: 8),
                    // Quantity and price in a row with constraints
                    Container(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 16,
                        children: [
                          _buildDetailItem(Icons.format_list_numbered, '${item.quantity} units'),
                          _buildDetailItem(Icons.attach_money, '\$${item.price.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    if (item.expiryDate != null) ...[
                      SizedBox(height: 8),
                      _buildDetailItem(Icons.calendar_today, _formatDate(item.expiryDate!)),
                    ],
                    if (item.location != null) ...[
                      SizedBox(height: 8),
                      _buildDetailItem(Icons.location_on, item.location!),
                    ],
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

  Widget _buildDetailItem(IconData icon, String text) {
    return Container(
      constraints: BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: lightTextColor),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: lightTextColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
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

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      ),
    );
  }

  Widget _buildEndOfListIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'No more items to load',
          style: TextStyle(
            fontSize: 14,
            color: lightTextColor,
            fontStyle: FontStyle.italic,
          ),
        ),
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

  Widget _buildNoLowStockState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: lightTextColor.withOpacity(0.5)),
          SizedBox(height: 16),
          Text(
            'No low stock items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
          ),
          SizedBox(height: 8),
          Text(
            'All items are sufficiently stocked',
            style: TextStyle(fontSize: 14, color: lightTextColor),
          ),
        ],
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
                            _refreshData();
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