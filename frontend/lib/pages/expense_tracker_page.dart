import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'dart:async';

class ExpenseTrackerPage extends StatefulWidget {
  final String householdId;
  final bool isReadOnly;

  const ExpenseTrackerPage({
    Key? key,
    required this.householdId,
    required this.isReadOnly,
  }) : super(key: key);

  @override
  _ExpenseTrackerPageState createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Search and filter state
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date';
  Timer? _debounceTimer;
  Stream<QuerySnapshot>? _inventoryStream;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Chart state
  int _touchedIndex = -1;
  bool _showChart = true;

  // Month tracking state
  DateTime _selectedMonth = DateTime.now();
  List<MonthlySummary> _monthlySummaries = [];
  bool _isLoadingMonthlyData = false;

  // Color palette
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color secondaryColor = Color(0xFF5A8BA8);
  final Color backgroundColor = Color(0xFFF8F9FF);
  final Color cardColor = Color(0xFFFFFFFF);
  final Color textColor = Color(0xFF2D3436);
  final Color lightTextColor = Color(0xFF636E72);
  final Color successColor = Color(0xFF00B894);
  final Color warningColor = Color(0xFFFDCB6E);
  final Color dangerColor = Color(0xFFD63031);

  // Category colors for chart
  final List<Color> chartColors = [
    Color(0xFFFF9F43),
    Color(0xFF5F27CD),
    Color(0xFF00D2D3),
    Color(0xFFF368E0),
    Color(0xFFFF6B6B),
    Color(0xFF1DD1A1),
    Color(0xFF8395A7),
    Color(0xFFF9CA24),
    Color(0xFF6AB04C),
    Color(0xFF4834D4),
  ];

