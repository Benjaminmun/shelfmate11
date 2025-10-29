import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:frontend/services/inventory_reccomendation_service.dart';
import '../services/shopping_list_service.dart';
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

class _AllRecommendationsPageState extends State<AllRecommendationsPage> with SingleTickerProviderStateMixin {
  final InventoryRecommendationService _recommendationService = InventoryRecommendationService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  
  List<Map<String, dynamic>> _smartRecommendations = [];
  bool _isRecommendationsLoading = false;
  bool _hasError = false;
  bool _showCategoryView = false;
  int _shoppingListCount = 0;
  Set<String> _itemsInCart = Set<String>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  List<String> _selectedCategories = [];
  List<String> _selectedPriorities = [];
  bool _showNotificationAlert = true; // Add this flag for notification alert

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadSmartRecommendations();
    _loadShoppingListCount();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSmartRecommendations() async {
    if (widget.householdId.isEmpty) return;
    
    setState(() {
      _isRecommendationsLoading = true;
      _hasError = false;
    });

    try {
      print('🔄 Loading all smart recommendations for household: ${widget.householdId}');
      final recommendations = await _recommendationService.getSmartRecommendations(widget.householdId);
      
      print('✅ Loaded ${recommendations.length} recommendations');
      
      if (mounted) {
        setState(() {
          _smartRecommendations = recommendations;
          _isRecommendationsLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isRecommendationsLoading = false;
          _hasError = true;
          _smartRecommendations = [];
        });
      }
    }
  }

  Future<void> _loadShoppingListCount() async {
    try {
      final count = await _shoppingListService.getShoppingListCount(widget.householdId);
      if (mounted) {
        setState(() {
          _shoppingListCount = count;
        });
      }
    } catch (e) {
      print('❌ Error loading shopping list count: $e');
    }
  }

  Future<void> _refreshRecommendations() async {
    setState(() {
      _smartRecommendations = [];
      _itemsInCart.clear();
    });
    await Future.wait([
      _loadSmartRecommendations(),
      _loadShoppingListCount(),
    ]);
  }

  void _toggleCategoryView() {
    setState(() {
      _showCategoryView = !_showCategoryView;
    });
  }

  void _dismissNotificationAlert() {
    setState(() {
      _showNotificationAlert = false;
    });
  }

