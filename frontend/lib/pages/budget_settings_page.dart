import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class BudgetSettingsPage extends StatefulWidget {
  final String householdId;
  final String householdName;

  const BudgetSettingsPage({
    Key? key,
    required this.householdId,
    required this.householdName,
  }) : super(key: key);

  @override
  _BudgetSettingsPageState createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Enhanced color scheme
  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _secondaryColor = Color(0xFF6270B1);
  final Color _successColor = Color(0xFF10B981);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _backgroundColor = Color(0xFFF8FAFF);
  final Color _surfaceColor = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1E293B);
  final Color _textSecondary = Color(0xFF64748B);
  final Color _textLight = Color(0xFF94A3B8);

  // Form controllers
  final TextEditingController _monthlyBudgetController = TextEditingController();
  final TextEditingController _weeklyBudgetController = TextEditingController();
  final TextEditingController _groceriesBudgetController = TextEditingController();
  final TextEditingController _essentialsBudgetController = TextEditingController();

  // Form state
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  
  // Budget data
  Map<String, dynamic> _budgetData = {
    'minimumMonthlySpending': 0.0,
    'minimumWeeklySpending': 0.0,
    'groceriesBudget': 0.0,
    'essentialsBudget': 0.0,
    'budgetPeriod': 'monthly', // 'monthly' or 'weekly'
    'budgetAlertEnabled': true,
    'lowBudgetThreshold': 0.8, // 80% of budget
  };

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
    
    // Add listeners to detect changes
    _monthlyBudgetController.addListener(_checkForChanges);
    _weeklyBudgetController.addListener(_checkForChanges);
    _groceriesBudgetController.addListener(_checkForChanges);
    _essentialsBudgetController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _monthlyBudgetController.dispose();
    _weeklyBudgetController.dispose();
    _groceriesBudgetController.dispose();
    _essentialsBudgetController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    if (!_isLoading) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _loadBudgetData() async {
    try {
      final householdDoc = await _firestore
          .collection('households')
          .doc(widget.householdId)
          .get();

      if (householdDoc.exists) {
        final data = householdDoc.data() ?? {};
        
        setState(() {
          _budgetData = {
            'minimumMonthlySpending': (data['minimumMonthlySpending'] ?? 0.0).toDouble(),
            'minimumWeeklySpending': (data['minimumWeeklySpending'] ?? 0.0).toDouble(),
            'groceriesBudget': (data['groceriesBudget'] ?? 0.0).toDouble(),
            'essentialsBudget': (data['essentialsBudget'] ?? 0.0).toDouble(),
            'budgetPeriod': data['budgetPeriod'] ?? 'monthly',
            'budgetAlertEnabled': data['budgetAlertEnabled'] ?? true,
            'lowBudgetThreshold': (data['lowBudgetThreshold'] ?? 0.8).toDouble(),
          };
        });

        // Update controllers
        _monthlyBudgetController.text = _budgetData['minimumMonthlySpending'] > 0 
            ? _budgetData['minimumMonthlySpending'].toStringAsFixed(2)
            : '';
        _weeklyBudgetController.text = _budgetData['minimumWeeklySpending'] > 0
            ? _budgetData['minimumWeeklySpending'].toStringAsFixed(2)
            : '';
        _groceriesBudgetController.text = _budgetData['groceriesBudget'] > 0
            ? _budgetData['groceriesBudget'].toStringAsFixed(2)
            : '';
        _essentialsBudgetController.text = _budgetData['essentialsBudget'] > 0
            ? _budgetData['essentialsBudget'].toStringAsFixed(2)
            : '';
      }
    } catch (e) {
      print('Error loading budget data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load budget settings'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    }
  }

  Future<void> _saveBudgetData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Parse input values
      final monthlyBudget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
      final weeklyBudget = double.tryParse(_weeklyBudgetController.text) ?? 0.0;
      final groceriesBudget = double.tryParse(_groceriesBudgetController.text) ?? 0.0;
      final essentialsBudget = double.tryParse(_essentialsBudgetController.text) ?? 0.0;

      // Update budget data
      final updatedBudgetData = {
        'minimumMonthlySpending': monthlyBudget,
        'minimumWeeklySpending': weeklyBudget,
        'groceriesBudget': groceriesBudget,
        'essentialsBudget': essentialsBudget,
        'budgetPeriod': _budgetData['budgetPeriod'],
        'budgetAlertEnabled': _budgetData['budgetAlertEnabled'],
        'lowBudgetThreshold': _budgetData['lowBudgetThreshold'],
        'budgetLastUpdated': FieldValue.serverTimestamp(),
        'budgetUpdatedBy': _auth.currentUser?.uid,
      };

      // Save to Firestore
      await _firestore
          .collection('households')
          .doc(widget.householdId)
          .update(updatedBudgetData);

      // Log activity
      await _logBudgetUpdateActivity(monthlyBudget, weeklyBudget);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget settings updated successfully!'),
          backgroundColor: _successColor,
        ),
      );

      setState(() {
        _hasChanges = false;
      });

    } catch (e) {
      print('Error saving budget data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save budget settings: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _logBudgetUpdateActivity(double monthlyBudget, double weeklyBudget) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['userName'] ?? user.displayName ?? 'User';
      final fullName = userDoc.data()?['fullName'] ?? userName;

      await _firestore
          .collection('households')
          .doc(widget.householdId)
          .collection('activities')
          .add({
            'description': 'Budget settings updated: RM${monthlyBudget.toStringAsFixed(2)} monthly, RM${weeklyBudget.toStringAsFixed(2)} weekly',
            'type': 'update',
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user.uid,
            'userName': userName,
            'fullName': fullName,
            'itemName': 'Budget Settings',
            'oldValue': 'Previous budget',
            'newValue': 'New budget set',
          });
    } catch (e) {
      print('Error logging budget activity: $e');
    }
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset to Defaults'),
        content: Text('Are you sure you want to reset all budget settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performReset();
            },
            child: Text('Reset', style: TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
  }

  void _performReset() {
    setState(() {
      _monthlyBudgetController.clear();
      _weeklyBudgetController.clear();
      _groceriesBudgetController.clear();
      _essentialsBudgetController.clear();
      
      _budgetData = {
        'minimumMonthlySpending': 0.0,
        'minimumWeeklySpending': 0.0,
        'groceriesBudget': 0.0,
        'essentialsBudget': 0.0,
        'budgetPeriod': 'monthly',
        'budgetAlertEnabled': true,
        'lowBudgetThreshold': 0.8,
      };
      
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _primaryColor,
        systemNavigationBarColor: _backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading
            ? _buildLoadingState()
            : _buildBudgetForm(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Budget Settings',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      backgroundColor: _primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      actions: [
        if (_hasChanges)
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _resetToDefaults,
            tooltip: 'Reset Changes',
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
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading budget settings...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetForm() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildHouseholdHeader(),
            SizedBox(height: 24),
            _buildBudgetOverview(),
            SizedBox(height: 24),
            _buildMainBudgetSection(),
            SizedBox(height: 24),
            _buildCategoryBudgets(),
            SizedBox(height: 24),
            _buildBudgetPreferences(),
            SizedBox(height: 32),
            _buildActionButtons(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor.withOpacity(0.1), _secondaryColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_rounded, color: _primaryColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.householdName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Set spending limits and budget preferences for smarter recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetOverview() {
    final monthlyBudget = double.tryParse(_monthlyBudgetController.text) ?? 0.0;
    final weeklyBudget = double.tryParse(_weeklyBudgetController.text) ?? 0.0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildBudgetStat('Monthly', monthlyBudget, Icons.calendar_month_rounded, _primaryColor),
              SizedBox(width: 16),
              _buildBudgetStat('Weekly', weeklyBudget, Icons.today_rounded, _secondaryColor),
            ],
          ),
          if (monthlyBudget > 0 && weeklyBudget > 0) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _successColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: _successColor, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your budget will help us provide personalized recommendations and spending alerts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetStat(String period, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              amount > 0 ? 'RM${amount.toStringAsFixed(2)}' : 'Not set',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: amount > 0 ? _textPrimary : _textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBudgetSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Main Budget Limits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Set your minimum spending limits for better recommendations',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 20),
          _buildBudgetInputField(
            controller: _monthlyBudgetController,
            label: 'Minimum Monthly Spending',
            hint: 'Enter monthly budget (RM)',
            icon: Icons.calendar_month_rounded,
            isRequired: false,
          ),
          SizedBox(height: 16),
          _buildBudgetInputField(
            controller: _weeklyBudgetController,
            label: 'Minimum Weekly Spending',
            hint: 'Enter weekly budget (RM)',
            icon: Icons.today_rounded,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgets() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Budgets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Set specific budgets for different categories (optional)',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 20),
          _buildBudgetInputField(
            controller: _groceriesBudgetController,
            label: 'Groceries Budget',
            hint: 'Enter groceries budget (RM)',
            icon: Icons.shopping_basket_rounded,
            isRequired: false,
          ),
          SizedBox(height: 16),
          _buildBudgetInputField(
            controller: _essentialsBudgetController,
            label: 'Essentials Budget',
            hint: 'Enter essentials budget (RM)',
            icon: Icons.cleaning_services_rounded,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetPreferences() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 20),
          _buildPreferenceSwitch(
            title: 'Budget Alerts',
            subtitle: 'Receive notifications when approaching budget limits',
            value: _budgetData['budgetAlertEnabled'],
            onChanged: (value) {
              setState(() {
                _budgetData['budgetAlertEnabled'] = value;
                _hasChanges = true;
              });
            },
            icon: Icons.notifications_active_rounded,
          ),
          SizedBox(height: 16),
          _buildPreferenceSlider(
            title: 'Low Budget Alert Threshold',
            subtitle: 'Get alerted when spending reaches this percentage of your budget',
            value: _budgetData['lowBudgetThreshold'],
            onChanged: (value) {
              setState(() {
                _budgetData['lowBudgetThreshold'] = value;
                _hasChanges = true;
              });
            },
          ),
          SizedBox(height: 16),
          _buildPreferenceRadio(
            title: 'Primary Budget Period',
            subtitle: 'Set your main budgeting timeframe',
            value: _budgetData['budgetPeriod'],
            options: [
              {'value': 'monthly', 'label': 'Monthly', 'icon': Icons.calendar_month_rounded},
              {'value': 'weekly', 'label': 'Weekly', 'icon': Icons.today_rounded},
            ],
            onChanged: (value) {
              setState(() {
                _budgetData['budgetPeriod'] = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _textSecondary),
        prefixText: 'RM ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _textLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: _backgroundColor,
      ),
      style: TextStyle(
        fontSize: 16,
        color: _textPrimary,
        fontWeight: FontWeight.w500,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        if (value != null && value.isNotEmpty) {
          final amount = double.tryParse(value);
          if (amount == null || amount < 0) {
            return 'Please enter a valid amount';
          }
        }
        return null;
      },
    );
  }

  Widget _buildPreferenceSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 24),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _primaryColor,
        ),
      ],
    );
  }

  Widget _buildPreferenceSlider({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: _textSecondary,
          ),
        ),
        SizedBox(height: 16),
        Slider(
          value: value,
          onChanged: onChanged,
          min: 0.5,
          max: 1.0,
          divisions: 10,
          label: '${(value * 100).toInt()}%',
          activeColor: _primaryColor,
          inactiveColor: _textLight.withOpacity(0.3),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '50%',
              style: TextStyle(
                fontSize: 12,
                color: _textLight,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                fontSize: 12,
                color: _textLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferenceRadio({
    required String title,
    required String subtitle,
    required String value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: _textSecondary,
          ),
        ),
        SizedBox(height: 12),
        ...options.map((option) => RadioListTile<String>(
          title: Row(
            children: [
              Icon(option['icon'] as IconData, color: _textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                option['label'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          value: option['value'] as String,
          groupValue: value,
          onChanged: (newValue) => onChanged(newValue!),
          activeColor: _primaryColor,
          contentPadding: EdgeInsets.zero,
        )).toList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _hasChanges ? _resetToDefaults : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: _textLight),
            ),
            child: Text(
              'Reset to Defaults',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _hasChanges && !_isSaving ? _saveBudgetData : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}