  @override
  void initState() {
    super.initState();
    _setupInventoryStream();
    _initializeAnimations();
    _loadMonthlySummaries();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupInventoryStream() {
    // Get the first and last day of selected month
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    _inventoryStream = _firestore
        .collection('households')
        .doc(widget.householdId)
        .collection('inventory')
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // Load monthly summaries for the past 12 months
  Future<void> _loadMonthlySummaries() async {
    setState(() {
      _isLoadingMonthlyData = true;
    });

    try {
      final now = DateTime.now();
      final summaries = <MonthlySummary>[];
      
      for (int i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final firstDay = DateTime(month.year, month.month, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

        final snapshot = await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('inventory')
            .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
            .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
            .get();

        double monthlyTotal = 0.0;
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          final price = _parseDouble(data['price']);
          final quantity = _parseInt(data['quantity']);
          final totalValue = price * quantity;
          monthlyTotal += totalValue;
          return {
            'id': doc.id,
            'name': data['name']?.toString() ?? 'Unnamed Item',
            'category': data['category']?.toString() ?? 'Other',
            'quantity': quantity,
            'price': price,
            'totalValue': totalValue,
            'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
        }).toList();

        summaries.add(MonthlySummary(
          month: month,
          totalExpenses: monthlyTotal,
          itemCount: items.length,
        ));
      }

      setState(() {
        _monthlySummaries = summaries;
        _isLoadingMonthlyData = false;
      });
    } catch (error) {
      print('Error loading monthly summaries: $error');
      setState(() {
        _isLoadingMonthlyData = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _setupInventoryStream();
    });
  }

  _InventoryData _processInventoryData(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    Map<String, double> categoryTotals = {};
    List<Map<String, dynamic>> items = [];
    DateTime? latestUpdate;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      final price = _parseDouble(data['price']);
      final quantity = _parseInt(data['quantity']);
      final totalValue = price * quantity;
      final category = data['category']?.toString() ?? 'Other';
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      items.add({
        'id': doc.id,
        'name': data['name']?.toString() ?? 'Unnamed Item',
        'category': category,
        'quantity': quantity,
        'price': price,
        'totalValue': totalValue,
        'updatedAt': updatedAt,
        'description': data['description']?.toString() ?? '',
        'imageUrl': data['imageUrl']?.toString(),
        'localImagePath': data['localImagePath']?.toString(),
      });

      if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
        latestUpdate = updatedAt;
      }

      total += totalValue;
      categoryTotals.update(
        category,
        (value) => value + totalValue,
        ifAbsent: () => totalValue,
      );
    }

    return _InventoryData(
      items: items,
      totalExpenses: total,
      categoryTotals: categoryTotals,
      latestUpdateTime: latestUpdate,
    );
  }

  List<Map<String, dynamic>> _applySearchAndSort(
    List<Map<String, dynamic>> items, 
    String searchQuery, 
    String sortBy
  ) {
    List<Map<String, dynamic>> filtered = searchQuery.isEmpty
        ? List.from(items)
        : items.where((item) {
            return item['name'].toLowerCase().contains(searchQuery) ||
                   item['category'].toLowerCase().contains(searchQuery);
          }).toList();

    List<Map<String, dynamic>> sorted = List.from(filtered);
    
    if (sortBy == 'price') {
      sorted.sort((a, b) => b['totalValue'].compareTo(a['totalValue']));
    } else if (sortBy == 'category') {
      sorted.sort((a, b) => a['category'].compareTo(b['category']));
    } else {
      sorted.sort((a, b) => b['updatedAt'].compareTo(a['updatedAt']));
    }
    
    return sorted;
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to view these expenses. Please contact your household admin.';
        case 'unavailable':
          return 'Network unavailable. Please check your internet connection and try again.';
        case 'not-found':
          return 'Expense data not found. The household data may have been moved or deleted.';
        default:
          return 'Unable to load expenses: ${error.message}. Please try again.';
      }
    }
    return 'An unexpected error occurred while loading expenses. Please try again.';
  }

  String _formatUpdateTime(DateTime? updateTime) {
    if (updateTime == null) return 'Never updated';
    
    final now = DateTime.now();
    final difference = now.difference(updateTime);
    
    if (difference.inSeconds < 60) {
      return 'Updated just now';
    } else if (difference.inMinutes < 60) {
      return 'Updated ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return 'Updated ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return 'Updated ${DateFormat('MMM dd, yyyy').format(updateTime)}';
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      }
    });
  }

  // Interactive Pie Chart
  Widget _buildExpenseChart(Map<String, double> categoryTotals, double totalExpenses) {
    if (categoryTotals.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Text(
            'No data available for chart',
            style: TextStyle(color: lightTextColor),
          ),
        ),
      );
    }

    final categories = categoryTotals.entries.toList();
    
    return Container(
      height: 400,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 4,
                centerSpaceRadius: 60,
                sections: List.generate(categories.length, (i) {
                  final isTouched = i == _touchedIndex;
                  final category = categories[i];
                  final percentage = (category.value / totalExpenses * 100);
                  final fontSize = isTouched ? 16.0 : 12.0;
                  final radius = isTouched ? 60.0 : 50.0;

                  return PieChartSectionData(
                    color: chartColors[i % chartColors.length],
                    value: category.value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: radius,
                    titleStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildChartLegend(categories),
        ],
      ),
    );
  }

  Widget _buildChartLegend(List<MapEntry<String, double>> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categories.asMap().entries.map((entry) {
        final i = entry.key;
        final category = entry.value;
        final isTouched = i == _touchedIndex;
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isTouched ? chartColors[i].withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: chartColors[i],
              width: isTouched ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: chartColors[i],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                category.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Enhanced Loading State
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          SizedBox(height: 20),
          AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 500),
            child: Text(
              'Loading Expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Error State with Retry
  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: dangerColor),
            SizedBox(height: 24),
            Text(
              'Unable to Load Expenses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: lightTextColor,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _setupInventoryStream();
                setState(() {});
              },
              icon: Icon(Icons.refresh, size: 20),
              label: Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: lightTextColor.withOpacity(0.5)),
          SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No Expenses Yet' : 'No Matching Expenses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
              ? 'Start adding expenses to track your household spending'
              : 'Try adjusting your search terms',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: lightTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Month Selector Widget
  Widget _buildMonthSelector() {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: primaryColor),
            onPressed: () => _changeMonth(-1),
          ),
          GestureDetector(
            onTap: _showMonthlyHistory,
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap to view history',
                  style: TextStyle(
                    fontSize: 12,
                    color: lightTextColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: primaryColor),
            onPressed: () {
              final now = DateTime.now();
              final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              if (nextMonth.isBefore(DateTime(now.year, now.month + 1))) {
                _changeMonth(1);
              }
            },
          ),
        ],
      ),
    );
  }

  // Monthly History Widget
  Widget _buildMonthlyHistory() {
    if (_isLoadingMonthlyData) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 12),
          Container(
            height: 295,
            child: ListView(
              children: _monthlySummaries.map((summary) {
                final isCurrent = summary.month.month == _selectedMonth.month && 
                                summary.month.year == _selectedMonth.year;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? primaryColor : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat('MMM').format(summary.month),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? primaryColor : lightTextColor,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    DateFormat('MMMM yyyy').format(summary.month),
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                      color: isCurrent ? primaryColor : textColor,
                    ),
                  ),
                  trailing: Text(
                    'RM ${summary.totalExpenses.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: summary.totalExpenses > 0 ? textColor : lightTextColor,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedMonth = summary.month;
                      _setupInventoryStream();
                    });
                    Navigator.pop(context); // Close the dialog
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthlyHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Select Month',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: _buildMonthlyHistory(),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double totalExpenses, DateTime? latestUpdate, int itemCount) {
    final monthlyComparison = _getMonthlyComparison(totalExpenses);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${DateFormat('MMMM yyyy').format(_selectedMonth)} Expenses", 
                      style: TextStyle(color: Colors.white70, fontSize: 16)
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$itemCount items • ${_formatUpdateTime(latestUpdate)}', 
                      style: TextStyle(color: Colors.white60, fontSize: 12)
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "RM ${totalExpenses.toStringAsFixed(2)}", 
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)
          ),
          if (monthlyComparison != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  monthlyComparison.isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white70,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '${monthlyComparison.percentage.toStringAsFixed(1)}% from last month',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  MonthlyComparison? _getMonthlyComparison(double currentMonthTotal) {
    if (_monthlySummaries.length < 2) return null;

    final currentIndex = _monthlySummaries.indexWhere((summary) =>
      summary.month.month == _selectedMonth.month && 
      summary.month.year == _selectedMonth.year
    );

    if (currentIndex == -1 || currentIndex + 1 >= _monthlySummaries.length) return null;

    final previousMonth = _monthlySummaries[currentIndex + 1];
    if (previousMonth.totalExpenses == 0) return null;

    final difference = currentMonthTotal - previousMonth.totalExpenses;
    final percentage = (difference / previousMonth.totalExpenses * 100).abs();

    return MonthlyComparison(
      isIncrease: difference > 0,
      percentage: percentage,
      difference: difference,
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
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search expenses by name or category...',
          hintStyle: TextStyle(color: lightTextColor),
          prefixIcon: Icon(Icons.search, color: lightTextColor),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(
            icon: Icon(Icons.close, color: lightTextColor),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryColor : lightTextColor.withOpacity(0.3)),
          boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 2))] : null,
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : lightTextColor, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  // Updated Expense Item with Image Support and Integer Quantity
  Widget _buildExpenseItem(Map<String, dynamic> item, int index) {
    final double totalAmount = item['price'] * item['quantity'];
    final categoryColor = chartColors[item['category'].hashCode % chartColors.length];
    final date = DateFormat('MMM dd').format(item['updatedAt']);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item thumbnail
              _buildItemThumbnail(item),
              SizedBox(width: 16),
              
              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['category'],
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered, size: 16, color: lightTextColor),
                        SizedBox(width: 4),
                        Text(
                          '${item['quantity']} ${item['quantity'] == 1 ? 'unit' : 'units'}',
                          style: TextStyle(fontSize: 14, color: lightTextColor),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.attach_money, size: 16, color: lightTextColor),
                        SizedBox(width: 4),
                        Text(
                          "RM ${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w700, 
                            color: textColor, 
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: lightTextColor),
                        SizedBox(width: 4),
                        Text(
                          date,
                          style: TextStyle(fontSize: 14, color: lightTextColor),
                        ),
                      ],
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

  // Item Thumbnail Widget
  Widget _buildItemThumbnail(Map<String, dynamic> item) {
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

  // Item Image Widget
  Widget _buildItemImage(Map<String, dynamic> item) {
    // Priority: localImagePath > imageUrl > default icon
    if (item['localImagePath'] != null && item['localImagePath'].isNotEmpty) {
      return Image.file(
        File(item['localImagePath']),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon();
        },
      );
    } else if (item['imageUrl'] != null && item['imageUrl'].isNotEmpty) {
      return Image.network(
        item['imageUrl'],
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transportation': return Icons.directions_car;
      case 'utilities': return Icons.bolt;
      case 'entertainment': return Icons.movie;
      case 'shopping': return Icons.shopping_bag;
      case 'healthcare': return Icons.local_hospital;
      case 'beverages': return Icons.local_bar; 
      case 'cleaning supplies': return Icons.cleaning_services; 
      case 'personal care': return Icons.self_improvement; 
      case 'medication': return Icons.medical_services; 
      default: return Icons.category;
    }
  }

  Widget _buildCategoryList(Map<String, double> categoryTotals, double totalExpenses) {
    final categories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final percentage = (category.value / totalExpenses * 100);
          final color = chartColors[index % chartColors.length];
          
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_getCategoryIcon(category.key), color: color, size: 20),
                    ),
                    Text("${percentage.toStringAsFixed(0)}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                SizedBox(height: 16),
                Text(category.key, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                SizedBox(height: 8),
                Text("RM ${category.value.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
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
        },
      ),
    );
  }

  Widget _buildContent(_InventoryData inventoryData) {
    final filteredItems = _applySearchAndSort(inventoryData.items, _searchQuery, _sortBy);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: () async {
          _setupInventoryStream();
          _loadMonthlySummaries();
          setState(() {});
        },
        color: primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthSelector(),
                    SizedBox(height: 20),
                    _buildSummaryCard(inventoryData.totalExpenses, inventoryData.latestUpdateTime, inventoryData.items.length),
                    SizedBox(height: 28),
                    
                    // Chart/List Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expense Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        IconButton(
                          icon: Icon(_showChart ? Icons.list : Icons.pie_chart, color: primaryColor),
                          onPressed: () => setState(() => _showChart = !_showChart),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Interactive Chart or Category List
                    _showChart 
                      ? _buildExpenseChart(inventoryData.categoryTotals, inventoryData.totalExpenses)
                      : _buildCategoryList(inventoryData.categoryTotals, inventoryData.totalExpenses),
                    
                    SizedBox(height: 28),
                    Text('Recent Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                    SizedBox(height: 16),
                    _buildSearchBar(),
                    SizedBox(height: 16),
                    Row(children: [
                      _buildSortChip('Date', 'date'),
                      SizedBox(width: 8),
                      _buildSortChip('Price', 'price'),
                      SizedBox(width: 8),
                      _buildSortChip('Category', 'category'),
                    ]),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // Animated Expense List with Images
            filteredItems.isEmpty
              ? SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: _buildEmptyState()))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _buildExpenseItem(filteredItems[index], index),
                    ),
                    childCount: filteredItems.length,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Expense Tracker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showMonthlyHistory,
          ),
        ],
      ),
      floatingActionButton: !widget.isReadOnly ? FloatingActionButton(
        onPressed: () {
          // TODO: Implement add expense functionality
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Add expense functionality would be implemented here'),
              backgroundColor: primaryColor,
            ),
          );
        },
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ) : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _inventoryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(_getErrorMessage(snapshot.error));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyContent();
          }

          final docs = snapshot.data!.docs;
          final inventoryData = _processInventoryData(docs);

          return _buildContent(inventoryData);
        },
      ),
    );
  }

  Widget _buildEmptyContent() {
    return RefreshIndicator(
      onRefresh: () async {
        _setupInventoryStream();
        _loadMonthlySummaries();
        setState(() {});
      },
      color: primaryColor,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            SizedBox(height: 20),
            _buildSummaryCard(0.0, null, 0),
            SizedBox(height: 28),
            _buildEmptyState(),
          ],
        ),
      ),
    );
  }
}

// Data classes for monthly tracking
class MonthlySummary {
  final DateTime month;
  final double totalExpenses;
  final int itemCount;

  MonthlySummary({
    required this.month,
    required this.totalExpenses,
    required this.itemCount,
  });
}

class MonthlyComparison {
  final bool isIncrease;
  final double percentage;
  final double difference;

  MonthlyComparison({
    required this.isIncrease,
    required this.percentage,
    required this.difference,
  });
}

class _InventoryData {
  final List<Map<String, dynamic>> items;
  final double totalExpenses;
  final Map<String, double> categoryTotals;
  final DateTime? latestUpdateTime;

  _InventoryData({
    required this.items,
    required this.totalExpenses,
    required this.categoryTotals,
    this.latestUpdateTime,
  });
}