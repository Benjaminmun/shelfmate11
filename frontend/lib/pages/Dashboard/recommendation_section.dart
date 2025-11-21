import 'package:flutter/material.dart';
import 'package:frontend/services/inventory_recomendation_service.dart';
import '../../services/shopping_list_service.dart';
import 'all_recommendations_page.dart';

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
  final int maxDisplayCount;

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
    this.maxDisplayCount = 2,
  }) : super(key: key);

  @override
  _RecommendationSectionState createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  final InventoryRecommendationService _recommendationService =
      InventoryRecommendationService();
  final ShoppingListService _shoppingListService = ShoppingListService();

  List<Map<String, dynamic>> _smartRecommendations = [];
  bool _isRecommendationsLoading = false;
  bool _hasError = false;
  Set<String> _itemsInCart = Set<String>();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _loadSmartRecommendations();
    _loadCartState();
  }

  Future<void> _loadSmartRecommendations() async {
    if (widget.householdId.isEmpty || _smartRecommendations.isNotEmpty) return;

    setState(() {
      _isRecommendationsLoading = true;
      _hasError = false;
    });

    try {
      final recommendations = await _recommendationService
          .getSmartRecommendations(widget.householdId);

      if (mounted) {
        setState(() {
          _smartRecommendations = recommendations;
          _isRecommendationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecommendationsLoading = false;
          _hasError = true;
          _smartRecommendations = [];
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

  Future<void> _refreshRecommendations() async {
    setState(() {
      _smartRecommendations = [];
      _itemsInCart.clear();
    });
    await Future.wait([_loadSmartRecommendations(), _loadCartState()]);
  }

  void _navigateToAllRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllRecommendationsPage(
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
          onAddToShoppingList: widget.onAddToShoppingList,
          onNavigateToItem: widget.onNavigateToItem,
        ),
      ),
    ).then((_) => _refreshData());
  }

  void _refreshData() {
    _loadCartState();
    _loadSmartRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildHeader(), const SizedBox(height: 16), _buildContent()],
    );
  }

  Widget _buildHeader() {
    final urgentCount = _smartRecommendations
        .where((rec) => rec['priority'] == 'high')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _CartStatusIndicator(
              displayedCount: _smartRecommendations.length,
              surfaceColor: widget.surfaceColor,
              primaryColor: widget.primaryColor,
              textSecondary: widget.textSecondary,
            ),
          ],
        ),
        if (_smartRecommendations.isNotEmpty && !_isRecommendationsLoading)
          Container(
            margin: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                if (urgentCount > 0) ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$urgentCount urgent items',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: urgentCount > 0 ? 1.0 : 0.0,
                          backgroundColor: widget.backgroundColor,
                          color: widget.warningColor,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isRecommendationsLoading) {
      return _buildRecommendationsLoading();
    } else if (_hasError) {
      return _buildErrorState();
    } else if (_smartRecommendations.isEmpty) {
      return _buildNoRecommendations();
    } else {
      return _buildDashboardRecommendations();
    }
  }

  Widget _buildRecommendationsLoading() {
    return _StateWidget(
      title: 'Analyzing Your Inventory...',
      subtitle:
          'Checking stock levels, expiry dates, and consumption patterns to provide personalized recommendations',
      icon: Icons.auto_awesome_rounded,
      iconColor: widget.primaryColor,
    );
  }

  Widget _buildErrorState() {
    return _StateWidget(
      title: 'Unable to Load Recommendations',
      subtitle:
          'There was an error analyzing your inventory data. Please check your connection and try again.',
      icon: Icons.error_outline_rounded,
      iconColor: widget.errorColor,
      actionText: 'Try Again',
      onAction: _refreshRecommendations,
    );
  }

  Widget _buildNoRecommendations() {
    return Column(
      children: [
        _StateWidget(
          title: 'Everything Looks Great! 🎉',
          subtitle:
              'Your inventory is well managed with optimal stock levels and no urgent issues detected.',
          icon: Icons.check_circle_rounded,
          iconColor: widget.successColor,
        ),
        const SizedBox(height: 20),
        _buildViewAllButton(),
      ],
    );
  }

  Widget _buildDashboardRecommendations() {
    final displayedRecommendations = _smartRecommendations
        .take(widget.maxDisplayCount)
        .toList();

    return Column(
      children: [
        ...displayedRecommendations
            .map(
              (recommendation) => _DashboardRecommendationItem(
                recommendation: recommendation,
                textPrimary: widget.textPrimary,
                textSecondary: widget.textSecondary,
                textLight: widget.textLight,
                primaryColor: widget.primaryColor,
                successColor: widget.successColor,
                errorColor: widget.errorColor,
              ),
            )
            .toList(),
        _buildViewAllButton(),
      ],
    );
  }

  Widget _buildViewAllButton() {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _smartRecommendations.isEmpty
                  ? 'View Recommendations'
                  : 'View All ${_smartRecommendations.length} Recommendations',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _navigateToAllRecommendations,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor.withOpacity(0.1),
              foregroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// Extracted Widgets

class _CartStatusIndicator extends StatelessWidget {
  final int displayedCount;
  final Color surfaceColor;
  final Color primaryColor;
  final Color textSecondary;

  const _CartStatusIndicator({
    Key? key,
    required this.displayedCount,
    required this.surfaceColor,
    required this.primaryColor,
    required this.textSecondary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 10, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            '$displayedCount recommendations',
            style: TextStyle(
              fontSize: 10,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String? actionText;
  final VoidCallback? onAction;

  const _StateWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
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

class _DashboardRecommendationItem extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final Color primaryColor;
  final Color successColor;
  final Color errorColor;

  const _DashboardRecommendationItem({
    Key? key,
    required this.recommendation,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.primaryColor,
    required this.successColor,
    required this.errorColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = Color(recommendation['color'] as int);
    final IconData icon = recommendation['icon'] as IconData;
    final String priority = recommendation['priority'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (priority == 'high')
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.warning_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
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
                            color: textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation['message'],
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View all recommendations to take action',
                    style: TextStyle(
                      fontSize: 10,
                      color: textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
