// inventory_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item_model.dart';
import 'inventory_service.dart';
import 'inventory_edit_page.dart';

class InventoryListPage extends StatefulWidget {
  final String householdId;
  final String householdName;

  const InventoryListPage({Key? key, required this.householdId, required this.householdName}) : super(key: key);

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

  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
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
                                label: Text(category),
                                selected: _selectedCategory == category,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = selected ? category : 'All';
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: primaryColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: _selectedCategory == category ? primaryColor : lightTextColor,
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
                  : _inventoryService.getItemsStream(widget.householdId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState('Error loading inventory: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _showLowStockOnly ? _buildNoLowStockState() : _buildEmptyState();
                }

                // Filter items based on search query and category
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final item = InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                  final matchesSearch = item.name.toLowerCase().contains(_searchQuery) ||
                      (item.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (item.category.toLowerCase().contains(_searchQuery));
                  final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var item = InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                    
                    return _buildInventoryCard(item, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _navigateToEditPage();
        },
        backgroundColor: secondaryColor,
        child: Icon(Icons.add, color: Colors.white, size: 28),
        elevation: 4,
      ),
    );
  }

  void _navigateToEditPage({InventoryItem? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryEditPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          item: item,
        ),
      ),
    );
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
        onTap: () {
          _navigateToEditPage(item: item);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Item icon/thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2_outlined, color: primaryColor, size: 30),
              ),
              SizedBox(width: 16),
              
              // Item details
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
                    Row(
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
                        if (isLowStock) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Low Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (isExpiringSoon) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Expiring Soon',
                              style: TextStyle(
                                fontSize: 12,
                                overflow: TextOverflow.ellipsis, // prevents overflow
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDetailItem(Icons.format_list_numbered, '${item.quantity} units'),
                        SizedBox(width: 16),
                        _buildDetailItem(Icons.attach_money, '\$${item.price.toStringAsFixed(2)}'),
                      ],
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
              
              // Action buttons
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: primaryColor),
                    onPressed: () {
                      _navigateToEditPage(item: item);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _showDeleteDialog(item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
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
                setState(() {});
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