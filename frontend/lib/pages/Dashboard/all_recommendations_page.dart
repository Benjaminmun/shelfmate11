import 'package:flutter/material.dart';
import 'package:frontend/services/inventory_recomendation_service.dart';
import '../../services/shopping_list_service.dart';
import 'shopping_list_page.dart';

class AllRecommendationsPage extends StatefulWidget {
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
  final Function(String, int, String) onAddToShoppingList;
  final Function(String) onNavigateToItem;

  const AllRecommendationsPage({
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
    required this.onAddToShoppingList,
    required this.onNavigateToItem,
  }) : super(key: key);

  @override
  _AllRecommendationsPageState createState() => _AllRecommendationsPageState();
}

class _AllRecommendationsPageState extends State<AllRecommendationsPage> {
  final InventoryRecommendationService _recommendationService =
      InventoryRecommendationService();
  final ShoppingListService _shoppingListService = ShoppingListService();

  List<Map<String, dynamic>> _allRecommendations = [];
  bool _isLoading = false;
  bool _hasError = false;
  Set<String> _itemsInCart = Set<String>();
  String _filterPriority = 'all';
  String _filterType = 'all';
  String _searchQuery = '';
  int _shoppingListCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllRecommendations();
    _loadCartState();
    _loadShoppingListCount();
  }

  Future<void> _loadAllRecommendations() async {
    if (widget.householdId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final recommendations = await _recommendationService
          .getSmartRecommendations(widget.householdId);

      if (mounted) {
        setState(() {
          _allRecommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _allRecommendations = [];
        });
      }
    }
  }

  Future<void> _loadCartState() async {
    try {
      final shoppingListItems = await _shoppingListService.getShoppingListItems(
        widget.householdId,
      );
      if (mounted) {
        setState(() {
          _itemsInCart = Set<String>.from(
            shoppingListItems.map((item) => item['id']?.toString() ?? ''),
          );
        });
      }
    } catch (e) {
      print('Error loading cart state: $e');
    }
  }

  Future<void> _loadShoppingListCount() async {
    try {
      final count = await _shoppingListService.getShoppingListCount(
        widget.householdId,
      );
      if (mounted) {
        setState(() {
          _shoppingListCount = count;
        });
      }
    } catch (e) {
      print('Error loading shopping list count: $e');
    }
  }

  Future<void> _toggleCartStatus(Map<String, dynamic> recommendation) async {
    final String itemId =
        recommendation['itemId'] ??
        'custom_${DateTime.now().millisecondsSinceEpoch}';
    final bool isCurrentlyInCart = _itemsInCart.contains(itemId);

    try {
      if (isCurrentlyInCart) {
        await _removeFromCart(itemId);
      } else {
        await _addToCart(recommendation);
      }
    } catch (e) {
      _showErrorSnackbar('Error updating cart: $e');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> recommendation) async {
    final String itemId =
        recommendation['itemId'] ??
        'custom_${DateTime.now().millisecondsSinceEpoch}';
    final String itemName = recommendation['itemName'] ?? 'Unknown Item';

    setState(() {
      _itemsInCart.add(itemId);
    });

    try {
      final result = await _recommendationService
          .addRecommendationToShoppingList(
            householdId: widget.householdId,
            recommendation: recommendation,
          );

      if (result['success'] == true) {
        _showSuccessSnackbar('$itemName added to cart');
        widget.onAddToShoppingList(itemName, 1, itemId);
        _loadShoppingListCount();
      } else {
        _showErrorSnackbar('Failed to add $itemName: ${result['error']}');
        setState(() {
          _itemsInCart.remove(itemId);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error adding $itemName to cart: $e');
      setState(() {
        _itemsInCart.remove(itemId);
      });
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    try {
      final result = await _shoppingListService.removeFromShoppingList(
        widget.householdId,
        itemId,
      );

      if (result['success'] == true) {
        setState(() {
          _itemsInCart.remove(itemId);
        });
        _showInfoSnackbar('Item removed from cart');
        _loadShoppingListCount();
      } else {
        _showErrorSnackbar('Failed to remove item: ${result['error']}');
      }
    } catch (e) {
      _showErrorSnackbar('Error removing item: $e');
    }
  }

  void _navigateToShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListPage(
          householdId: widget.householdId,
          householdName: widget.householdName,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          accentColor: widget.accentColor,
          successColor: widget.successColor,
          warningColor: widget.warningColor,
          errorColor: widget.errorColor,
          backgroundColor: widget.backgroundColor,
          surfaceColor: widget.surfaceColor,
          textPrimary: widget.textPrimary,
          textSecondary: widget.textSecondary,
          textLight: widget.textLight,
        ),
      ),
    ).then((_) {
      _loadCartState();
      _loadShoppingListCount();
    });
  }

  List<Map<String, dynamic>> get _filteredRecommendations {
    List<Map<String, dynamic>> filtered = _allRecommendations;

    // Apply priority filter
    if (_filterPriority != 'all') {
      filtered = filtered
          .where((rec) => rec['priority'] == _filterPriority)
          .toList();
    }

    // Apply type filter
    if (_filterType != 'all') {
      filtered = filtered.where((rec) {
        final type = rec['type'] as String? ?? '';
        return type.contains(_filterType);
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((rec) {
        final itemName = rec['itemName'] as String? ?? '';
        final title = rec['title'] as String? ?? '';
        final message = rec['message'] as String? ?? '';

        return itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            message.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedRecommendations {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final recommendation in _filteredRecommendations) {
      final priority = recommendation['priority'] as String? ?? 'medium';
      if (!grouped.containsKey(priority)) {
        grouped[priority] = [];
      }
      grouped[priority]!.add(recommendation);
    }

    // Sort groups by priority order: high, medium, low
    final sortedGroups = <String, List<Map<String, dynamic>>>{};
    if (grouped.containsKey('high')) {
      sortedGroups['high'] = grouped['high']!;
    }
    if (grouped.containsKey('medium')) {
      sortedGroups['medium'] = grouped['medium']!;
    }
    if (grouped.containsKey('low')) {
      sortedGroups['low'] = grouped['low']!;
    }

    return sortedGroups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Column(
        children: [
          // App Bar
          _buildAppBar(),

          // Filters and Search
          _buildFilters(),

          // Statistics
          if (!_isLoading && !_hasError && _allRecommendations.isNotEmpty)
            _buildStatistics(),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: widget.primaryColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Recommendations',
                      style: TextStyle(
                        color: widget.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_allRecommendations.length} items',
                      style: TextStyle(color: widget.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Shopping Cart Icon
              _ShoppingCartIcon(
                count: _shoppingListCount,
                onPressed: _navigateToShoppingList,
                primaryColor: widget.primaryColor,
              ),
              const SizedBox(width: 8),

              // Refresh Button
              Container(
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: widget.primaryColor),
                  onPressed: _loadAllRecommendations,
                  tooltip: 'Refresh recommendations',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        border: Border(
          bottom: BorderSide(color: widget.backgroundColor.withOpacity(0.5)),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search recommendations...',
                hintStyle: TextStyle(color: widget.textLight),
                prefixIcon: Icon(Icons.search_rounded, color: widget.textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(color: widget.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _filterPriority,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Priorities'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High Priority'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium Priority'),
                    ),
                    DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterPriority = value.toString();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  value: _filterType,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(
                      value: 'stock',
                      child: Text('Stock Alerts'),
                    ),
                    DropdownMenuItem(
                      value: 'expiry',
                      child: Text('Expiry Alerts'),
                    ),
                    DropdownMenuItem(value: 'usage', child: Text('Usage Tips')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterType = value.toString();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: TextStyle(color: widget.textPrimary, fontSize: 14),
          icon: Icon(Icons.arrow_drop_down_rounded, color: widget.textLight),
          dropdownColor: widget.surfaceColor,
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final highCount = _allRecommendations
        .where((rec) => rec['priority'] == 'high')
        .length;
    final mediumCount = _allRecommendations
        .where((rec) => rec['priority'] == 'medium')
        .length;
    final inCartCount = _itemsInCart.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        border: Border(
          bottom: BorderSide(color: widget.backgroundColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            count: _allRecommendations.length,
            label: 'Total',
            color: widget.primaryColor,
          ),
          _StatItem(count: highCount, label: 'High', color: widget.errorColor),
          _StatItem(
            count: mediumCount,
            label: 'Medium',
            color: widget.warningColor,
          ),
          _StatItem(
            count: inCartCount,
            label: 'In Cart',
            color: widget.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    } else if (_hasError) {
      return _buildErrorState();
    } else if (_allRecommendations.isEmpty) {
      return _buildEmptyState();
    } else if (_filteredRecommendations.isEmpty) {
      return _buildNoResultsState();
    } else {
      return _buildRecommendationsList();
    }
  }

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
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing Your Inventory...',
            style: TextStyle(
              color: widget.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking stock levels, expiry dates, and consumption patterns',
            style: TextStyle(color: widget.textLight, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Unable to Load Recommendations',
              style: TextStyle(
                color: widget.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There was an error analyzing your inventory data. '
              'Please check your connection and try again.',
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAllRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: widget.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: widget.successColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Everything Looks Great! 🎉',
              style: TextStyle(
                color: widget.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your inventory is well managed with optimal stock levels '
              'and no urgent issues detected.',
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusChip(
                  label: 'Stock Levels',
                  value: 'Optimal',
                  color: widget.successColor,
                  icon: Icons.inventory_2_rounded,
                ),
                _StatusChip(
                  label: 'Expiry Dates',
                  value: 'No Issues',
                  color: widget.successColor,
                  icon: Icons.calendar_today_rounded,
                ),
                _StatusChip(
                  label: 'Consumption',
                  value: 'Stable',
                  color: widget.successColor,
                  icon: Icons.timeline_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Matching Recommendations',
              style: TextStyle(
                color: widget.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your filters or search terms to find what you\'re looking for.',
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterPriority = 'all';
                  _filterType = 'all';
                  _searchQuery = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor.withOpacity(0.1),
                foregroundColor: widget.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    final grouped = _groupedRecommendations;

    return RefreshIndicator(
      backgroundColor: widget.surfaceColor,
      color: widget.primaryColor,
      onRefresh: () async {
        await _loadAllRecommendations();
        await _loadCartState();
        await _loadShoppingListCount();
      },
      child: ListView(
        children: [
          const SizedBox(height: 8),
          for (final entry in grouped.entries)
            _RecommendationGroup(
              priority: entry.key,
              recommendations: entry.value,
              itemsInCart: _itemsInCart,
              onToggleCart: _toggleCartStatus,
              onViewDetails: _showRecommendationDetails,
              primaryColor: widget.primaryColor,
              successColor: widget.successColor,
              errorColor: widget.errorColor,
              warningColor: widget.warningColor,
              surfaceColor: widget.surfaceColor,
              backgroundColor: widget.backgroundColor,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              textLight: widget.textLight,
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showRecommendationDetails(Map<String, dynamic> recommendation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _RecommendationDetailsSheet(
        recommendation: recommendation,
        isInCart: _itemsInCart.contains(recommendation['itemId']),
        onToggleCart: () => _toggleCartStatus(recommendation),
        onViewItem: () {
          Navigator.pop(context);
          widget.onNavigateToItem(recommendation['itemId']);
        },
        primaryColor: widget.primaryColor,
        successColor: widget.successColor,
        errorColor: widget.errorColor,
        surfaceColor: widget.surfaceColor,
        textPrimary: widget.textPrimary,
        textSecondary: widget.textSecondary,
        textLight: widget.textLight,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: widget.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: widget.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: widget.accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Reusable Widget Components

class _ShoppingCartIcon extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;
  final Color primaryColor;

  const _ShoppingCartIcon({
    Key? key,
    required this.count,
    required this.onPressed,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.shopping_cart_rounded, size: 22),
            onPressed: onPressed,
            tooltip: 'View Shopping List ($count items)',
            color: primaryColor,
          ),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatItem({
    Key? key,
    required this.count,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatusChip({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationGroup extends StatelessWidget {
  final String priority;
  final List<Map<String, dynamic>> recommendations;
  final Set<String> itemsInCart;
  final Function(Map<String, dynamic>) onToggleCart;
  final Function(Map<String, dynamic>) onViewDetails;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;
  final Color warningColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const _RecommendationGroup({
    Key? key,
    required this.priority,
    required this.recommendations,
    required this.itemsInCart,
    required this.onToggleCart,
    required this.onViewDetails,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
    required this.warningColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  Color get _priorityColor {
    switch (priority) {
      case 'high':
        return errorColor;
      case 'medium':
        return warningColor;
      case 'low':
        return successColor;
      default:
        return primaryColor;
    }
  }

  String get _priorityLabel {
    switch (priority) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return 'Recommendations';
    }
  }

  IconData get _priorityIcon {
    switch (priority) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      case 'low':
        return Icons.lightbulb_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _priorityColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_priorityIcon, color: _priorityColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _priorityLabel,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${recommendations.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recommendations List
          ...recommendations.map(
            (recommendation) => _RecommendationItem(
              recommendation: recommendation,
              isInCart: itemsInCart.contains(recommendation['itemId']),
              onToggleCart: () => onToggleCart(recommendation),
              onViewDetails: () => onViewDetails(recommendation),
              priorityColor: _priorityColor,
              surfaceColor: surfaceColor,
              backgroundColor: backgroundColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              textLight: textLight,
              successColor: successColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final bool isInCart;
  final VoidCallback onToggleCart;
  final VoidCallback onViewDetails;
  final Color priorityColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color successColor;

  const _RecommendationItem({
    Key? key,
    required this.recommendation,
    required this.isInCart,
    required this.onToggleCart,
    required this.onViewDetails,
    required this.priorityColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.successColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = Color(recommendation['color'] as int);
    final IconData icon = recommendation['icon'] as IconData;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: backgroundColor.withOpacity(0.5)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onViewDetails,
          borderRadius: BorderRadius.circular(0),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isInCart
                        ? successColor.withOpacity(0.2)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isInCart
                          ? successColor.withOpacity(0.4)
                          : color.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    isInCart ? Icons.check_circle_rounded : icon,
                    color: isInCart ? successColor : color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation['message'],
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (recommendation['type'] as String? ?? '')
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: priorityColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isInCart ? 'In Cart' : 'Add to Cart',
                            style: TextStyle(
                              fontSize: 12,
                              color: isInCart ? successColor : textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Button
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    isInCart
                        ? Icons.remove_shopping_cart_rounded
                        : Icons.add_shopping_cart_rounded,
                    color: isInCart ? successColor : priorityColor,
                    size: 20,
                  ),
                  onPressed: onToggleCart,
                  tooltip: isInCart ? 'Remove from cart' : 'Add to cart',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final bool isInCart;
  final VoidCallback onToggleCart;
  final VoidCallback onViewItem;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  const _RecommendationDetailsSheet({
    Key? key,
    required this.recommendation,
    required this.isInCart,
    required this.onToggleCart,
    required this.onViewItem,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
  }) : super(key: key);

  Color get _priorityColor {
    final priority = recommendation['priority'] as String? ?? 'medium';
    switch (priority) {
      case 'high':
        return errorColor;
      case 'medium':
        return primaryColor;
      case 'low':
        return successColor;
      default:
        return primaryColor;
    }
  }

  IconData get _typeIcon {
    final type = recommendation['type'] as String? ?? '';
    if (type.contains('stock')) return Icons.inventory_2_rounded;
    if (type.contains('expiry')) return Icons.calendar_today_rounded;
    if (type.contains('usage')) return Icons.timeline_rounded;
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final analysis =
        recommendation['analysisSummary'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: _priorityColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation['title'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation['itemName'] ?? 'Unknown Item',
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Priority Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              (recommendation['priority'] as String? ?? 'medium').toUpperCase(),
              style: TextStyle(
                color: _priorityColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          Text(
            recommendation['message'],
            style: TextStyle(fontSize: 16, color: textPrimary, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Analysis Details
          if (analysis.isNotEmpty) _buildAnalysisDetails(analysis),

          const Spacer(),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewItem,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Item Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onToggleCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInCart ? errorColor : successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isInCart ? 'Remove from Cart' : 'Add to Cart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisDetails(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (analysis['daysOfSupply'] != null)
          _AnalysisRow(
            label: 'Days of Supply',
            value:
                '${(analysis['daysOfSupply'] as double).toStringAsFixed(1)} days',
            color: textPrimary,
          ),
        if (analysis['consumptionRate'] != null)
          _AnalysisRow(
            label: 'Usage Rate',
            value:
                '${(analysis['consumptionRate'] as double).toStringAsFixed(2)}/day',
            color: textPrimary,
          ),
        if (analysis['stockoutProbability'] != null)
          _AnalysisRow(
            label: 'Stockout Risk',
            value:
                '${((analysis['stockoutProbability'] as double) * 100).toStringAsFixed(0)}%',
            color: textPrimary,
          ),
        if (analysis['expiryRisk'] != null)
          _AnalysisRow(
            label: 'Expiry Risk',
            value:
                '${((analysis['expiryRisk'] as double) * 100).toStringAsFixed(0)}%',
            color: textPrimary,
          ),
        if (analysis['minStockLevel'] != null)
          _AnalysisRow(
            label: 'Minimum Stock',
            value: '${analysis['minStockLevel']} units',
            color: textPrimary,
          ),
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalysisRow({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
