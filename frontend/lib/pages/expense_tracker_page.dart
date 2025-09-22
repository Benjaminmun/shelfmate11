import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ExpenseTrackerPage extends StatefulWidget {
  final String householdId;

  const ExpenseTrackerPage({
    Key? key,
    required this.householdId,
  }) : super(key: key);

  @override
  _ExpenseTrackerPageState createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _totalExpenses = 0.0;
  Map<String, double> _categoryTotals = {};
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Search and filter state
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date';
  List<Map<String, dynamic>> _filteredItems = [];

  // Premium color palette
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF5A8BA8);
  final Color backgroundColor = Color(0xFFF8F9FF);
  final Color cardColor = Color(0xFFFFFFFF);
  final Color textColor = Color(0xFF2D3436);
  final Color lightTextColor = Color(0xFF636E72);
  final Color successColor = Color(0xFF00B894);
  final Color warningColor = Color(0xFFFDCB6E);
  final Color dangerColor = Color(0xFFD63031);

  // Category colors
  final Map<String, Color> categoryColors = {
    'Food': Color(0xFFFF9F43),
    'Transportation': Color(0xFF5F27CD),
    'Utilities': Color(0xFF00D2D3),
    'Entertainment': Color(0xFFF368E0),
    'Shopping': Color(0xFFFF6B6B),
    'Healthcare': Color(0xFF1DD1A1),
    'Other': Color(0xFF8395A7),
  };

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final snapshot = await _firestore
          .collection('households')
          .doc(widget.householdId)
          .collection('inventory')
          .orderBy('updatedAt', descending: true)
          .get();

      double total = 0.0;
      Map<String, double> categoryTotals = {};
      List<Map<String, dynamic>> items = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final price = _parseDouble(data['price']);
        final quantity = _parseDouble(data['quantity']);
        final totalValue = price * quantity;
        final category = data['category']?.toString() ?? 'Other';
        
        items.add({
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unnamed Item',
          'category': category,
          'quantity': quantity,
          'price': price,
          'totalValue': totalValue,
          'addedByUserName': data['addedByUserName']?.toString() ?? 'Unknown',
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'description': data['description']?.toString() ?? '',
        });

        total += totalValue;
        categoryTotals.update(
          category,
          (value) => value + totalValue,
          ifAbsent: () => totalValue,
        );
      }

      setState(() {
        _inventoryItems = items;
        _filteredItems = items;
        _totalExpenses = total;
        _categoryTotals = categoryTotals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading inventory data: $e');
      setState(() {
        _errorMessage = 'Failed to load data. Please try again.';
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _filterItems() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredItems = List.from(_inventoryItems);
      } else {
        _filteredItems = _inventoryItems.where((item) {
          return item['name'].toLowerCase().contains(_searchQuery) ||
                 item['category'].toLowerCase().contains(_searchQuery) ||
                 (item['description']?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();
      }
      _applySorting();
    });
  }

  void _applySorting() {
    if (_sortBy == 'price') {
      _filteredItems.sort((a, b) => b['totalValue'].compareTo(a['totalValue']));
    } else if (_sortBy == 'category') {
      _filteredItems.sort((a, b) => a['category'].compareTo(b['category']));
    } else {
      _filteredItems.sort((a, b) => b['updatedAt'].compareTo(a['updatedAt']));
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _firestore.collection('households')
        .doc(widget.householdId)
        .collection('inventory')
        .doc(itemId)
        .delete();
      
      _loadInventoryData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete item. Please try again.'),
          backgroundColor: dangerColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ),
              SizedBox(width: 16),
              Text("Total Expenses",
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
          SizedBox(height: 16),
          Text("RM ${_totalExpenses.toStringAsFixed(2)}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              )),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.arrow_upward, color: Colors.white70, size: 16),
              SizedBox(width: 4),
              Text("Updated just now",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, double amount, double percentage) {
    final color = categoryColors[category] ?? categoryColors['Other']!;
    
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(category), color: color, size: 20),
              ),
              Text("${percentage.toStringAsFixed(0)}%",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          SizedBox(height: 16),
          Text(category,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          SizedBox(height: 8),
          Text("RM ${amount.toStringAsFixed(2)}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.2),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.toLowerCase();
            _filterItems();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: TextStyle(color: lightTextColor),
          prefixIcon: Icon(Icons.search, color: lightTextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: lightTextColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _filterItems();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSortFilterChip(String label, String value) {
    final isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _applySorting();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : lightTextColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : lightTextColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final double totalAmount = item['price'] * item['quantity'];
    final categoryColor = categoryColors[item['category']] ?? categoryColors['Other']!;
    final date = DateFormat('MMM dd').format(item['updatedAt']);

    return Dismissible(
      key: Key(item['id']),
      background: Container(
        decoration: BoxDecoration(
          color: dangerColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: dangerColor, size: 48),
                    SizedBox(height: 16),
                    Text(
                      "Delete Item",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Are you sure you want to delete ${item['name']}?",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: lightTextColor),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: lightTextColor.withOpacity(0.3)),
                            ),
                            child: Text("Cancel", style: TextStyle(color: lightTextColor)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dangerColor,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text("Delete", style: TextStyle(color: Colors.white)),
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
      },
      onDismissed: (direction) {
        _deleteItem(item['id']);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getCategoryIcon(item['category']), color: categoryColor),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['name'], 
                          style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 16)),
                      Text("RM ${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['category'],
                          style: TextStyle(color: categoryColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        date,
                        style: TextStyle(color: lightTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                  if (item['description'] != null && item['description'].isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        item['description'],
                        style: TextStyle(color: lightTextColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: lightTextColor),
                      SizedBox(width: 4),
                      Text(
                        "by ${item['addedByUserName']}",
                        style: TextStyle(color: lightTextColor, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: lightTextColor.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty 
              ? 'No inventory items yet'
              : 'No items found',
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
              ? 'Items added to inventory will appear here'
              : 'Try a different search term',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'utilities':
        return Icons.bolt;
      case 'entertainment':
        return Icons.movie;
      case 'shopping':
        return Icons.shopping_bag;
      case 'healthcare':
        return Icons.local_hospital;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Expense Tracker',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInventoryData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading expenses...',
                    style: TextStyle(color: lightTextColor),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: dangerColor),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInventoryData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInventoryData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        _buildSummaryCard(),
                        SizedBox(height: 28),

                        // Category Breakdown
                        Text(
                          'Expenses by Category',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        _categoryTotals.isEmpty
                            ? Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'No expenses to categorize',
                                    style: TextStyle(color: lightTextColor),
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 200,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: _categoryTotals.entries.map((entry) {
                                    final percentage = (_totalExpenses > 0) 
                                        ? (entry.value / _totalExpenses * 100) 
                                        : 0.0;
                                    return _buildCategoryCard(entry.key, entry.value, percentage);
                                  }).toList(),
                                ),
                              ),

                        SizedBox(height: 28),

                        // Inventory Items Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Expenses',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.filter_list, color: primaryColor),
                              onPressed: () {
                                // TODO: Implement filter dialog
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildSearchBar(),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            _buildSortFilterChip('Date', 'date'),
                            SizedBox(width: 8),
                            _buildSortFilterChip('Price', 'price'),
                            SizedBox(width: 8),
                            _buildSortFilterChip('Category', 'category'),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Inventory Items List
                        _filteredItems.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  return _buildInventoryItem(item);
                                },
                              ),
                      ],
                    ),
                  ),
                ),
    );
  }
}