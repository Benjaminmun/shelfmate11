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

class _ShoppingListPageState extends State<ShoppingListPage> {
  final ShoppingListService _shoppingListService = ShoppingListService();
  List<Map<String, dynamic>> _shoppingItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  double _totalEstimatedCost = 0.0;
  int _totalItems = 0;
  int _completedItems = 0;

  @override
  void initState() {
    super.initState();
    _loadShoppingList();
  }

  Future<void> _loadShoppingList() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🔄 Loading shopping list for household: ${widget.householdId}');
      final items = await _shoppingListService.getShoppingList(widget.householdId);
      
      print('✅ Loaded ${items.length} shopping list items');
      
      if (mounted) {
        setState(() {
          _shoppingItems = items;
          _isLoading = false;
          _calculateTotals();
        });
      }
    } catch (e) {
      print('❌ Error loading shopping list: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        title: Text(
          '${widget.householdName} Shopping List',
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
            IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: widget.successColor),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: widget.errorColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_completedItems',
                        style: TextStyle(
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
              onPressed: _clearCompletedItems,
              tooltip: 'Clear $_completedItems Completed Items',
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: widget.textSecondary),
            onPressed: _loadShoppingList,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading && !_hasError && _shoppingItems.isNotEmpty)
            _buildHeaderStats(),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _shoppingItems.isEmpty
                        ? _buildEmptyState()
                        : _buildShoppingList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        child: Icon(Icons.add_rounded),
        tooltip: 'Add Custom Item',
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          // Progress bar with percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'List Progress',
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
            height: 10,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * (completionPercentage / 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.primaryColor, widget.successColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                'Total Items',
                '$_totalItems',
                Icons.shopping_basket_rounded,
                widget.primaryColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Estimated Cost',
                'RM${_totalEstimatedCost.toStringAsFixed(2)}',
                Icons.attach_money_rounded,
                widget.successColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Completed',
                '$_completedItems/${_shoppingItems.length}',
                Icons.check_circle_rounded,
                widget.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: widget.textSecondary,
                fontWeight: FontWeight.w500,
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.shopping_basket_rounded,
                    size: 40,
                    color: widget.primaryColor.withOpacity(0.7),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Your List...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Getting your shopping items ready',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: widget.errorColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Unable to Load List',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There was an error loading your shopping list',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadShoppingList,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: widget.primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Shopping List is Empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add items from recommendations or manually\nusing the + button below',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Your First Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    final pendingItems = _shoppingItems.where((item) => item['completed'] != true).toList();
    final completedItems = _shoppingItems.where((item) => item['completed'] == true).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (pendingItems.isNotEmpty) ...[
            _buildSectionHeader('To Buy', pendingItems.length, 'Tap items to mark as purchased'),
            const SizedBox(height: 12),
            Expanded(
              flex: pendingItems.length,
              child: RefreshIndicator(
                backgroundColor: widget.surfaceColor,
                color: widget.primaryColor,
                onRefresh: _loadShoppingList,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: pendingItems.length,
                  itemBuilder: (context, index) => _ShoppingListItem(
                    item: pendingItems[index],
                    onQuantityChanged: (newQuantity) => _updateItemQuantity(
                      pendingItems[index]['id'],
                      newQuantity,
                    ),
                    onPurchased: () => _markItemAsPurchased(pendingItems[index]['id']),
                    onRemove: () => _removeItem(pendingItems[index]['id']),
                    primaryColor: widget.primaryColor,
                    successColor: widget.successColor,
                    errorColor: widget.errorColor,
                    surfaceColor: widget.surfaceColor,
                    textPrimary: widget.textPrimary,
                    textSecondary: widget.textSecondary,
                    textLight: widget.textLight,
                  ),
                ),
              ),
            ),
          ],

          if (completedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCompletedSectionHeader('Purchased Items', completedItems.length),
            const SizedBox(height: 12),
            Expanded(
              flex: completedItems.length,
              child: ListView.builder(
                itemCount: completedItems.length,
                itemBuilder: (context, index) => _CompletedShoppingListItem(
                  item: completedItems[index],
                  onRestore: () => _uncompleteItem(completedItems[index]['id']),
                  onRemove: () => _removeItem(completedItems[index]['id']),
                  primaryColor: widget.primaryColor,
                  successColor: widget.successColor,
                  surfaceColor: widget.surfaceColor,
                  textPrimary: widget.textPrimary,
                  textSecondary: widget.textSecondary,
                  textLight: widget.textLight,
                ),
              ),
            ),
          ],
        ],
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: widget.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: widget.successColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: widget.successColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: widget.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.successColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Long press to restore',
            style: TextStyle(
              fontSize: 12,
              color: widget.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
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

class _ShoppingListItem extends StatefulWidget {
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

  const _ShoppingListItem({
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
  __ShoppingListItemState createState() => __ShoppingListItemState();
}

class __ShoppingListItemState extends State<_ShoppingListItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _handleTap() {
    // Animate the purchase
    _animationController.forward().then((_) {
      widget.onPurchased();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int quantity = widget.item['quantity'] as int? ?? 1;
    final String category = widget.item['category'] as String? ?? 'general';
    final double estimatedPrice = (widget.item['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
    final double totalCost = quantity * estimatedPrice;
    final bool hasPrice = estimatedPrice > 0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: widget.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _handleTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Checkbox
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.primaryColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.shopping_cart_rounded,
                          size: 14,
                          color: widget.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item['itemName'] ?? 'Unknown Item',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Category badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(category).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getCategoryIcon(category),
                                        size: 12,
                                        color: _getCategoryColor(category),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        category.replaceAll('_', ' '),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _getCategoryColor(category),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                if (hasPrice) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: widget.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'RM${totalCost.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Quantity controls
                      Container(
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_rounded, size: 16),
                              onPressed: () => widget.onQuantityChanged(quantity - 1),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              color: widget.primaryColor,
                            ),
                            Container(
                              width: 30,
                              child: Text(
                                quantity.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: widget.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_rounded, size: 16),
                              onPressed: () => widget.onQuantityChanged(quantity + 1),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              color: widget.primaryColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Delete button
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: widget.onRemove,
                        color: widget.errorColor.withOpacity(0.6),
                        tooltip: 'Remove Item',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    const colors = {
      'perishables': Colors.red,
      'household_supplies': Colors.blue,
      'personal_care': Colors.purple,
      'medicines': Colors.orange,
      'beverages': Colors.teal,
      'snacks': Colors.amber,
      'cleaning_supplies': Colors.green,
      'general': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'perishables': Icons.food_bank_rounded,
      'household_supplies': Icons.home_rounded,
      'personal_care': Icons.person_rounded,
      'medicines': Icons.medical_services_rounded,
      'beverages': Icons.local_drink_rounded,
      'snacks': Icons.cookie_rounded,
      'cleaning_supplies': Icons.cleaning_services_rounded,
      'general': Icons.shopping_basket_rounded,
    };
    return icons[category] ?? Icons.shopping_basket_rounded;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _CompletedShoppingListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRestore;
  final VoidCallback onRemove;
  final Color primaryColor;
  final Color successColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const _CompletedShoppingListItem({
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: successColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: successColor.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: onRestore,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Checkmark icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: successColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),

                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['itemName'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textLight,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Purchase info
                          Icon(Icons.schedule_rounded, size: 12, color: textLight),
                          const SizedBox(width: 4),
                          Text(
                            'Purchased',
                            style: TextStyle(
                              fontSize: 12,
                              color: textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (hasPrice) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.attach_money_rounded, size: 12, color: successColor),
                            const SizedBox(width: 4),
                            Text(
                              'RM${totalCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: successColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Quantity display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      fontSize: 12,
                      color: successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Action buttons
                PopupMenuButton<String>(
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
                          Text('Move back to list'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Remove permanently'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final Function(String, int, String, double) onAddItem;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _AddItemDialog({
    Key? key,
    required this.onAddItem,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
  }) : super(key: key);

  @override
  __AddItemDialogState createState() => __AddItemDialogState();
}

class __AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  int _quantity = 1;
  String _selectedCategory = 'general';

  final _categories = [
    'general',
    'perishables',
    'household_supplies',
    'personal_care',
    'medicines',
    'beverages',
    'snacks',
    'cleaning_supplies',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_rounded, color: widget.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Item',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: widget.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Milk, Bread, Eggs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              color: widget.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price (RM)',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        prefixText: 'RM ',
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Quantity',
                    style: TextStyle(
                      color: widget.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.primaryColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              if (_quantity > 1) _quantity--;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          color: widget.primaryColor,
                        ),
                        Container(
                          width: 30,
                          child: Text(
                            _quantity.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _quantity++;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          color: widget.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
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
                      child: Text('Cancel', style: TextStyle(color: widget.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final price = _priceController.text.isEmpty 
                              ? 0.0 
                              : double.tryParse(_priceController.text) ?? 0.0;
                          
                          widget.onAddItem(
                            _nameController.text,
                            _quantity,
                            _selectedCategory,
                            price,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Item'),
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