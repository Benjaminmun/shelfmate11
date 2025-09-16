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

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  // Load inventory data with better error handling
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

      print('Found ${snapshot.docs.length} inventory items'); // Debug info

      double total = 0.0;
      Map<String, double> categoryTotals = {};
      List<Map<String, dynamic>> items = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Debug print to see what data we're getting
        print('Item data: $data');
        
        // Handle potential missing or incorrectly typed fields
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
        _totalExpenses = total;
        _categoryTotals = categoryTotals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading inventory data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method to parse different types to double
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF2D5D7C);
    final Color backgroundColor = Color(0xFFF8FAFC);
    final Color textColor = Color(0xFF1E293B);
    final Color lightTextColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Expense Tracker',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInventoryData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInventoryData,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
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
                              child: Icon(Icons.attach_money, color: Colors.white, size: 28),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Expenses',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'RM ${_totalExpenses.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Category Breakdown
                      Text(
                        'Expenses by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildCategoryBreakdown(),

                      SizedBox(height: 24),

                      // Inventory Items List
                      Text(
                        'Inventory Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: _inventoryItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory,
                                      size: 64,
                                      color: lightTextColor.withOpacity(0.5),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No inventory items yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: lightTextColor,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Items added to inventory will appear here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: lightTextColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _inventoryItems.length,
                                itemBuilder: (context, index) {
                                  final item = _inventoryItems[index];
                                  return _buildInventoryItem(item);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryTotals.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No expenses to categorize',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _categoryTotals.entries.map((entry) {
          final percentage = (_totalExpenses > 0)
              ? (entry.value / _totalExpenses * 100)
              : 0;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5D7C)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RM ${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final Color primaryColor = Color(0xFF2D5D7C);
    final Color lightTextColor = Color(0xFF64748B);
    final double totalAmount = item['price'] * item['quantity'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            _getCategoryIcon(item['category']),
            color: primaryColor,
          ),
        ),
        title: Text(
          item['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${item['category']} • ${DateFormat('MMM dd, yyyy').format(item['updatedAt'])}',
              style: TextStyle(color: lightTextColor),
            ),
            if (item['description'] != null && item['description'].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  item['description'],
                  style: TextStyle(color: lightTextColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(height: 4),
            Text(
              '${item['quantity']} × RM ${item['price'].toStringAsFixed(2)} = RM ${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: lightTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'RM ${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Added by ${item['addedByUserName']}',
              style: TextStyle(color: lightTextColor, fontSize: 10),
            ),
          ],
        ),
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
}