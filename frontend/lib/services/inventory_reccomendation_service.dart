import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:math';

// Import services
import 'shopping_list_service.dart';

class InventoryRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  
  // Add ShoppingListService instance
  final ShoppingListService _shoppingListService = ShoppingListService();
  
  // Enhanced cache with TTL
  final Map<String, _CachedConsumptionRate> _consumptionRateCache = {};
  final Map<String, HouseholdProfile> _householdProfileCache = {};
  final Map<String, List<Map<String, dynamic>>> _recommendationCache = {};
  static const Duration _cacheDuration = Duration(hours: 2);
  static const int _maxCacheSize = 1000;

  // Track recommendations that have been added to shopping list
  final Map<String, Set<String>> _addedRecommendations = {};

  // Category profiles focused on consumption patterns
  static const Map<String, CategoryConsumptionProfile> _categoryProfiles = {
    'perishables': CategoryConsumptionProfile(
      category: 'Food',
      typicalDailyUsage: 0.3,
      seasonality: 1.2,
      urgencyMultiplier: 1.5,
      minStockLevelMultiplier: 1.8,
      expirySensitivity: 2.0,
      consumptionPattern: ConsumptionPattern.daily,
      priceSensitivity: 1.8,
      bulkPurchaseScore: 0.6,
      emergencyPriority: 0.9,
      lowStockThreshold: 3,
      expiryWarningThreshold: 7,
    ),
    'cleaning_supplies': CategoryConsumptionProfile(
      category: 'Cleaning Supplies',
      typicalDailyUsage: 0.08,
      seasonality: 1.0,
      urgencyMultiplier: 1.0,
      minStockLevelMultiplier: 0.5,
      expirySensitivity: 0.2,
      consumptionPattern: ConsumptionPattern.steady,
      priceSensitivity: 1.1,
      bulkPurchaseScore: 0.9,
      emergencyPriority: 0.4,
      lowStockThreshold: 7,
      expiryWarningThreshold: 30,
    ),
    'personal_care': CategoryConsumptionProfile(
      category: 'Personal Care',
      typicalDailyUsage: 0.05,
      seasonality: 1.1,
      urgencyMultiplier: 1.2,
      minStockLevelMultiplier: 0.5,
      expirySensitivity: 0.8,
      consumptionPattern: ConsumptionPattern.regular,
      priceSensitivity: 1.5,
      bulkPurchaseScore: 0.7,
      emergencyPriority: 0.6,
      lowStockThreshold: 5,
      expiryWarningThreshold: 14,
    ),
    'medicines': CategoryConsumptionProfile(
      category: 'Medication',
      typicalDailyUsage: 0.02,
      seasonality: 1.3,
      urgencyMultiplier: 2.0,
      minStockLevelMultiplier: 0.5,
      expirySensitivity: 1.8,
      consumptionPattern: ConsumptionPattern.irregular,
      priceSensitivity: 0.8,
      bulkPurchaseScore: 0.4,
      emergencyPriority: 1.0,
      lowStockThreshold: 14,
      expiryWarningThreshold: 30,
    ),
    'beverages': CategoryConsumptionProfile(
      category: 'Beverages',
      typicalDailyUsage: 0.4,
      seasonality: 1.4,
      urgencyMultiplier: 1.1,
      minStockLevelMultiplier: 1.5,
      expirySensitivity: 0.5,
      consumptionPattern: ConsumptionPattern.daily,
      priceSensitivity: 1.6,
      bulkPurchaseScore: 0.9,
      emergencyPriority: 0.5,
      lowStockThreshold: 3,
      expiryWarningThreshold: 14,
    ),
    'household_supplies': CategoryConsumptionProfile(
      category: 'Household Supplies',
      typicalDailyUsage: 0.1,
      seasonality: 1.0,
      urgencyMultiplier: 1.0,
      minStockLevelMultiplier: 1.0,
      expirySensitivity: 0.3,
      consumptionPattern: ConsumptionPattern.steady,
      priceSensitivity: 1.2,
      bulkPurchaseScore: 0.8,
      emergencyPriority: 0.3,
      lowStockThreshold: 7,
      expiryWarningThreshold: 90,
    ),
  };

  // Priority system - high, medium, low
  static const Map<String, int> _priorityWeights = {
    'high': 1,
    'medium': 2,
    'low': 3,
  };

  // 🎯 MAIN RECOMMENDATION METHOD
  Future<List<Map<String, dynamic>>> getSmartRecommendations(String householdId) async {
    final cacheKey = '${householdId}_recommendations';
    final cached = _recommendationCache[cacheKey];
    if (cached != null) {
      return cached.where((rec) => !_isRecommendationAdded(householdId, rec)).toList();
    }

    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        throw Exception('No internet connection. Please check your connection and try again.');
      }

      final stopwatch = Stopwatch()..start();
      
      // Fetch data for specific household
      final responses = await Future.wait<dynamic>([
        _fetchInventoryBatch(householdId),
        _fetchAllConsumptionRates(householdId),
        _getHouseholdProfile(householdId),
        _fetchCategoryConsumptionPatterns(householdId),
      ]);

      final inventoryItems = responses[0] as List<InventoryItem>;
      final consumptionRates = responses[1] as Map<String, double>;
      final householdProfile = responses[2] as HouseholdProfile;
      final categoryPatterns = responses[3] as Map<String, CategoryConsumptionPattern>;

      if (inventoryItems.isEmpty) {
        return _getPersonalizedDefaultRecommendations(householdProfile);
      }

      // Generate recommendations based on enhanced logic
      final recommendations = await _generateUsageBasedRecommendations(
        inventoryItems,
        consumptionRates,
        householdProfile,
        categoryPatterns,
      );

      // Cache the results
      _cacheRecommendations(cacheKey, recommendations);

      _logPerformance('Enhanced recommendations generated in ${stopwatch.elapsedMilliseconds}ms');
      
      return recommendations.where((rec) => !_isRecommendationAdded(householdId, rec)).toList();
    } catch (e) {
      _logError('Error generating enhanced recommendations', e);
      final householdProfile = await _getHouseholdProfile(householdId);
      final defaultRecs = _getPersonalizedDefaultRecommendations(householdProfile);
      return defaultRecs.where((rec) => !_isRecommendationAdded(householdId, rec)).toList();
    }
  }

  // 📈 GET USAGE ANALYTICS FOR SPECIFIC ITEM
  Future<Map<String, dynamic>> getItemUsageAnalytics(String householdId, String itemId) async {
    try {
      final consumptionRate = await _calculateConsumptionRate(itemId);
      final itemDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) {
        throw Exception('Item not found');
      }

      final item = InventoryItem.fromMap(itemDoc.data()!, itemId);
      final categoryProfile = _categoryProfiles[item.category.toLowerCase()] ?? _categoryProfiles['household_supplies']!;
      
      // Get recent usage history
      final usageHistory = await _getUsageHistory(itemId, 30); // Last 30 days

      // Calculate metrics
      final double daysOfSupply = consumptionRate > 0 ? (item.quantity / consumptionRate).toDouble() : 0.0;
      final minStockLevel = item.minStockLevel ?? _calculateDefaultMinStockLevel(categoryProfile, consumptionRate);
      final isBelowMinStock = item.quantity <= minStockLevel;
      
      // Expiry analysis
      double expiryRisk = 0.0;
      int? daysUntilExpiry;
      if (item.expiryDate != null) {
        daysUntilExpiry = item.expiryDate!.difference(DateTime.now()).inDays;
        expiryRisk = _calculateExpiryRisk(item, categoryProfile);
      }

      return {
        'itemId': itemId,
        'itemName': item.name,
        'currentQuantity': item.quantity,
        'consumptionRate': consumptionRate,
        'daysOfSupply': daysOfSupply,
        'minStockLevel': minStockLevel,
        'isBelowMinStock': isBelowMinStock,
        'expiryRisk': expiryRisk,
        'daysUntilExpiry': daysUntilExpiry,
        'usageHistory': usageHistory,
        'recommendedRestockQuantity': _calculateRecommendedQuantity(UsageAnalysis(
          item: item,
          consumptionRate: consumptionRate,
          daysOfSupply: daysOfSupply,
          stockoutProbability: _calculateStockoutProbability(daysOfSupply, categoryProfile.lowStockThreshold),
          expiryRisk: expiryRisk,
          categoryProfile: categoryProfile,
          lastRestockDate: await _getLastRestockDate(itemId),
          usageConsistency: 0.7, // Default
          minStockLevel: minStockLevel,
          isBelowMinStock: isBelowMinStock,
          minStockCompliance: isBelowMinStock ? 0.0 : 1.0,
        )),
        'lastRestockDate': await _getLastRestockDate(itemId),
        'analysisTimestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logError('Error getting item usage analytics', e);
      return {'error': e.toString()};
    }
  }

  // 🎯 TRACK HOUSEHOLD INTERACTION
  Future<void> trackHouseholdInteraction({
    required String householdId,
    required String itemId,
    required String action,
    String? itemName,
    String? category,
    int? quantity,
    double? price,
  }) async {
    try {
      await _firestore.collection('household_interactions').add({
        'householdId': householdId,
        'itemId': itemId,
        'itemName': itemName,
        'category': category,
        'action': action,
        'quantity': quantity,
        'price': price,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });
    } catch (e) {
      print('❌ Error tracking household interaction: $e');
    }
  }

  // 🔍 DIAGNOSE SHOPPING LIST ISSUE
  Future<Map<String, dynamic>> diagnoseShoppingListIssue(String householdId) async {
    try {
      // Check shopping list items
      final shoppingListSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .get();

      // Check inventory items
      final inventorySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      return {
        'shoppingListItemCount': shoppingListSnapshot.docs.length,
        'inventoryItemCount': inventorySnapshot.docs.length,
        'hasDuplicateItems': await _checkDuplicateItems(householdId),
        'hasExpiredRecommendations': await _checkExpiredRecommendations(householdId),
        'diagnosisTimestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // 🐛 DEBUG ADD TO SHOPPING LIST
  Future<Map<String, dynamic>> debugAddToShoppingList({
    required String householdId,
    required String itemName,
    required String itemId,
  }) async {
    try {
      final result = await _shoppingListService.addToShoppingList(
        householdId,
        itemName,
        1, // quantity
        itemId,
        category: 'test',
        estimatedPrice: 10.0,
        priority: 'medium',
      );

      return {
        'success': result['success'] ?? false,
        'message': 'Debug add completed',
        'result': result,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🛒 ADD RECOMMENDATION TO SHOPPING LIST
  Future<Map<String, dynamic>> addRecommendationToShoppingList({
    required String householdId,
    required Map<String, dynamic> recommendation,
    int? customQuantity,
  }) async {
    try {
      final fixedRecommendation = _validateAndFixRecommendation(recommendation);
      
      final itemId = fixedRecommendation['itemId'] as String;
      final itemName = fixedRecommendation['itemName'] as String;
      final category = fixedRecommendation['category'] as String;
      final quantity = customQuantity ?? 1;
      final exactPrice = await _getExactPrice(householdId, itemId);
      final priority = fixedRecommendation['priority'] as String;

      final result = await _shoppingListService.addToShoppingList(
        householdId,
        itemName,
        quantity,
        itemId,
        category: category,
        estimatedPrice: exactPrice,
        priority: priority,
        recommendationData: {
          'type': fixedRecommendation['type'],
          'analysis': fixedRecommendation['analysisSummary'],
          'originalRecommendation': fixedRecommendation,
          'addedAt': DateTime.now().toIso8601String(),
          'formattedEstimatedPrice': _formatCurrency(exactPrice),
        },
      );

      if (result['success'] == true) {
        _markRecommendationAsAdded(householdId, fixedRecommendation);

        await trackHouseholdInteraction(
          householdId: householdId,
          itemId: itemId,
          action: 'added_to_shopping_list',
          itemName: itemName,
          category: category,
          quantity: quantity,
          price: exactPrice,
        );

        return {
          'success': true,
          'message': 'Added $itemName to shopping list',
          'shoppingListItemId': result['documentId'],
          'quantity': quantity,
          'itemName': itemName,
          'estimatedPrice': exactPrice,
          'formattedEstimatedPrice': _formatCurrency(exactPrice),
          'priceSource': 'firestore_exact',
          'recommendationRemoved': true,
        };
      } else {
        throw Exception('Shopping list service returned error: ${result['error']}');
      }
    } catch (e) {
      _logError('Error adding recommendation to shopping list', e);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 🎯 TRACK INVENTORY UPDATE WITH USAGE DETECTION
  Future<void> trackInventoryUpdate({
    required String householdId,
    required String itemId,
    required String itemName,
    required int oldQuantity,
    required int newQuantity,
    required String category,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Create audit log for usage tracking
      await _createUsageAuditLog(
        householdId: householdId,
        itemId: itemId,
        itemName: itemName,
        oldQuantity: oldQuantity,
        newQuantity: newQuantity,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Unknown User',
      );

      // Track household interaction for behavior analysis
      await trackHouseholdInteraction(
        householdId: householdId,
        itemId: itemId,
        action: 'quantity_updated',
        itemName: itemName,
        category: category,
        quantity: newQuantity,
      );

      // Clear cache to refresh recommendations
      _consumptionRateCache.remove(itemId);
      _recommendationCache.remove('${householdId}_recommendations');

      print('✅ Tracked inventory update: $itemName ($oldQuantity → $newQuantity)');
    } catch (e) {
      print('❌ Error tracking inventory update: $e');
    }
  }

  // 🔄 PRIVATE METHODS

  // 🧠 GENERATE USAGE BASED RECOMMENDATIONS
  Future<List<Map<String, dynamic>>> _generateUsageBasedRecommendations(
    List<InventoryItem> inventoryItems,
    Map<String, double> consumptionRates,
    HouseholdProfile householdProfile,
    Map<String, CategoryConsumptionPattern> categoryPatterns,
  ) async {
    final recommendations = <Map<String, dynamic>>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (final item in inventoryItems) {
      try {
        final baseConsumptionRate = consumptionRates[item.id!] ?? 0.1;
        item.category.toLowerCase();

        // Analyze usage patterns
        final analysis = await _analyzeUsagePatterns(
          item,
          baseConsumptionRate,
          householdProfile,
          categoryPatterns,
        );

        // Generate recommendations based on analysis
        recommendations.addAll(_detectLowStockAlerts(item, analysis, timestamp));
        recommendations.addAll(_detectExpiryRiskAlerts(item, analysis, timestamp));
      } catch (e) {
        _logError('Error generating recommendations for item ${item.id}', e);
      }
    }

    // Sort by priority and timestamp
    recommendations.sort((a, b) {
      final priorityA = _priorityWeights[a['priority']] ?? 3;
      final priorityB = _priorityWeights[b['priority']] ?? 3;
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      return (b['timestamp'] as int).compareTo(a['timestamp'] as int);
    });

    return recommendations;
  }

  // 🔍 ANALYZE USAGE PATTERNS FROM AUDIT LOGS
  Future<UsageAnalysis> _analyzeUsagePatterns(
    InventoryItem item,
    double baseConsumptionRate,
    HouseholdProfile householdProfile,
    Map<String, CategoryConsumptionPattern> categoryPatterns,
  ) async {
    final category = item.category.toLowerCase();
    final categoryProfile = _categoryProfiles[category] ?? _categoryProfiles['household_supplies']!;
    final householdPattern = categoryPatterns[category];

    // Calculate detailed consumption metrics
    final consumptionRate = _calculateAdjustedConsumptionRate(item, baseConsumptionRate, householdPattern, categoryProfile);
    final daysOfSupply = consumptionRate > 0 ? item.quantity / consumptionRate : 999.0;
    final stockoutProbability = _calculateStockoutProbability(daysOfSupply, categoryProfile.lowStockThreshold);
    
    // Calculate expiry risk
    final expiryRisk = _calculateExpiryRisk(item, categoryProfile);

    // Calculate min stock level compliance
    final minStockLevel = item.minStockLevel ?? _calculateDefaultMinStockLevel(categoryProfile, consumptionRate);
    final isBelowMinStock = item.quantity <= minStockLevel;
    final minStockCompliance = isBelowMinStock ? 0.0 : 1.0;

    return UsageAnalysis(
      item: item,
      consumptionRate: consumptionRate,
      daysOfSupply: daysOfSupply,
      stockoutProbability: stockoutProbability,
      expiryRisk: expiryRisk,
      categoryProfile: categoryProfile,
      lastRestockDate: await _getLastRestockDate(item.id!),
      usageConsistency: _calculateUsageConsistency(item.id!, householdPattern),
      minStockLevel: minStockLevel,
      isBelowMinStock: isBelowMinStock,
      minStockCompliance: minStockCompliance,
    );
  }

  // 🚨 ENHANCED LOW STOCK DETECTION
  List<Map<String, dynamic>> _detectLowStockAlerts(InventoryItem item, UsageAnalysis analysis, int timestamp) {
    final recommendations = <Map<String, dynamic>>[];
    final categoryProfile = analysis.categoryProfile;

    // 🎯 CHECK 1: Based on minStockLevel (user-defined or calculated)
    if (analysis.isBelowMinStock) {
      final neededQuantity = _calculateRecommendedQuantity(analysis);
      final urgencyLevel = _determineMinStockUrgency(analysis);

      recommendations.add(_buildMinStockRecommendation(
        item: item,
        analysis: analysis,
        neededQuantity: neededQuantity,
        urgencyLevel: urgencyLevel,
        timestamp: timestamp,
      ));
    }

    // 🎯 CHECK 2: Based on days of supply
    else if (analysis.daysOfSupply <= categoryProfile.lowStockThreshold) {
      final neededQuantity = _calculateRecommendedQuantity(analysis);
      final urgencyLevel = _determineLowStockUrgency(analysis);

      recommendations.add(_buildLowStockRecommendation(
        item: item,
        analysis: analysis,
        neededQuantity: neededQuantity,
        urgencyLevel: urgencyLevel,
        timestamp: timestamp,
      ));
    }

    // 🚨 CHECK 3: Critical stock alert for very low quantities
    if (analysis.daysOfSupply <= 1 || item.quantity == 0) {
      recommendations.add(_buildCriticalStockRecommendation(
        item: item,
        analysis: analysis,
        timestamp: timestamp,
      ));
    }

    return recommendations;
  }

  // ⏰ ENHANCED EXPIRY DETECTION
  List<Map<String, dynamic>> _detectExpiryRiskAlerts(InventoryItem item, UsageAnalysis analysis, int timestamp) {
    final recommendations = <Map<String, dynamic>>[];
    
    if (item.expiryDate == null) return recommendations;

    final daysUntilExpiry = item.expiryDate!.difference(DateTime.now()).inDays;
    final categoryProfile = analysis.categoryProfile;

    // Check if item is approaching expiry
    if (daysUntilExpiry <= categoryProfile.expiryWarningThreshold) {
      final urgencyLevel = _determineExpiryUrgency(daysUntilExpiry);
      
      recommendations.add(_buildExpiryRecommendation(
        item: item,
        analysis: analysis,
        daysUntilExpiry: daysUntilExpiry,
        urgencyLevel: urgencyLevel,
        timestamp: timestamp,
      ));
    }

    // Critical expiry alert for items expiring soon
    if (daysUntilExpiry <= 3) {
      recommendations.add(_buildCriticalExpiryRecommendation(
        item: item,
        analysis: analysis,
        daysUntilExpiry: daysUntilExpiry,
        timestamp: timestamp,
      ));
    }

    // Usage recommendation for items nearing expiry
    if (daysUntilExpiry <= 7 && analysis.consumptionRate < categoryProfile.typicalDailyUsage) {
      recommendations.add(_buildUseSoonRecommendation(
        item: item,
        analysis: analysis,
        daysUntilExpiry: daysUntilExpiry,
        timestamp: timestamp,
      ));
    }

    return recommendations;
  }

  // 🏗️ RECOMMENDATION BUILDERS
  Map<String, dynamic> _buildAIPoweredRecommendation({
    required String type,
    required String priority,
    required String title,
    required String message,
    required InventoryItem item,
    required UsageAnalysis analysis,
    required Map<String, dynamic> extraData,
    required int color,
    required int timestamp,
    required IconData icon,
  }) {
    return {
      'type': type,
      'priority': priority,
      'title': title,
      'message': message,
      'itemId': item.id,
      'itemName': item.name,
      'category': item.category,
      'action': _getSmartActionForType(type),
      'icon': icon,
      'color': color,
      'timestamp': timestamp,
      'aiGenerated': true,
      'aiConfidence': _calculateRecommendationConfidence(analysis),
      'analysisSummary': analysis.toSummaryMap(),
      ...extraData,
    };
  }

  Map<String, dynamic> _buildCriticalStockRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int timestamp,
  }) {
    final message = '${item.name} is critically low! Only ${item.quantity} left. '
                   'Restock immediately to avoid running out.';

    return _buildAIPoweredRecommendation(
      type: 'critical_stock_alert',
      priority: 'high',
      title: '🚨 Critical Stock: ${item.name}',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'currentQuantity': item.quantity,
        'daysOfSupply': analysis.daysOfSupply,
        'stockoutProbability': analysis.stockoutProbability,
      },
      color: 0xFFE74C3C, // Red
      timestamp: timestamp,
      icon: Icons.warning_rounded,
    );
  }

  Map<String, dynamic> _buildExpiryRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int daysUntilExpiry,
    required String urgencyLevel,
    required int timestamp,
  }) {
    final message = '${item.name} expires in $daysUntilExpiry days. '
                   'Consider using it soon to prevent waste.';

    return _buildAIPoweredRecommendation(
      type: 'expiry_alert',
      priority: urgencyLevel,
      title: '${item.name} Expiring Soon',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'daysUntilExpiry': daysUntilExpiry,
        'expiryRisk': analysis.expiryRisk,
      },
      color: _getPriorityColor(urgencyLevel),
      timestamp: timestamp,
      icon: Icons.calendar_today_rounded,
    );
  }

  Map<String, dynamic> _buildCriticalExpiryRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int daysUntilExpiry,
    required int timestamp,
  }) {
    final message = '${item.name} expires in $daysUntilExpiry days! '
                   'Use it immediately to avoid waste.';

    return _buildAIPoweredRecommendation(
      type: 'critical_expiry_alert',
      priority: 'high',
      title: '🚨 ${item.name} Expiring!',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'daysUntilExpiry': daysUntilExpiry,
        'expiryRisk': analysis.expiryRisk,
      },
      color: 0xFFE74C3C, // Red
      timestamp: timestamp,
      icon: Icons.warning_amber_rounded,
    );
  }

  Map<String, dynamic> _buildMinStockRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int neededQuantity,
    required String urgencyLevel,
    required int timestamp,
  }) {
    final message = '${item.name} is below minimum stock level (${analysis.minStockLevel}). '
                   'Restock $neededQuantity ${neededQuantity == 1 ? 'unit' : 'units'} to maintain optimal inventory.';

    return _buildAIPoweredRecommendation(
      type: 'min_stock_alert',
      priority: urgencyLevel,
      title: '${item.name} Below Minimum Stock',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'minStockLevel': analysis.minStockLevel,
        'currentQuantity': item.quantity,
        'recommendedQuantity': neededQuantity,
        'stockoutProbability': analysis.stockoutProbability,
      },
      color: _getPriorityColor(urgencyLevel),
      timestamp: timestamp,
      icon: Icons.inventory_2_rounded,
    );
  }

  Map<String, dynamic> _buildLowStockRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int neededQuantity,
    required String urgencyLevel,
    required int timestamp,
  }) {
    final daysLeft = analysis.daysOfSupply.floor();
    final message = 'Based on your usage patterns, ${item.name} will run out in $daysLeft days. '
                   'Consider restocking $neededQuantity ${neededQuantity == 1 ? 'unit' : 'units'} to maintain supply.';

    return _buildAIPoweredRecommendation(
      type: 'low_stock_alert',
      priority: urgencyLevel,
      title: '${item.name} Running Low',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'daysOfSupply': analysis.daysOfSupply,
        'recommendedQuantity': neededQuantity,
        'stockoutProbability': analysis.stockoutProbability,
      },
      color: _getPriorityColor(urgencyLevel),
      timestamp: timestamp,
      icon: Icons.inventory_2_rounded,
    );
  }

  Map<String, dynamic> _buildUseSoonRecommendation({
    required InventoryItem item,
    required UsageAnalysis analysis,
    required int daysUntilExpiry,
    required int timestamp,
  }) {
    final message = '${item.name} expires in $daysUntilExpiry days and your usage rate is lower than typical. '
                   'Consider using this item more frequently to prevent waste.';

    return _buildAIPoweredRecommendation(
      type: 'use_soon_alert',
      priority: 'medium',
      title: 'Use ${item.name} Soon',
      message: message,
      item: item,
      analysis: analysis,
      extraData: {
        'daysUntilExpiry': daysUntilExpiry,
        'currentUsageRate': analysis.consumptionRate,
        'typicalUsageRate': analysis.categoryProfile.typicalDailyUsage,
      },
      color: 0xFFF39C12, // Orange
      timestamp: timestamp,
      icon: Icons.schedule_rounded,
    );
  }

  // 🧮 CALCULATION METHODS
  double _calculateAdjustedConsumptionRate(
    InventoryItem item,
    double baseConsumptionRate,
    CategoryConsumptionPattern? householdPattern,
    CategoryConsumptionProfile categoryProfile,
  ) {
    double adjustedRate = baseConsumptionRate;

    // Apply household pattern adjustment if available
    if (householdPattern != null) {
      adjustedRate *= householdPattern.adjustmentFactor;
    }

    // Apply category-specific adjustments
    adjustedRate *= categoryProfile.seasonality;

    return max(adjustedRate, 0.01); // Minimum consumption rate
  }

  int _calculateDefaultMinStockLevel(CategoryConsumptionProfile profile, double consumptionRate) {
    // Default to 7 days of supply for min stock level
    final defaultMinStock = (consumptionRate * 7).ceil();
    return max(defaultMinStock, 1); // At least 1
  }

  int _calculateRecommendedQuantity(UsageAnalysis analysis) {
    final targetDaysOfSupply = analysis.categoryProfile.lowStockThreshold * 2;
    
    // Calculate needed quantity based on usage
    double neededByUsage = (targetDaysOfSupply * analysis.consumptionRate - analysis.item.quantity).ceilToDouble();
    
    // Calculate needed quantity based on min stock level
    double neededByMinStock = 0.0;
    if (analysis.isBelowMinStock) {
      neededByMinStock = (analysis.minStockLevel - analysis.item.quantity).toDouble();
    }
    
    // Use the larger of the two calculations
    final needed = max(neededByUsage, neededByMinStock).ceil();
    
    return needed.clamp(1, 10);
  }

  double _calculateExpiryRisk(InventoryItem item, CategoryConsumptionProfile profile) {
    if (item.expiryDate == null) return 0.0;

    final daysLeft = item.expiryDate!.difference(DateTime.now()).inDays;
    double riskLevel = 0.0;

    if (daysLeft <= 0) riskLevel = 1.0;
    else if (daysLeft <= 3) riskLevel = 0.9;
    else if (daysLeft <= 7) riskLevel = 0.7;
    else if (daysLeft <= 14) riskLevel = 0.5;
    else if (daysLeft <= 30) riskLevel = 0.3;

    riskLevel *= profile.expirySensitivity;

    return riskLevel.clamp(0.0, 1.0);
  }

  double _calculateStockoutProbability(double daysOfSupply, int lowStockThreshold) {
    if (daysOfSupply <= 1) return 0.95;
    if (daysOfSupply <= lowStockThreshold * 0.5) return 0.8;
    if (daysOfSupply <= lowStockThreshold) return 0.6;
    if (daysOfSupply <= lowStockThreshold * 1.5) return 0.3;
    return 0.1;
  }

  // 🚨 URGENCY CALCULATION METHODS
  String _determineMinStockUrgency(UsageAnalysis analysis) {
    final deficitRatio = (analysis.minStockLevel - analysis.item.quantity) / analysis.minStockLevel;
    
    if (deficitRatio >= 0.7) return 'high';
    if (deficitRatio >= 0.4) return 'medium';
    return 'low';
  }

  String _determineLowStockUrgency(UsageAnalysis analysis) {
    if (analysis.daysOfSupply <= 1) return 'high';
    if (analysis.daysOfSupply <= analysis.categoryProfile.lowStockThreshold * 0.5) return 'high';
    if (analysis.daysOfSupply <= analysis.categoryProfile.lowStockThreshold) return 'medium';
    return 'low';
  }

  String _determineExpiryUrgency(int daysUntilExpiry) {
    if (daysUntilExpiry <= 3) return 'high';
    if (daysUntilExpiry <= 7) return 'high';
    if (daysUntilExpiry <= 14) return 'medium';
    return 'low';
  }

  // 📊 DATA FETCHING METHODS
  Future<List<InventoryItem>> _fetchInventoryBatch(String householdId) async {
    try {
      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      return querySnapshot.docs
          .map((doc) {
            try {
              return InventoryItem.fromMap(doc.data(), doc.id);
            } catch (e) {
              _logError('Error parsing inventory item ${doc.id}', e);
              return null;
            }
          })
          .where((item) => item != null && (item.id?.isNotEmpty ?? false))
          .cast<InventoryItem>()
          .toList();
    } catch (e) {
      _logError('Error fetching inventory for household $householdId', e);
      return [];
    }
  }

  Future<Map<String, double>> _fetchAllConsumptionRates(String householdId) async {
    try {
      final inventorySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      final consumptionRateFutures = inventorySnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .map((itemId) async {
            final rate = await _calculateConsumptionRate(itemId);
            return MapEntry(itemId, rate);
          })
          .toList();

      final results = await Future.wait(consumptionRateFutures);
      return Map<String, double>.fromEntries(results);
    } catch (e) {
      _logError('Error fetching consumption rates for household $householdId', e);
      return {};
    }
  }

  Future<double> _calculateConsumptionRate(String itemId) async {
    final now = DateTime.now();
    final cached = _consumptionRateCache[itemId];
    if (cached != null && now.difference(cached.timestamp) < _cacheDuration) {
      return cached.rate;
    }

    try {
      final auditSnapshot = await _firestore
          .collection('inventory_audit_logs')
          .where('itemId', isEqualTo: itemId)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      if (auditSnapshot.docs.length < 2) {
        _cacheConsumptionRate(itemId, 0.0);
        return 0.0;
      }

      final analysis = _analyzeConsumptionPatterns(auditSnapshot.docs);
      _cacheConsumptionRate(itemId, analysis.weightedRate);
      
      return analysis.weightedRate;
    } catch (e) {
      _logError('Error calculating consumption rate for item $itemId', e);
      _cacheConsumptionRate(itemId, 0.5);
      return 0.5;
    }
  }

  ConsumptionAnalysisResult _analyzeConsumptionPatterns(List<QueryDocumentSnapshot> auditLogs) {
    double totalUsed = 0;
    DateTime? earliest;
    DateTime? latest;

    for (var log in auditLogs) {
      try {
        final data = log.data() as Map<String, dynamic>;
        final oldVal = data['oldValue'] ?? 0;
        final newVal = data['newValue'] ?? 0;
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        // 🎯 DETECT USAGE WHEN QUANTITY DECREASES (2→1, 5→3, etc.)
        if (oldVal is int && newVal is int && oldVal > newVal) {
          final usage = (oldVal - newVal).toDouble();
          totalUsed += usage;

          earliest = earliest == null || timestamp.isBefore(earliest) ? timestamp : earliest;
          latest = latest == null || timestamp.isAfter(latest) ? timestamp : latest;
        }
      } catch (e) {
        continue;
      }
    }

    if (earliest == null || latest == null || totalUsed == 0) {
      return ConsumptionAnalysisResult(0.0, 0.0);
    }

    final days = latest.difference(earliest).inDays.clamp(1, 365);
    final averageRate = totalUsed / days;

    return ConsumptionAnalysisResult(averageRate, averageRate);
  }

  // 🏠 HOUSEHOLD PROFILE METHODS
  Future<HouseholdProfile> _getHouseholdProfile(String householdId) async {
    final cached = _householdProfileCache[householdId];
    if (cached != null && DateTime.now().difference(cached.lastUpdated) < _cacheDuration) {
      return cached;
    }

    try {
      final profileDoc = await _firestore
          .collection('household_profiles')
          .doc(householdId)
          .get();

      HouseholdProfile profile;
      if (profileDoc.exists) {
        profile = HouseholdProfile.fromMap(profileDoc.data()!);
      } else {
        // Create default profile
        profile = HouseholdProfile(
          householdId: householdId,
          preferredItems: {},
          ignoredItems: {},
          restockFrequency: {},
          categoryPreferences: {},
          averageConsumptionRates: {},
          categoryConsumptionRates: {},
          lastUpdated: DateTime.now(),
          purchaseHistory: [],
          budgetLimits: {},
        );
      }

      _householdProfileCache[householdId] = profile;
      return profile;
    } catch (e) {
      _logError('Error getting household profile', e);
      return HouseholdProfile(
        householdId: householdId,
        preferredItems: {},
        ignoredItems: {},
        restockFrequency: {},
        categoryPreferences: {},
        averageConsumptionRates: {},
        categoryConsumptionRates: {},
        lastUpdated: DateTime.now(),
        purchaseHistory: [],
        budgetLimits: {},
      );
    }
  }

  Future<Map<String, CategoryConsumptionPattern>> _fetchCategoryConsumptionPatterns(String householdId) async {
    try {
      final patternsSnapshot = await _firestore
          .collection('household_consumption_patterns')
          .doc(householdId)
          .collection('category_patterns')
          .get();

      final patterns = <String, CategoryConsumptionPattern>{};
      
      for (final doc in patternsSnapshot.docs) {
        final data = doc.data();
        patterns[doc.id] = CategoryConsumptionPattern(
          category: doc.id,
          averageConsumptionRate: (data['averageConsumptionRate'] ?? 0.1).toDouble(),
          consistencyScore: (data['consistencyScore'] ?? 0.7).toDouble(),
          dataPoints: (data['dataPoints'] ?? 10).toInt(),
          adjustmentFactor: (data['adjustmentFactor'] ?? 1.0).toDouble(),
        );
      }

      return patterns;
    } catch (e) {
      _logError('Error fetching category consumption patterns', e);
      return {};
    }
  }

  // 📊 USAGE HISTORY METHODS
  Future<List<Map<String, dynamic>>> _getUsageHistory(String itemId, int days) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      final auditSnapshot = await _firestore
          .collection('inventory_audit_logs')
          .where('itemId', isEqualTo: itemId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .get();

      return auditSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': (data['timestamp'] as Timestamp).toDate(),
          'oldQuantity': data['oldValue'] ?? 0,
          'newQuantity': data['newValue'] ?? 0,
          'usageAmount': data['usageAmount'] ?? 0,
          'action': data['action'] ?? 'unknown',
        };
      }).toList();
    } catch (e) {
      _logError('Error getting usage history', e);
      return [];
    }
  }

  // 🔄 AUDIT LOG METHODS
  Future<void> _createUsageAuditLog({
    required String householdId,
    required String itemId,
    required String itemName,
    required int oldQuantity,
    required int newQuantity,
    required String userId,
    required String userName,
  }) async {
    try {
      if (oldQuantity == newQuantity) return; // No change
      
      final usageAmount = oldQuantity - newQuantity;
      if (usageAmount <= 0) return; // Only track consumption, not additions

      await _firestore.collection('inventory_audit_logs').add({
        'householdId': householdId,
        'itemId': itemId,
        'itemName': itemName,
        'action': 'consumed',
        'oldValue': oldQuantity,
        'newValue': newQuantity,
        'usageAmount': usageAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedByUserId': userId,
        'updatedByUserName': userName,
        'type': 'quantity_change',
      });

      print('📝 Created usage audit log: $itemName $oldQuantity → $newQuantity (used: $usageAmount)');
    } catch (e) {
      print('❌ Error creating usage audit log: $e');
    }
  }

  Future<DateTime?> _getLastRestockDate(String itemId) async {
    try {
      final auditSnapshot = await _firestore
          .collection('inventory_audit_logs')
          .where('itemId', isEqualTo: itemId)
          .where('action', isEqualTo: 'restocked')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (auditSnapshot.docs.isNotEmpty) {
        final data = auditSnapshot.docs.first.data();
        final timestamp = data['timestamp'] as Timestamp;
        return timestamp.toDate();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🎯 HELPER METHODS
  String _getSmartActionForType(String type) {
    const actions = {
      'low_stock_alert': 'restock',
      'min_stock_alert': 'restock',
      'critical_stock_alert': 'urgent_restock',
      'expiry_alert': 'use_soon',
      'critical_expiry_alert': 'use_immediately',
      'use_soon_alert': 'use_more_frequently',
      'usage_pattern_insight': 'monitor',
      'restock_reminder': 'plan_restock',
    };
    return actions[type] ?? 'monitor';
  }

  int _getPriorityColor(String priority) {
    const colors = {
      'high': 0xFFE74C3C,
      'medium': 0xFFF39C12,  
      'low': 0xFF2ECC71,
    };
    return colors[priority] ?? 0xFF95A5A6;
  }

  double _calculateUsageConsistency(String itemId, CategoryConsumptionPattern? householdPattern) {
    // If we have household pattern data, use its consistency score
    if (householdPattern != null) {
      return householdPattern.consistencyScore;
    }

    // Default consistency score
    return 0.7;
  }

  double _calculateRecommendationConfidence(UsageAnalysis analysis) {
    double confidence = 0.5;

    if (analysis.usageConsistency > 0.7) confidence += 0.3;
    if (analysis.consumptionRate > 0) confidence += 0.2;
    if (analysis.minStockCompliance < 1.0) confidence += 0.2;

    return confidence.clamp(0.0, 1.0);
  }

  List<Map<String, dynamic>> _getPersonalizedDefaultRecommendations(HouseholdProfile householdProfile) {
    return [
      {
        'type': 'welcome',
        'priority': 'low',
        'title': 'Welcome to Smart Recommendations',
        'message': 'Start adding items to your inventory to get personalized recommendations.',
        'icon': Icons.emoji_objects_rounded,
        'color': 0xFF2ECC71,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'aiGenerated': false,
      }
    ];
  }

  // 💾 CACHE MANAGEMENT
  void _cacheRecommendations(String cacheKey, List<Map<String, dynamic>> recommendations) {
    // Simple cache eviction if too large
    if (_recommendationCache.length >= _maxCacheSize) {
      _recommendationCache.remove(_recommendationCache.keys.first);
    }
    _recommendationCache[cacheKey] = recommendations;
  }

  void _cacheConsumptionRate(String itemId, double rate) {
    _consumptionRateCache[itemId] = _CachedConsumptionRate(rate, DateTime.now());
  }

  // 🔧 UTILITY METHODS
  String _formatCurrency(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  Future<double> _getExactPrice(String householdId, String itemId) async {
    try {
      final doc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['price'] != null) {
          return (data['price'] as num).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  String _getRecommendationKey(Map<String, dynamic> recommendation) {
    final itemId = recommendation['itemId'] as String? ?? '';
    final type = recommendation['type'] as String? ?? '';
    final timestamp = recommendation['timestamp'] as int? ?? 0;
    return '${itemId}_${type}_$timestamp';
  }

  bool _isRecommendationAdded(String householdId, Map<String, dynamic> recommendation) {
    final key = _getRecommendationKey(recommendation);
    return _addedRecommendations[householdId]?.contains(key) ?? false;
  }

  void _markRecommendationAsAdded(String householdId, Map<String, dynamic> recommendation) {
    final key = _getRecommendationKey(recommendation);
    _addedRecommendations.putIfAbsent(householdId, () => <String>{});
    _addedRecommendations[householdId]!.add(key);
    _recommendationCache.remove('${householdId}_recommendations');
  }

  Map<String, dynamic> _validateAndFixRecommendation(Map<String, dynamic> rec) {
    final fixedRec = Map<String, dynamic>.from(rec);
    
    if (fixedRec['itemId'] == null) {
      fixedRec['itemId'] = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    if (fixedRec['itemName'] == null) {
      fixedRec['itemName'] = 'Unknown Item';
    }
    
    if (fixedRec['category'] == null) {
      fixedRec['category'] = 'general';
    }
    
    if (fixedRec['priority'] == null) {
      fixedRec['priority'] = 'medium';
    }
    
    if (fixedRec['aiConfidence'] == null) {
      fixedRec['aiConfidence'] = 0.7;
    }
    
    return fixedRec;
  }

  Future<bool> _checkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  // 🐛 DIAGNOSTIC HELPERS
  Future<bool> _checkDuplicateItems(String householdId) async {
    try {
      final shoppingListSnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .get();

      final itemNames = <String>{};
      for (final doc in shoppingListSnapshot.docs) {
        final name = doc['name'] as String? ?? '';
        if (itemNames.contains(name)) {
          return true;
        }
        itemNames.add(name);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkExpiredRecommendations(String householdId) async {
    try {
      final weekAgo = DateTime.now().subtract(Duration(days: 7));
      final cacheKey = '${householdId}_recommendations';
      final cached = _recommendationCache[cacheKey];
      
      if (cached != null) {
        for (final rec in cached) {
          final timestamp = rec['timestamp'] as int? ?? 0;
          if (DateTime.fromMillisecondsSinceEpoch(timestamp).isBefore(weekAgo)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _logError(String message, dynamic error) {
    print('❌ $message: $error');
  }

  void _logPerformance(String message) {
    print('⏱️ $message');
  }

  // Clear all caches
  void clearCache() {
    _consumptionRateCache.clear();
    _householdProfileCache.clear();
    _recommendationCache.clear();
    _addedRecommendations.clear();
  }
}

// 🏠 DATA MODELS

class HouseholdProfile {
  final String householdId;
  final Set<String> preferredItems;
  final Set<String> ignoredItems;
  final Map<String, int> restockFrequency;
  final Map<String, double> categoryPreferences;
  final Map<String, double> averageConsumptionRates;
  final Map<String, double> categoryConsumptionRates;
  DateTime lastUpdated;
  final List<Map<String, dynamic>> purchaseHistory;
  final Map<String, double> budgetLimits;

  HouseholdProfile({
    required this.householdId,
    required this.preferredItems,
    required this.ignoredItems,
    required this.restockFrequency,
    required this.categoryPreferences,
    required this.averageConsumptionRates,
    required this.categoryConsumptionRates,
    required this.lastUpdated,
    required this.purchaseHistory,
    required this.budgetLimits,
  });

  Map<String, dynamic> toMap() {
    return {
      'householdId': householdId,
      'preferredItems': preferredItems.toList(),
      'ignoredItems': ignoredItems.toList(),
      'restockFrequency': restockFrequency,
      'categoryPreferences': categoryPreferences,
      'averageConsumptionRates': averageConsumptionRates,
      'categoryConsumptionRates': categoryConsumptionRates,
      'lastUpdated': lastUpdated.toIso8601String(),
      'purchaseHistory': purchaseHistory,
      'budgetLimits': budgetLimits,
    };
  }

  factory HouseholdProfile.fromMap(Map<String, dynamic> map) {
    return HouseholdProfile(
      householdId: map['householdId'] ?? '',
      preferredItems: Set<String>.from(map['preferredItems'] ?? []),
      ignoredItems: Set<String>.from(map['ignoredItems'] ?? []),
      restockFrequency: Map<String, int>.from(map['restockFrequency'] ?? {}),
      categoryPreferences: Map<String, double>.from(map['categoryPreferences'] ?? {}),
      averageConsumptionRates: Map<String, double>.from(map['averageConsumptionRates'] ?? {}),
      categoryConsumptionRates: Map<String, double>.from(map['categoryConsumptionRates'] ?? {}),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
      purchaseHistory: List<Map<String, dynamic>>.from(map['purchaseHistory'] ?? []),
      budgetLimits: Map<String, double>.from(map['budgetLimits'] ?? {}),
    );
  }
}

class CategoryConsumptionProfile {
  final String category;
  final double typicalDailyUsage;
  final double seasonality;
  final double urgencyMultiplier;
  final double minStockLevelMultiplier;
  final double expirySensitivity;
  final ConsumptionPattern consumptionPattern;
  final double priceSensitivity;
  final double bulkPurchaseScore;
  final double emergencyPriority;
  final int lowStockThreshold;
  final int expiryWarningThreshold;

  const CategoryConsumptionProfile({
    required this.category,
    required this.typicalDailyUsage,
    required this.seasonality,
    required this.urgencyMultiplier,
    required this.minStockLevelMultiplier,
    required this.expirySensitivity,
    required this.consumptionPattern,
    required this.priceSensitivity,
    required this.bulkPurchaseScore,
    required this.emergencyPriority,
    required this.lowStockThreshold,
    required this.expiryWarningThreshold,
  });
}

class CategoryConsumptionPattern {
  final String category;
  final double averageConsumptionRate;
  final double consistencyScore;
  final int dataPoints;
  final double adjustmentFactor;

  CategoryConsumptionPattern({
    required this.category,
    required this.averageConsumptionRate,
    required this.consistencyScore,
    required this.dataPoints,
    required this.adjustmentFactor,
  });
}

enum ConsumptionPattern {
  daily,
  regular,
  steady,
  irregular,
  variable,
}

class UsageAnalysis {
  final InventoryItem item;
  final double consumptionRate;
  final double daysOfSupply;
  final double stockoutProbability;
  final double expiryRisk;
  final CategoryConsumptionProfile categoryProfile;
  final DateTime? lastRestockDate;
  final double usageConsistency;
  final int minStockLevel;
  final bool isBelowMinStock;
  final double minStockCompliance;

  UsageAnalysis({
    required this.item,
    required this.consumptionRate,
    required this.daysOfSupply,
    required this.stockoutProbability,
    required this.expiryRisk,
    required this.categoryProfile,
    required this.lastRestockDate,
    required this.usageConsistency,
    required this.minStockLevel,
    required this.isBelowMinStock,
    required this.minStockCompliance,
  });

  Map<String, dynamic> toSummaryMap() {
    return {
      'consumptionRate': consumptionRate,
      'daysOfSupply': daysOfSupply,
      'stockoutProbability': stockoutProbability,
      'expiryRisk': expiryRisk,
      'usageConsistency': usageConsistency,
      'lastRestockDate': lastRestockDate?.toIso8601String(),
      'minStockLevel': minStockLevel,
      'isBelowMinStock': isBelowMinStock,
      'minStockCompliance': minStockCompliance,
    };
  }
}

class InventoryItem {
  final String? id;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? description;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? location;
  final String? supplier;
  final String? barcode;
  final int? minStockLevel;
  final String? imageUrl;
  final String? localImagePath;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? addedByUserId;
  final String? addedByUserName;
  final String? updatedByUserId;
  final String? updatedByUserName;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.description,
    this.purchaseDate,
    this.expiryDate,
    this.location,
    this.supplier,
    this.barcode,
    this.minStockLevel,
    this.imageUrl,
    this.localImagePath,
    required this.createdAt,
    this.updatedAt,
    this.addedByUserId,
    this.addedByUserName,
    this.updatedByUserId,
    this.updatedByUserName,
  });

  /// Converts object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'description': description,
      'purchaseDate': _dateToTimestamp(purchaseDate),
      'expiryDate': _dateToTimestamp(expiryDate),
      'location': location,
      'supplier': supplier,
      'barcode': barcode,
      'minStockLevel': minStockLevel,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'createdAt': _dateToTimestamp(createdAt) ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'addedByUserId': addedByUserId,
      'addedByUserName': addedByUserName,
      'updatedByUserId': updatedByUserId,
      'updatedByUserName': updatedByUserName,
    };
  }

  /// Helper method to convert DateTime to Timestamp
  Timestamp? _dateToTimestamp(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }

  /// Converts Firestore document into InventoryItem object
  factory InventoryItem.fromMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      quantity: (map['quantity'] ?? 0).toInt(),
      price: (map['price'] ?? 0.0).toDouble(),
      description: map['description'],
      purchaseDate: _timestampToDate(map['purchaseDate']),
      expiryDate: _timestampToDate(map['expiryDate']),
      location: map['location'],
      supplier: map['supplier'],
      barcode: map['barcode'],
      minStockLevel: map['minStockLevel']?.toInt(),
      imageUrl: map['imageUrl'],
      localImagePath: map['localImagePath'],
      createdAt: _timestampToDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _timestampToDate(map['updatedAt']),
      addedByUserId: map['addedByUserId'],
      addedByUserName: map['addedByUserName'],
      updatedByUserId: map['updatedByUserId'],
      updatedByUserName: map['updatedByUserName'],
    );
  }

  /// Helper method to convert Timestamp to DateTime
  static DateTime? _timestampToDate(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  /// Creates a copy of the item with updated fields
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? location,
    String? supplier,
    String? barcode,
    int? minStockLevel,
    String? imageUrl,
    String? localImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedByUserId,
    String? addedByUserName,
    String? updatedByUserId,
    String? updatedByUserName,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      location: location ?? this.location,
      supplier: supplier ?? this.supplier,
      barcode: barcode ?? this.barcode,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByUserName: addedByUserName ?? this.addedByUserName,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
      updatedByUserName: updatedByUserName ?? this.updatedByUserName,
    );
  }
}

class _CachedConsumptionRate {
  final double rate;
  final DateTime timestamp;

  _CachedConsumptionRate(this.rate, this.timestamp);
}

class ConsumptionAnalysisResult {
  final double averageRate;
  final double weightedRate;

  ConsumptionAnalysisResult(this.averageRate, this.weightedRate);
}