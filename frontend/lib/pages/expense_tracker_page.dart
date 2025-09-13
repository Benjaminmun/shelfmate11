import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? description;
  final String createdBy;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    required this.createdBy,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      date: (data['date'] as Timestamp).toDate(),
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'description': description,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class ExpenseTrackerPage extends StatefulWidget {
  final String householdId;
  final bool isReadOnly;

  const ExpenseTrackerPage({
    Key? key,
    required this.householdId,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  _ExpenseTrackerPageState createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _categories = [
    'Food',
    'Transportation',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Healthcare',
    'Other'
  ];

  double _totalExpenses = 0.0;
  Map<String, double> _categoryTotals = {};
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final snapshot = await _firestore
          .collection('households')
          .doc(widget.householdId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      double total = 0.0;
      Map<String, double> categoryTotals = {};
      List<Expense> expenses = [];

      for (var doc in snapshot.docs) {
        final expense = Expense.fromFirestore(doc);
        expenses.add(expense);
        total += expense.amount;
        categoryTotals.update(
          expense.category,
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }

      setState(() {
        _expenses = expenses;
        _totalExpenses = total;
        _categoryTotals = categoryTotals;
      });
    } catch (e) {
      print('Error loading expenses: $e');
    }
  }

  Future<void> _addExpense() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => ExpenseDialog(
        categories: _categories,
        userId: user.uid,
      ),
    );

    if (result != null) {
      try {
        await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('expenses')
            .add(result.toFirestore());

        _loadExpenses(); // Reload expenses
      } catch (e) {
        print('Error adding expense: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add expense: $e')),
        );
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('households')
            .doc(widget.householdId)
            .collection('expenses')
            .doc(expenseId)
            .delete();

        _loadExpenses(); // Reload expenses
      } catch (e) {
        print('Error deleting expense: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF2D5D7C);
    final Color backgroundColor = Color(0xFFF8FAFC);
    final Color cardColor = Colors.white;
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
          if (!widget.isReadOnly)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _addExpense,
              tooltip: 'Add Expense',
            ),
        ],
      ),
      body: Container(
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

            // Expenses List
            Text(
              'Recent Expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: _expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt,
                            size: 64,
                            color: lightTextColor.withOpacity(0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No expenses yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: lightTextColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (!widget.isReadOnly)
                            Text(
                              'Tap the + button to add your first expense',
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
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return _buildExpenseItem(expense);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: _addExpense,
              backgroundColor: primaryColor,
              child: Icon(Icons.add, color: Colors.white),
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

  Widget _buildExpenseItem(Expense expense) {
    final Color primaryColor = Color(0xFF2D5D7C);
    final Color cardColor = Colors.white;
    final Color textColor = Color(0xFF1E293B);
    final Color lightTextColor = Color(0xFF64748B);

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
            _getCategoryIcon(expense.category),
            color: primaryColor,
          ),
        ),
        title: Text(
          expense.title,
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
              '${expense.category} • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
              style: TextStyle(color: lightTextColor),
            ),
            if (expense.description != null && expense.description!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  expense.description!,
                  style: TextStyle(color: lightTextColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'RM ${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            if (!widget.isReadOnly)
              TextButton(
                onPressed: () => _deleteExpense(expense.id),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
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
        return Icons.attach_money;
    }
  }
}

class ExpenseDialog extends StatefulWidget {
  final List<String> categories;
  final String userId;
  final Expense? existingExpense;

  const ExpenseDialog({
    Key? key,
    required this.categories,
    required this.userId,
    this.existingExpense,
  }) : super(key: key);

  @override
  _ExpenseDialogState createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Other';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _titleController.text = widget.existingExpense!.title;
      _amountController.text = widget.existingExpense!.amount.toString();
      _descriptionController.text = widget.existingExpense!.description ?? '';
      _selectedCategory = widget.existingExpense!.category;
      _selectedDate = widget.existingExpense!.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingExpense == null ? 'Add Expense' : 'Edit Expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount (RM)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text('Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final expense = Expense(
                id: widget.existingExpense?.id ?? '',
                title: _titleController.text,
                amount: double.parse(_amountController.text),
                category: _selectedCategory,
                date: _selectedDate,
                description: _descriptionController.text.isEmpty
                    ? null
                    : _descriptionController.text,
                createdBy: widget.userId,
              );
              Navigator.of(context).pop(expense);
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}