  void _navigateToShoppingList() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ShoppingListPage(
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) {
      _loadShoppingListCount();
      _itemsInCart.clear();
    });
  }

  Future<void> _toggleCartStatus(Map<String, dynamic> recommendation) async {
    final String itemId = recommendation['itemId'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final String itemName = recommendation['itemName'] ?? 'Unknown Item';
    
    print('🔄 Toggling cart status for: $itemName (ID: $itemId)');
    
    final bool isCurrentlyInCart = _itemsInCart.contains(itemId);

    try {
      if (isCurrentlyInCart) {
        // Remove from cart
        await _removeFromCart(itemId);
      } else {
        // Add to cart
        await _addToCart(recommendation);
      }
    } catch (e) {
      print('❌ Error toggling cart status: $e');
      _showEnhancedSnackbar(
        message: 'Error updating cart: $e',
        icon: Icons.error_rounded,
        color: widget.errorColor,
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> recommendation) async {
    final String itemId = recommendation['itemId'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final String itemName = recommendation['itemName'] ?? 'Unknown Item';
    
    print('🛒 Adding to cart: $itemName (ID: $itemId)');
    
    setState(() {
      _itemsInCart.add(itemId);
    });

    try {
      final result = await _recommendationService.addRecommendationToShoppingList(
        householdId: widget.householdId,
        recommendation: recommendation,
      );

      if (result['success'] == true) {
        _showEnhancedSnackbar(
          message: '$itemName added to cart',
          icon: Icons.check_circle_rounded,
          color: widget.successColor,
        );
        print('✅ Successfully added to cart: $itemName');
        
        _loadShoppingListCount();
        
        final quantity = 1; // Always use quantity 1
        widget.onAddToShoppingList(itemName, quantity, itemId);
      } else {
        _showEnhancedSnackbar(
          message: 'Failed to add $itemName: ${result['error']}',
          icon: Icons.error_rounded,
          color: widget.errorColor,
        );
        setState(() {
          _itemsInCart.remove(itemId);
        });
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      _showEnhancedSnackbar(
        message: 'Error adding $itemName to cart: $e',
        icon: Icons.error_rounded,
        color: widget.errorColor,
      );
      setState(() {
        _itemsInCart.remove(itemId);
      });
    }
  }

  Future<void> _removeFromCart(String itemId) async {
    print('🗑️ Removing from cart: $itemId');
    
    try {
      final result = await _shoppingListService.removeFromShoppingList(widget.householdId, itemId);
      
      if (result['success'] == true) {
        setState(() {
          _itemsInCart.remove(itemId);
        });
        _showEnhancedSnackbar(
          message: 'Item removed from cart',
          icon: Icons.remove_shopping_cart_rounded,
          color: widget.accentColor,
        );
        _loadShoppingListCount();
      } else {
        _showEnhancedSnackbar(
          message: 'Failed to remove item: ${result['error']}',
          icon: Icons.error_rounded,
          color: widget.errorColor,
        );
      }
    } catch (e) {
      print('❌ Error removing from cart: $e');
      _showEnhancedSnackbar(
        message: 'Error removing item: $e',
        icon: Icons.error_rounded,
        color: widget.errorColor,
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRecommendations {
    var filtered = _smartRecommendations;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((rec) =>
        rec['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        rec['message'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        rec['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((rec) => 
        _selectedCategories.contains(rec['category'])
      ).toList();
    }

    // Priority filter
    if (_selectedPriorities.isNotEmpty) {
      filtered = filtered.where((rec) => 
        _selectedPriorities.contains(rec['priority'])
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecommendations = _filteredRecommendations;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Recommendations'),
            if (filteredRecommendations.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${filteredRecommendations.length} items',
                  key: ValueKey(filteredRecommendations.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: widget.primaryColor.withOpacity(0.5),
        actions: [
          // Shopping cart with improved badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart_rounded),
                onPressed: _navigateToShoppingList,
                tooltip: 'View Shopping List',
              ),
              if (_shoppingListCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _shoppingListCount > 99 ? '99+' : '$_shoppingListCount',
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
        ],
      ),
      body: Column(
        children: [
          // Notification Alert Banner (NEW)
          if (_showNotificationAlert && filteredRecommendations.isNotEmpty)
            _buildNotificationAlert(),

          // Search and Filter Bar
          _buildSearchFilterBar(),
          
          // Stats Overview
          if (!_isRecommendationsLoading && !_hasError && filteredRecommendations.isNotEmpty)
            _buildEnhancedStatsOverview(),

          // Main Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  // NEW: Notification Alert Banner
  Widget _buildNotificationAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            widget.warningColor.withOpacity(0.9),
            widget.accentColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.warningColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Recommendations Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on your inventory analysis and consumption patterns',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: _dismissNotificationAlert,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tight(Size(32, 32)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        border: Border(
          bottom: BorderSide(color: widget.primaryColor.withOpacity(0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search recommendations...',
                hintStyle: TextStyle(color: widget.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, color: widget.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Chips
          Row(
            children: [
              _buildFilterChip(
                label: 'View',
                icon: _showCategoryView ? Icons.list_rounded : Icons.category_rounded,
                isSelected: false,
                onTap: _toggleCategoryView,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Filter',
                icon: Icons.filter_list_rounded,
                isSelected: _selectedCategories.isNotEmpty || _selectedPriorities.isNotEmpty,
                onTap: _showFilterDialog,
              ),
              const Spacer(),
              if (_selectedCategories.isNotEmpty || _selectedPriorities.isNotEmpty || _searchQuery.isNotEmpty)
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Clear', style: TextStyle(color: widget.primaryColor)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor.withOpacity(0.1) : widget.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.primaryColor : widget.textLight.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? widget.primaryColor : widget.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? widget.primaryColor : widget.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatsOverview() {
    final filtered = _filteredRecommendations;
    final totalItems = filtered.length;
    final urgentItems = filtered.where((rec) => rec['priority'] == 'high').length;
    final inCartItems = filtered.where((rec) => _itemsInCart.contains(rec['itemId'])).length;
    final completionPercentage = totalItems > 0 ? (inCartItems / totalItems) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.primaryColor.withOpacity(0.05),
            widget.primaryColor.withOpacity(0.02),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: widget.primaryColor.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Progress Bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  width: MediaQuery.of(context).size.width * (completionPercentage / 100) * 0.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.successColor, widget.primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            children: [
              _buildStatItem('Total', '$totalItems', Icons.auto_awesome_rounded, widget.primaryColor),
              const SizedBox(width: 16),
              _buildStatItem('Urgent', '$urgentItems', Icons.warning_rounded, widget.errorColor),
              const SizedBox(width: 16),
              _buildStatItem('In Cart', '$inCartItems', Icons.shopping_cart_rounded, widget.successColor),
              const Spacer(),
              Text(
                '${completionPercentage.toStringAsFixed(0)}% Complete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: widget.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isRecommendationsLoading) {
      return _buildLoadingState();
    } else if (_hasError) {
      return _buildErrorState();
    } else if (_filteredRecommendations.isEmpty) {
      return _buildEmptyState();
    } else {
      return _buildRecommendationsContent();
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerRecommendation(),
    );
  }

  Widget _buildShimmerRecommendation() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Shimmer.fromColors(
        baseColor: widget.surfaceColor.withOpacity(0.5),
        highlightColor: widget.surfaceColor.withOpacity(0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Container(
              width: 250,
              height: 12,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
              child: Icon(Icons.error_outline_rounded, size: 60, color: widget.errorColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Recommendations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: widget.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(
                fontSize: 16,
                color: widget.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshRecommendations,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: widget.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 60,
                  color: widget.successColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Inventory Well Managed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: widget.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty || _selectedCategories.isNotEmpty || _selectedPriorities.isNotEmpty
                    ? 'No recommendations match your current filters.'
                    : 'Your smart inventory system is working perfectly. No recommendations needed at this time.',
                style: TextStyle(
                  fontSize: 16,
                  color: widget.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_searchQuery.isNotEmpty || _selectedCategories.isNotEmpty || _selectedPriorities.isNotEmpty)
                ElevatedButton(
                  onPressed: _clearFilters,
                  child: Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _showCategoryView ? _buildCategoryView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    final filtered = _filteredRecommendations;
    final urgentItems = filtered.where((rec) => rec['priority'] == 'high').toList();
    final otherItems = filtered.where((rec) => rec['priority'] != 'high').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (urgentItems.isNotEmpty) ...[
          _buildSectionHeader('Urgent Items', urgentItems.length, widget.errorColor),
          const SizedBox(height: 16),
          ...urgentItems.asMap().entries.map((entry) => 
            _AdvancedRecommendationItem(
              recommendation: entry.value,
              index: entry.key,
              onTap: () => _handleRecommendationAction(entry.value),
              onToggleCart: () => _toggleCartStatus(entry.value),
              isInCart: _itemsInCart.contains(entry.value['itemId']),
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              textLight: widget.textLight,
              backgroundColor: widget.backgroundColor,
              surfaceColor: widget.surfaceColor,
              successColor: widget.successColor,
              primaryColor: widget.primaryColor,
              warningColor: widget.warningColor,
              errorColor: widget.errorColor,
            )
          ).toList(),
          const SizedBox(height: 24),
        ],
        
        if (otherItems.isNotEmpty) ...[
          _buildSectionHeader('Other Recommendations', otherItems.length, widget.primaryColor),
          const SizedBox(height: 16),
          ...otherItems.asMap().entries.map((entry) => 
            _AdvancedRecommendationItem(
              recommendation: entry.value,
              index: entry.key,
              onTap: () => _handleRecommendationAction(entry.value),
              onToggleCart: () => _toggleCartStatus(entry.value),
              isInCart: _itemsInCart.contains(entry.value['itemId']),
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              textLight: widget.textLight,
              backgroundColor: widget.backgroundColor,
              surfaceColor: widget.surfaceColor,
              successColor: widget.successColor,
              primaryColor: widget.primaryColor,
              warningColor: widget.warningColor,
              errorColor: widget.errorColor,
            )
          ).toList(),
        ],
      ],
    );
  }

  Widget _buildCategoryView() {
    final Map<String, List<Map<String, dynamic>>> categorized = {};
    
    for (final recommendation in _filteredRecommendations) {
      final category = recommendation['category'] as String? ?? 'general';
      categorized.putIfAbsent(category, () => []).add(recommendation);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...categorized.entries.map((entry) => 
          _AdvancedCategorySection(
            category: entry.key,
            recommendations: entry.value,
            onTap: _handleRecommendationAction,
            onToggleCart: _toggleCartStatus,
            itemsInCart: _itemsInCart,
            textPrimary: widget.textPrimary,
            textSecondary: widget.textSecondary,
            textLight: widget.textLight,
            surfaceColor: widget.surfaceColor,
            primaryColor: widget.primaryColor,
            errorColor: widget.errorColor,
          )
        ).toList(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count items',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    final categories = _smartRecommendations.map((rec) => rec['category'] as String).toSet().toList();
    final priorities = _smartRecommendations.map((rec) => rec['priority'] as String).toSet().toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
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
                'Filter Recommendations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: categories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(_formatCategoryName(category)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    backgroundColor: widget.backgroundColor,
                    selectedColor: widget.primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: isSelected ? widget.primaryColor : widget.textSecondary,
                    ),
                    checkmarkColor: widget.primaryColor,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: priorities.map((priority) {
                  final isSelected = _selectedPriorities.contains(priority);
                  return FilterChip(
                    label: Text(priority.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedPriorities.add(priority);
                        } else {
                          _selectedPriorities.remove(priority);
                        }
                      });
                    },
                    backgroundColor: widget.backgroundColor,
                    selectedColor: _getPriorityColor(priority).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: isSelected ? _getPriorityColor(priority) : widget.textSecondary,
                    ),
                    checkmarkColor: _getPriorityColor(priority),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 30),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      child: Text('Clear All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategories.clear();
      _selectedPriorities.clear();
    });
  }

  String _formatCategoryName(String category) {
    return category.replaceAll('_', ' ').toUpperCase();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return widget.errorColor;
      case 'medium':
        return widget.warningColor;
      default:
        return widget.primaryColor;
    }
  }

  void _handleRecommendationAction(Map<String, dynamic> recommendation) {
    final String? itemId = recommendation['itemId'] as String?;
    
    if (itemId == null) {
      _showEnhancedSnackbar(
        message: 'Invalid recommendation: missing item ID',
        icon: Icons.error_rounded,
        color: widget.errorColor,
      );
      return;
    }

    // Show detailed dialog for the recommendation
    _showRecommendationDetails(recommendation);
  }

  void _showRecommendationDetails(Map<String, dynamic> recommendation) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: widget.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(recommendation['color'] as int).withOpacity(0.8),
                          Color(recommendation['color'] as int).withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      recommendation['icon'] as IconData,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation['title'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: widget.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                recommendation['message'],
                style: TextStyle(
                  fontSize: 14,
                  color: widget.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    _itemsInCart.contains(recommendation['itemId']) 
                        ? Icons.remove_shopping_cart_rounded 
                        : Icons.add_shopping_cart_rounded,
                  ),
                  label: Text(
                    _itemsInCart.contains(recommendation['itemId']) 
                        ? 'Remove from Cart' 
                        : 'Add to Cart',
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleCartStatus(recommendation);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _itemsInCart.contains(recommendation['itemId']) 
                        ? widget.errorColor 
                        : widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnhancedSnackbar({
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: widget.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ... rest of the code remains the same (_AdvancedCategorySection, _AdvancedRecommendationItem, _DetailChip)


class _AdvancedCategorySection extends StatefulWidget {
  final String category;
  final List<Map<String, dynamic>> recommendations;
  final Function(Map<String, dynamic>) onTap;
  final Function(Map<String, dynamic>) onToggleCart;
  final Set<String> itemsInCart;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color surfaceColor;
  final Color primaryColor;
  final Color errorColor;

  const _AdvancedCategorySection({
    Key? key,
    required this.category,
    required this.recommendations,
    required this.onTap,
    required this.onToggleCart,
    required this.itemsInCart,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.surfaceColor,
    required this.primaryColor,
    required this.errorColor,
  }) : super(key: key);

  @override
  State<_AdvancedCategorySection> createState() => _AdvancedCategorySectionState();
}

class _AdvancedCategorySectionState extends State<_AdvancedCategorySection> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heightAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final urgentCount = widget.recommendations.where((r) => r['priority'] == 'high').length;
    final inCartCount = widget.recommendations.where((r) => widget.itemsInCart.contains(r['itemId'])).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Enhanced category header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpansion,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getCategoryColor(widget.category).withOpacity(0.8),
                            _getCategoryColor(widget.category).withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _getCategoryColor(widget.category).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getCategoryIcon(widget.category),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatCategoryName(widget.category),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: widget.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.recommendations.length} items • $inCartCount in cart',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badges
                    Row(
                      children: [
                        if (urgentCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_rounded, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(
                                  '$urgentCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 300),
                          turns: _isExpanded ? 0.5 : 0,
                          child: Icon(
                            Icons.expand_more_rounded,
                            color: widget.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Animated expandable content
          SizeTransition(
            sizeFactor: _heightAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: widget.recommendations.asMap().entries.map((entry) => 
                  _AdvancedRecommendationItem(
                    recommendation: entry.value,
                    index: entry.key,
                    onTap: () => widget.onTap(entry.value),
                    onToggleCart: () => widget.onToggleCart(entry.value),
                    isInCart: widget.itemsInCart.contains(entry.value['itemId']),
                    textPrimary: widget.textPrimary,
                    textSecondary: widget.textSecondary,
                    textLight: widget.textLight,
                    backgroundColor: widget.surfaceColor,
                    surfaceColor: widget.surfaceColor,
                    successColor: Colors.green,
                    primaryColor: widget.primaryColor,
                    warningColor: Colors.orange,
                    errorColor: widget.errorColor,
                  )
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category.replaceAll('_', ' ').toUpperCase();
  }

  IconData _getCategoryIcon(String category) {
    const icons = {
      'perishables': Icons.agriculture_rounded,
      'household_supplies': Icons.home_rounded,
      'personal_care': Icons.person_rounded,
      'medicines': Icons.medical_services_rounded,
      'beverages': Icons.local_drink_rounded,
      'snacks': Icons.emoji_food_beverage_rounded,
      'cleaning_supplies': Icons.cleaning_services_rounded,
      'frozen_foods': Icons.ac_unit_rounded,
      'pantry': Icons.kitchen_rounded,
    };
    return icons[category] ?? Icons.inventory_2_rounded;
  }

  Color _getCategoryColor(String category) {
    const colors = {
      'perishables': Colors.red,
      'household_supplies': Colors.blue,
      'personal_care': Colors.purple,
      'medicines': Colors.orange,
      'beverages': Colors.teal,
      'snacks': Colors.amber,
      'cleaning_supplies': Colors.grey,
      'frozen_foods': Colors.cyan,
      'pantry': Colors.brown,
    };
    return colors[category] ?? Colors.grey;
  }
}

class _AdvancedRecommendationItem extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onToggleCart;
  final bool isInCart;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color successColor;
  final Color primaryColor;
  final Color warningColor;
  final Color errorColor;

  const _AdvancedRecommendationItem({
    Key? key,
    required this.recommendation,
    required this.index,
    required this.onTap,
    required this.onToggleCart,
    required this.isInCart,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.successColor,
    required this.primaryColor,
    required this.warningColor,
    required this.errorColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = Color(recommendation['color'] as int);
    final IconData icon = recommendation['icon'] as IconData;
    final String priority = recommendation['priority'] as String;
    final String category = recommendation['category'] as String? ?? 'general';
    final bool isCategoryAdjusted = recommendation['categoryAdjusted'] == true;
    final double? preferenceScore = recommendation['preferenceScore'] as double?;
    final bool isAIGenerated = recommendation['aiGenerated'] == true;
    final int? daysUntilExpiry = recommendation['daysUntilExpiry'] as int?;
    final double? consumptionRate = recommendation['consumptionRate'] as double?;
    final int? currentStock = recommendation['currentStock'] as int?;
    final bool isUrgent = priority == 'high';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isInCart ? successColor.withOpacity(0.08) : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isUrgent ? 0.15 : 0.08),
            blurRadius: isUrgent ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isInCart 
            ? Border.all(color: successColor.withOpacity(0.3), width: 2)
            : (isUrgent 
                ? Border.all(color: errorColor.withOpacity(0.3), width: 2)
                : null),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleCart, // Toggle cart status on tap
          borderRadius: BorderRadius.circular(20),
          splashColor: isInCart ? successColor.withOpacity(0.1) : color.withOpacity(0.1),
          highlightColor: isInCart ? successColor.withOpacity(0.05) : color.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority indicator with improved design
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isInCart ? successColor : _getPriorityColor(priority),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: (isInCart ? successColor : _getPriorityColor(priority)).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Icon with better styling
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isInCart 
                          ? [successColor.withOpacity(0.8), successColor.withOpacity(0.6)]
                          : [color.withOpacity(0.8), color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isInCart ? successColor : color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          isInCart ? Icons.check_circle_rounded : icon, 
                          color: Colors.white, 
                          size: 24
                        ),
                      ),
                      if (isCategoryAdjusted)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (isAIGenerated)
                        Positioned(
                          left: -4,
                          bottom: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with priority badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recommendation['title'],
                                  style: TextStyle(
                                    fontSize: 17,
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
                                if (isInCart) 
                                  Text(
                                    '✓ In shopping list • Tap to remove',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: successColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  Text(
                                    'Tap to add to shopping list',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPriorityBadge(priority),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Enhanced detail chips (without quantity)
                      _buildEnhancedDetailInfo(
                        currentStock: currentStock,
                        daysUntilExpiry: daysUntilExpiry,
                        consumptionRate: consumptionRate,
                        preferenceScore: preferenceScore,
                        category: category,
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

  Widget _buildPriorityBadge(String priority) {
    final Color bgColor = _getPriorityColor(priority);
    final IconData icon = priority == 'high' 
        ? Icons.warning_rounded 
        : Icons.info_rounded;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: bgColor),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: bgColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return errorColor;
      case 'medium':
        return warningColor;
      default:
        return primaryColor;
    }
  }

  Widget _buildEnhancedDetailInfo({
    required int? currentStock,
    required int? daysUntilExpiry,
    required double? consumptionRate,
    required double? preferenceScore,
    required String category,
  }) {
    final List<Widget> details = [];

    if (currentStock != null) {
      details.add(
        _DetailChip(
          icon: Icons.inventory_2_rounded,
          text: 'Stock: $currentStock',
          color: textLight,
        ),
      );
    }

    if (daysUntilExpiry != null) {
      details.add(
        _DetailChip(
          icon: Icons.calendar_today_rounded,
          text: 'Expires: ${daysUntilExpiry}d',
          color: daysUntilExpiry <= 3 ? errorColor : warningColor,
        ),
      );
    }

    if (consumptionRate != null) {
      details.add(
        _DetailChip(
          icon: Icons.timeline_rounded,
          text: '${consumptionRate.toStringAsFixed(1)}/day',
          color: successColor,
        ),
      );
    }

    if (preferenceScore != null && preferenceScore > 0.3) {
      details.add(
        _DetailChip(
          icon: Icons.favorite_rounded,
          text: 'Household Favorite',
          color: Colors.red,
        ),
      );
    }

    if (category != 'general') {
      details.add(
        _DetailChip(
          icon: Icons.category_rounded,
          text: category.replaceAll('_', ' '),
          color: Colors.purple,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: details,
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailChip({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}