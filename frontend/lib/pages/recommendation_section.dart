import 'package:flutter/material.dart';
import '../services/inventory_reccomendation_service.dart';

class RecommendationSection extends StatefulWidget {
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

  const RecommendationSection({
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
  _RecommendationSectionState createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  final InventoryRecommendationService _recommendationService = InventoryRecommendationService();
  
  List<Map<String, dynamic>> _smartRecommendations = [];
  bool _isRecommendationsLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSmartRecommendations();
  }

  Future<void> _loadSmartRecommendations() async {
    if (widget.householdId.isEmpty) return;
    
    setState(() {
      _isRecommendationsLoading = true;
      _hasError = false;
    });

    try {
      final recommendations = await _recommendationService.getSmartRecommendations(widget.householdId);
      
      if (mounted) {
        setState(() {
          _smartRecommendations = recommendations;
          _isRecommendationsLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isRecommendationsLoading = false;
          _hasError = true;
          _smartRecommendations = [];
        });
      }
    }
  }

  Future<void> _refreshRecommendations() async {
    await _loadSmartRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: 16),
        
        _isRecommendationsLoading
            ? _buildRecommendationsLoading()
            : _hasError
                ? _buildErrorState()
                : _smartRecommendations.isEmpty
                    ? _buildNoRecommendations()
                    : _buildRecommendationsList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          'Smart Recommendations',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: widget.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(width: 8),
        PulseIndicator(color: widget.primaryColor, size: 6),
        Spacer(),
        if (_smartRecommendations.isNotEmpty)
        
        SizedBox(width: 10),
        IconButton(
          icon: Icon(Icons.refresh_rounded, size: 20),
          onPressed: _refreshRecommendations,
          tooltip: 'Refresh Recommendations',
          color: widget.textSecondary,
        ),
      ],
    );
  }

  

  Widget _buildRecommendationsLoading() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
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
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Analyzing Your Inventory...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Checking stock levels, expiry dates, and consumption patterns',
            style: TextStyle(
              fontSize: 13,
              color: widget.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
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
          SizedBox(height: 16),
          Text(
            'Unable to Load Recommendations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There was an error loading your smart recommendations. Please try again.',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshRecommendations,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecommendations() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.successColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 40,
              color: widget.successColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Everything Looks Great!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your inventory is well managed. No urgent recommendations at the moment.',
            style: TextStyle(
              fontSize: 14,
              color: widget.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatusChip('Stock Levels', 'Optimal', widget.successColor),
              _buildStatusChip('Expiry Dates', 'No Issues', widget.successColor),
              _buildStatusChip('Consumption', 'Stable', widget.successColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
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

  Widget _buildRecommendationsList() {
    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
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
        children: [
          ..._smartRecommendations.take(5).map((recommendation) => 
            _buildRecommendationItem(recommendation)
          ).toList(),
          
          if (_smartRecommendations.length > 5)
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _showAllRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor.withOpacity(0.1),
                  foregroundColor: widget.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All ${_smartRecommendations.length} Recommendations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    final Color color = Color(recommendation['color'] as int);
    final IconData icon = recommendation['icon'] as IconData;
    final String priority = recommendation['priority'] as String;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleRecommendationAction(recommendation),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority Indicator
              Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 12),
              
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recommendation['title'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: widget.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      recommendation['message'],
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Additional info based on type
                    if (recommendation['type'] == 'predicted_out_of_stock')
                      Row(
                        children: [
                          Icon(Icons.timeline_rounded, size: 12, color: widget.textLight),
                          SizedBox(width: 4),
                          Text(
                            'Consumption: ${recommendation['consumptionRate']}/day',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.textLight,
                            ),
                          ),
                        ],
                      ),
                    
                    if (recommendation['type'] == 'low_stock')
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_rounded, size: 12, color: widget.textLight),
                          SizedBox(width: 4),
                          Text(
                            'Add ${recommendation['recommendedQuantity']} to cart',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.textLight,
                            ),
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

  void _showAllRecommendations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'All Recommendations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: widget.textPrimary,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _smartRecommendations.length,
                itemBuilder: (context, index) => 
                  _buildRecommendationItem(_smartRecommendations[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRecommendationAction(Map<String, dynamic> recommendation) {
    final String action = recommendation['action'];
    final String itemId = recommendation['itemId'];
    final String itemName = recommendation['itemName'];
    
    switch (action) {
      case 'restock':
        _showRestockDialog(itemName, itemId, recommendation['recommendedQuantity']);
        break;
      case 'use_soon':
        _showExpiryWarning(itemName, recommendation['daysUntilExpiry']);
        break;
      case 'plan_restock':
        _showPredictionDetails(itemName, recommendation['daysRemaining']);
        break;
      case 'monitor':
        widget.onNavigateToItem(itemId);
        break;
    }
  }

  void _showRestockDialog(String itemName, String itemId, int quantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock $itemName'),
        content: Text('Add $quantity units to your shopping list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onAddToShoppingList(itemName, quantity, itemId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
            ),
            child: Text('Add to List'),
          ),
        ],
      ),
    );
  }

  void _showExpiryWarning(String itemName, int daysUntilExpiry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$itemName Expiring'),
        content: Text(daysUntilExpiry == 0 
            ? 'This item expires today! Use it immediately.'
            : 'This item expires in $daysUntilExpiry days. Consider using it soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPredictionDetails(String itemName, double daysRemaining) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$itemName Stock Prediction'),
        content: Text('Based on consumption patterns, this item will run out in ${daysRemaining.toStringAsFixed(1)} days. Consider restocking soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Pulse Indicator Widget (copied from your original code)
class PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;
  
  const PulseIndicator({Key? key, required this.color, this.size = 8}) : super(key: key);
  
  @override
  _PulseIndicatorState createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value * 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
} 