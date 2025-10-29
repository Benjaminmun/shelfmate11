import 'package:flutter/material.dart';
import '../services/shopping_list_service.dart';

class ShoppingListPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const ShoppingListPage({
    Key? key,
    required this.householdId,
    required this.householdName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  @override
  _ShoppingListPageState createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> with SingleTickerProviderStateMixin {
  final ShoppingListService _shoppingListService = ShoppingListService();
  List<Map<String, dynamic>> _shoppingItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  double _totalEstimatedCost = 0.0;
  int _totalItems = 0;
  int _completedItems = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadShoppingList();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadShoppingList() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final items = await _shoppingListService.getShoppingList(widget.householdId);
      
      if (mounted) {
        setState(() {
          _shoppingItems = items;
          _isLoading = false;
          _calculateTotals();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _calculateTotals() {
    double totalCost = 0.0;
    int totalItems = 0;
    int completedItems = 0;
    
    for (final item in _shoppingItems) {
      final quantity = item['quantity'] as int? ?? 1;
      final price = (item['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
      final completed = item['completed'] == true;
      
      totalCost += quantity * price;
      totalItems += quantity;
      if (completed) completedItems += 1;
    }
    
    setState(() {
      _totalEstimatedCost = totalCost;
      _totalItems = totalItems;
      _completedItems = completedItems;
    });
  }

  Future<void> _updateItemQuantity(String itemId, int newQuantity) async {
    print('🔄 Updating quantity for item $itemId to $newQuantity');
    
    if (newQuantity <= 0) {
      await _removeItem(itemId);
      return;
    }

    try {
      final result = await _shoppingListService.updateItemQuantity(
        widget.householdId, 
        itemId, 
        newQuantity,
      );

      if (result['success'] == true) {
        await _loadShoppingList();
        _showSuccessSnackbar('Quantity updated');
      } else {
        _showErrorSnackbar('Failed to update quantity: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error updating quantity: $e');
      _showErrorSnackbar('Failed to update quantity: $e');
    }
  }

  Future<void> _removeItem(String itemId) async {
    print('🗑️ Removing item: $itemId');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Item',
          style: TextStyle(
            color: widget.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this item from your shopping list?',
          style: TextStyle(color: widget.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: widget.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await _shoppingListService.removeFromShoppingList(
                  widget.householdId, 
                  itemId,
                );

                if (result['success'] == true) {
                  await _loadShoppingList();
                  _showSuccessSnackbar('Item removed from list');
                } else {
                  _showErrorSnackbar('Failed to remove item: ${result['error']}');
                }
              } catch (e) {
                print('❌ Error removing item: $e');
                _showErrorSnackbar('Failed to remove item: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCompletedItems() async {
    if (_completedItems == 0) {
      _showErrorSnackbar('No completed items to clear');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Completed Items',
          style: TextStyle(
            color: widget.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all $_completedItems completed items?',
          style: TextStyle(color: widget.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: widget.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              print('🧹 Clearing completed items...');
              
              try {
                final result = await _shoppingListService.clearCompletedItems(widget.householdId);
                
                if (result['success'] == true) {
                  await _loadShoppingList();
                  _showSuccessSnackbar('Cleared ${result['clearedCount']} completed items');
                } else {
                  _showErrorSnackbar('Failed to clear completed items: ${result['error']}');
                }
              } catch (e) {
                print('❌ Error clearing completed items: $e');
                _showErrorSnackbar('Failed to clear completed items: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _markItemAsPurchased(String itemId) async {
    print('🛍️ Marking item as purchased: $itemId');
    
    try {
      final result = await _shoppingListService.markItemAsPurchased(
        widget.householdId, 
        itemId,
      );

      if (result['success'] == true) {
        await _loadShoppingList();
        _showSuccessSnackbar('Item marked as purchased!');
      } else {
        _showErrorSnackbar('Failed to mark item as purchased: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error marking item as purchased: $e');
      _showErrorSnackbar('Failed to mark item as purchased: $e');
    }
  }

  Future<void> _uncompleteItem(String itemId) async {
    print('↩️ Un-completing item: $itemId');
    
    try {
      final result = await _shoppingListService.toggleItemStatus(
        widget.householdId, 
        itemId, 
        false,
      );

      if (result['success'] == true) {
        await _loadShoppingList();
        _showSuccessSnackbar('Item moved back to shopping list');
      } else {
        _showErrorSnackbar('Failed to restore item: ${result['error']}');
      }
    } catch (e) {
      print('❌ Error un-completing item: $e');
      _showErrorSnackbar('Failed to restore item: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: widget.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: widget.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

 Future<void> _quickAddItem(String name, [String category = 'Other']) async {
    try {
      await _shoppingListService.addToShoppingList(
        widget.householdId,
        name,
        1,
        'quick_${DateTime.now().millisecondsSinceEpoch}',
        category: category,
      );
      await _loadShoppingList();
      _showSuccessSnackbar('$name added to list');
    } catch (e) {
      _showErrorSnackbar('Failed to add item: $e');
    }
  }

  void _showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.textLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Add Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: widget.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAddChip(
                  label: 'Milk',
                  icon: Icons.local_drink_rounded,
                  onTap: () => _quickAddItem('Milk', 'Beverages'),
                  color: widget.primaryColor,
                ),
                _QuickAddChip(
                  label: 'Bread',
                  icon: Icons.bakery_dining_rounded,
                  onTap: () => _quickAddItem('Bread', 'Food'),
                  color: widget.primaryColor,
                ),
                _QuickAddChip(
                  label: 'Eggs',
                  icon: Icons.egg_rounded,
                  onTap: () => _quickAddItem('Eggs', 'Food'),
                  color: widget.primaryColor,
                ),
                _QuickAddChip(
                  label: 'Rice',
                  icon: Icons.rice_bowl_rounded,
                  onTap: () => _quickAddItem('Rice', 'Food'),
                  color: widget.primaryColor,
                ),
                _QuickAddChip(
                  label: 'Soap',
                  icon: Icons.soap_rounded,
                  onTap: () => _quickAddItem('Soap', 'Personal Care'),
                  color: widget.primaryColor,
                ),
                _QuickAddChip(
                  label: 'Shampoo',
                  icon: Icons.shower_rounded,
                  onTap: () => _quickAddItem('Shampoo', 'Personal Care'),
                  color: widget.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddItemDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text('Add Custom Item'),
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
      backgroundColor: widget.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_isLoading && !_hasError && _shoppingItems.isNotEmpty)
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildHeaderStats(),
            ),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _shoppingItems.isEmpty
                        ? _buildEmptyState()
                        : _buildUnifiedShoppingList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        '${widget.householdName} Shopping',
        style: TextStyle(
          color: widget.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      backgroundColor: widget.surfaceColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: widget.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_completedItems > 0)
          _buildClearCompletedButton(),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: widget.textSecondary),
          onPressed: _loadShoppingList,
          tooltip: 'Refresh List',
        ),
      ],
    );
  }

  Widget _buildClearCompletedButton() {
    return Tooltip(
      message: 'Clear $_completedItems completed items',
      child: Stack(
        children: [
          IconButton(
            icon: Icon(Icons.cleaning_services_rounded, color: widget.successColor),
            onPressed: _clearCompletedItems,
          ),
          if (_completedItems > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: widget.errorColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$_completedItems',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    final completionPercentage = _shoppingItems.isNotEmpty ? (_completedItems / _shoppingItems.length) * 100 : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shopping Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.textSecondary,
                ),
              ),
              Text(
                '${completionPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutQuart,
                    width: constraints.maxWidth * (completionPercentage / 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.primaryColor, widget.successColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Enhanced Stats cards
          Row(
            children: [
              _buildEnhancedStatCard(
                'Total Items',
                '$_totalItems',
                Icons.shopping_basket_rounded,
                widget.primaryColor,
              ),
              const SizedBox(width: 12),
              _buildEnhancedStatCard(
                'Estimated Cost',
                'RM${_totalEstimatedCost.toStringAsFixed(2)}',
                Icons.attach_money_rounded,
                widget.successColor,
              ),
              const SizedBox(width: 12),
              _buildEnhancedStatCard(
                'Completed',
                '$_completedItems',
                Icons.check_circle_rounded,
                widget.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: widget.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_basket_rounded,
                      size: 36,
                      color: widget.primaryColor.withOpacity(0.7),
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Your Shopping List',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Getting everything ready for your shopping trip',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: widget.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Shopping List',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: widget.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'There was a problem loading your shopping items. '
              'Please check your connection and try again.',
              style: TextStyle(
                fontSize: 15,
                color: widget.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: widget.textSecondary.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(color: widget.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadShoppingList,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 72,
                color: widget.primaryColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Shopping List is Empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: widget.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Start adding items to create your shopping list\nfor a more organized shopping experience',
              style: TextStyle(
                fontSize: 16,
                color: widget.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showQuickAddOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Items to List'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedShoppingList() {
    final pendingItems = _shoppingItems.where((item) => item['completed'] != true).toList();
    final completedItems = _shoppingItems.where((item) => item['completed'] == true).toList();

    return RefreshIndicator(
      backgroundColor: widget.surfaceColor,
      color: widget.primaryColor,
      onRefresh: _loadShoppingList,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // To Buy Section
            if (pendingItems.isNotEmpty) ...[
              _buildSectionHeader('To Buy', pendingItems.length, 'Tap to mark as purchased'),
              const SizedBox(height: 12),
              ...pendingItems.map((item) => _EnhancedShoppingListItem(
                item: item,
                onQuantityChanged: (newQuantity) => _updateItemQuantity(item['id'], newQuantity),
                onPurchased: () => _markItemAsPurchased(item['id']),
                onRemove: () => _removeItem(item['id']),
                primaryColor: widget.primaryColor,
                successColor: widget.successColor,
                errorColor: widget.errorColor,
                surfaceColor: widget.surfaceColor,
                textPrimary: widget.textPrimary,
                textSecondary: widget.textSecondary,
                textLight: widget.textLight,
              )).toList(),
              const SizedBox(height: 24),
            ],

            // Recently Purchased Section
            if (completedItems.isNotEmpty) ...[
              _buildCompletedSectionHeader('Recently Purchased', completedItems.length),
              const SizedBox(height: 12),
              ...completedItems.map((item) => _EnhancedCompletedShoppingListItem(
                item: item,
                onRestore: () => _uncompleteItem(item['id']),
                onRemove: () => _removeItem(item['id']),
                primaryColor: widget.primaryColor,
                successColor: widget.successColor,
                surfaceColor: widget.surfaceColor,
                textPrimary: widget.textPrimary,
                textSecondary: widget.textSecondary,
                textLight: widget.textLight,
              )).toList(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: widget.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.successColor, widget.successColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.check_circle_rounded, size: 20, color: widget.successColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.successColor, widget.successColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(
              'Long press to move back to shopping list',
              style: TextStyle(
                fontSize: 14,
                color: widget.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          onPressed: _showQuickAddOptions,
          backgroundColor: widget.primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Item'),
          heroTag: 'add_item',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ],
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _EnhancedAddItemDialog(
        onAddItem: (name, quantity, category, price) async {
          try {
            await _shoppingListService.addToShoppingList(
              widget.householdId,
              name,
              quantity,
              'custom_${DateTime.now().millisecondsSinceEpoch}',
              category: category,
              estimatedPrice: price,
            );
            Navigator.pop(context);
            await _loadShoppingList();
            _showSuccessSnackbar('$name added to list');
          } catch (e) {
            _showErrorSnackbar('Failed to add item: $e');
          }
        },
        primaryColor: widget.primaryColor,
        surfaceColor: widget.surfaceColor,
        textPrimary: widget.textPrimary,
        textSecondary: widget.textSecondary,
      ),
    );
  }
}

// Enhanced Shopping List Item with better animations and interactions
class _EnhancedShoppingListItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int) onQuantityChanged;
  final VoidCallback onPurchased;
  final VoidCallback onRemove;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const _EnhancedShoppingListItem({
    Key? key,
    required this.item,
    required this.onQuantityChanged,
    required this.onPurchased,
    required this.onRemove,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  @override
  __EnhancedShoppingListItemState createState() => __EnhancedShoppingListItemState();
}

class __EnhancedShoppingListItemState extends State<_EnhancedShoppingListItem> {
  bool _isTapped = false;

  void _handleTap() {
    setState(() => _isTapped = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isTapped = false);
        widget.onPurchased();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int quantity = widget.item['quantity'] as int? ?? 1;
    final String category = widget.item['category'] as String? ?? 'Other';
    final double estimatedPrice = (widget.item['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
    final double totalCost = quantity * estimatedPrice;
    final bool hasPrice = estimatedPrice > 0;

    return AnimatedScale(
      scale: _isTapped ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.surfaceColor,
              widget.surfaceColor.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Check indicator with gradient
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.2),
                          widget.primaryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_cart_rounded,
                      size: 18,
                      color: widget.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Item details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item['itemName'] ?? 'Unknown Item',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: widget.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Enhanced Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getCategoryColor(category).withOpacity(0.2),
                                    _getCategoryColor(category).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _getCategoryColor(category).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(category),
                                    size: 10,
                                    color: _getCategoryColor(category),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 6,
                                      color: _getCategoryColor(category),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (hasPrice)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.primaryColor.withOpacity(0.2),
                                      widget.primaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.attach_money_rounded,
                                      size: 14,
                                      color: widget.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      totalCost.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Enhanced Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor.withOpacity(0.1),
                          widget.primaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_rounded, size: 18),
                          onPressed: () => widget.onQuantityChanged(quantity - 1),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          color: widget.primaryColor,
                        ),
                        Container(
                          width: 32,
                          child: Text(
                            quantity.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: widget.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, size: 18),
                          onPressed: () => widget.onQuantityChanged(quantity + 1),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          color: widget.primaryColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Enhanced Delete button
                  Container(
                    decoration: BoxDecoration(
                      color: widget.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: widget.onRemove,
                      color: widget.errorColor,
                      tooltip: 'Remove Item',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    const colors = {
      'Food': Colors.red,
      'Beverages': Colors.blue,
      'Cleaning Supplies': Colors.green,
      'Personal Care': Colors.purple,
      'Medication': Colors.orange,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'Food': Icons.food_bank_rounded,
      'Beverages': Icons.local_drink_rounded,
      'Cleaning Supplies': Icons.cleaning_services_rounded,
      'Personal Care': Icons.person_rounded,
      'Medication': Icons.medical_services_rounded,
      'Other': Icons.shopping_basket_rounded,
    };
    return icons[category] ?? Icons.shopping_basket_rounded;
  }
}

// Enhanced Completed Shopping List Item
class _EnhancedCompletedShoppingListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRestore;
  final VoidCallback onRemove;
  final Color primaryColor;
  final Color successColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const _EnhancedCompletedShoppingListItem({
    Key? key,
    required this.item,
    required this.onRestore,
    required this.onRemove,
    required this.primaryColor,
    required this.successColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int quantity = item['quantity'] as int? ?? 1;
    final double estimatedPrice = (item['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
    final double totalCost = quantity * estimatedPrice;
    final bool hasPrice = estimatedPrice > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            successColor.withOpacity(0.08),
            successColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: successColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: successColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onLongPress: onRestore,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Long press to restore "${item['itemName']}"'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Enhanced Checkmark icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [successColor, successColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: successColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 16),

                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['itemName'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textLight,
                          decoration: TextDecoration.lineThrough,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        children: [
                          // Purchase info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 12, color: successColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Purchased',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: successColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasPrice)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.attach_money_rounded, size: 12, color: successColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    totalCost.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: successColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Enhanced Quantity display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [successColor.withOpacity(0.15), successColor.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: successColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      fontSize: 12,
                      color: successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Enhanced Action menu
                Container(
                  decoration: BoxDecoration(
                    color: textLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: textLight),
                    onSelected: (value) {
                      if (value == 'restore') {
                        onRestore();
                      } else if (value == 'remove') {
                        onRemove();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            const Text('Move back to list'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Remove permanently'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Quick Add Chip for common items
class _QuickAddChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QuickAddChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Add Item Dialog
class _EnhancedAddItemDialog extends StatefulWidget {
  final Function(String, int, String, double) onAddItem;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _EnhancedAddItemDialog({
    Key? key,
    required this.onAddItem,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
  }) : super(key: key);

  @override
  __EnhancedAddItemDialogState createState() => __EnhancedAddItemDialogState();
}

class __EnhancedAddItemDialogState extends State<_EnhancedAddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  int _quantity = 1;
  String _selectedCategory = 'Other';

  final _categories = [
    'Food',
    'Beverages',
    'Cleaning Supplies',
    'Personal Care',
    'Medication',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor.withOpacity(0.1), widget.primaryColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.primaryColor, widget.primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add New Item',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: widget.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: widget.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Item Name
              Text(
                'Item Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Organic Milk, Whole Wheat Bread...',
                  hintStyle: TextStyle(color: widget.textSecondary.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.2)),
                  ),
                  filled: true,
                  fillColor: widget.surfaceColor.withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: TextStyle(color: widget.textPrimary, fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Category and Price
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.2)),
                            ),
                            filled: true,
                            fillColor: widget.surfaceColor.withOpacity(0.8),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                style: TextStyle(color: widget.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price (RM)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: widget.textSecondary.withOpacity(0.2)),
                            ),
                            filled: true,
                            fillColor: widget.surfaceColor.withOpacity(0.8),
                            prefixText: 'RM ',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final price = double.tryParse(value);
                              if (price == null || price < 0) {
                                return 'Enter valid price';
                              }
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Enhanced Quantity
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.primaryColor.withOpacity(0.1), widget.primaryColor.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_rounded, size: 20),
                            onPressed: () {
                              setState(() {
                                if (_quantity > 1) _quantity--;
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            color: widget.primaryColor,
                          ),
                          Container(
                            width: 36,
                            child: Text(
                              _quantity.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: widget.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_rounded, size: 20),
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            color: widget.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Enhanced Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: widget.textSecondary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: widget.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final price = _priceController.text.isEmpty 
                              ? 0.0 
                              : double.tryParse(_priceController.text) ?? 0.0;
                          
                          widget.onAddItem(
                            _nameController.text.trim(),
                            _quantity,
                            _selectedCategory,
                            price,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}