import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item_model.dart';
import 'package:flutter/material.dart';

class InventoryRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for consumption rates and household profiles
  final Map<String, _CachedConsumptionRate> _consumptionRateCache = {};
  final Map<String, HouseholdProfile> _householdProfileCache = {};
  static const Duration _cacheDuration = Duration(hours: 24);
  
  // User-configurable settings
  static const Map<String, int> _priorityWeights = {
    'critical': 0,
    'high': 1,
    'medium': 2,
    'info': 3,
  };
  
  static const int _maxRecommendations = 10;
  static const int _batchSize = 50;

  /// 🏠 HOUSEHOLD BEHAVIORAL ANALYTICS
  Future<void> trackHouseholdInteraction({
    required String householdId,
    required String itemId,
    required String action,
    required String itemName,
    String? category,
    int? quantity,
    double? price,
  }) async {
    try {
      final householdInteraction = {
        'householdId': householdId,
        'itemId': itemId,
        'itemName': itemName,
        'action': action,
        'category': category,
        'quantity': quantity,
        'price': price,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('household_interactions').add(householdInteraction);
      
      // Update household profile in background
      _updateHouseholdProfile(householdId, itemId, action, itemName, category);
      
      // Clear cache to ensure fresh data next time
      _householdProfileCache.remove(householdId);
      
    } catch (e) {
      _logError('Error tracking household interaction', e);
    }
  }

  /// 🏠 HOUSEHOLD PROFILE MANAGEMENT
  Future<void> _updateHouseholdProfile(
    String householdId,
    String itemId,
    String action,
    String itemName,
    String? category,
  ) async {
    try {
      final householdProfileRef = _firestore.collection('household_profiles').doc(householdId);

      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(householdProfileRef);
        HouseholdProfile profile;

        if (docSnapshot.exists) {
          profile = HouseholdProfile.fromMap(docSnapshot.data()!);
        } else {
          profile = HouseholdProfile(
            householdId: householdId,
            preferredItems: {},
            ignoredItems: {},
            restockFrequency: {},
            categoryPreferences: {},
            averageConsumptionRates: {},
            lastUpdated: DateTime.now(),
          );
        }

        // Update profile based on the action
        switch (action) {
          case 'restocked':
          case 'purchased':
            profile.preferredItems.add(itemId);
            profile.restockFrequency[itemId] = (profile.restockFrequency[itemId] ?? 0) + 1;
            if (category != null) {
              profile.categoryPreferences[category] = (profile.categoryPreferences[category] ?? 0) + 1;
            }
            break;
          
          case 'ignored':
            profile.ignoredItems.add(itemId);
            break;
          
          case 'clicked':
            if (category != null) {
              profile.categoryPreferences[category] = (profile.categoryPreferences[category] ?? 0) + 0.5;
            }
            break;
        }

        profile.lastUpdated = DateTime.now();
        transaction.set(householdProfileRef, profile.toMap());
      });

    } catch (e) {
      _logError('Error updating household profile', e);
    }
  }

  /// 🏠 GET HOUSEHOLD PROFILE WITH CACHING
  Future<HouseholdProfile> _getHouseholdProfile(String householdId) async {
    final cachedProfile = _householdProfileCache[householdId];
    if (cachedProfile != null && 
        DateTime.now().difference(cachedProfile.lastUpdated) < _cacheDuration) {
      return cachedProfile;
    }

    try {
      final profileSnapshot = await _firestore
          .collection('household_profiles')
          .doc(householdId)
          .get();

      HouseholdProfile profile;
      if (profileSnapshot.exists) {
        profile = HouseholdProfile.fromMap(profileSnapshot.data()!);
      } else {
        profile = HouseholdProfile(
          householdId: householdId,
          preferredItems: {},
          ignoredItems: {},
          restockFrequency: {},
          categoryPreferences: {},
          averageConsumptionRates: {},
          lastUpdated: DateTime.now(),
        );
      }

      _householdProfileCache[householdId] = profile;
      return profile;
    } catch (e) {
      _logError('Error fetching household profile', e);
      return HouseholdProfile(
        householdId: householdId,
        preferredItems: {},
        ignoredItems: {},
        restockFrequency: {},
        categoryPreferences: {},
        averageConsumptionRates: {},
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 🎯 ENHANCED: Main method with household personalization
  Future<List<Map<String, dynamic>>> getSmartRecommendations(String householdId) async {
    List<Map<String, dynamic>> recommendations = [];

    try {
      final responses = await Future.wait([
        _fetchInventoryBatch(householdId),
        _fetchAllConsumptionRates(householdId),
        _getHouseholdProfile(householdId),
      ]);

      final inventoryItems = responses[0] as List<InventoryItem>;
      final consumptionRates = responses[1] as Map<String, double>;
      final householdProfile = responses[2] as HouseholdProfile;

      if (inventoryItems.isEmpty) {
        return _getDefaultRecommendations();
      }

      for (final item in inventoryItems) {
        try {
          if (item.id?.isEmpty ?? true) continue;

          if (householdProfile.ignoredItems.contains(item.id)) {
            continue;
          }

          final itemConsumptionRate = consumptionRates[item.id] ?? 0.0;
          final itemRecommendations = _generatePersonalizedItemRecommendations(
            item, 
            itemConsumptionRate,
            householdProfile
          );
          
          recommendations.addAll(itemRecommendations);
        } catch (e) {
          _logError('Error processing item ${item.id}', e);
          continue;
        }
      }

      recommendations = _sortWithHouseholdPreferences(recommendations, householdProfile);

      if (recommendations.length > _maxRecommendations) {
        recommendations = recommendations.sublist(0, _maxRecommendations);
      }

      return recommendations;
    } catch (e) {
      _logError('Error generating recommendations for household $householdId', e);
      return _getDefaultRecommendations();
    }
  }

  /// 🚀 OPTIMIZED: Fetch inventory with pagination support
  Future<List<InventoryItem>> _fetchInventoryBatch(String householdId, {int limit = _batchSize}) async {
    try {
      final querySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .limit(limit)
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

  /// 🚀 OPTIMIZED: Fetch all consumption rates in parallel
  Future<Map<String, double>> _fetchAllConsumptionRates(String householdId) async {
    try {
      final inventorySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      final List<Future<MapEntry<String, double>>> consumptionRateFutures = inventorySnapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .map((itemId) async {
            final rate = await _calculateConsumptionRate(itemId);
            return MapEntry(itemId, rate);
          })
          .toList();

      final List<MapEntry<String, double>> results = await Future.wait(consumptionRateFutures);
      return Map<String, double>.fromEntries(results);
    } catch (e) {
      _logError('Error fetching consumption rates for household $householdId', e);
      return {};
    }
  }

  /// 🧮 TEMPORARY FIX: Consumption rate calculation without complex query
Future<double> _calculateConsumptionRate(String itemId) async {
  final now = DateTime.now();
  final cached = _consumptionRateCache[itemId];
  if (cached != null && now.difference(cached.timestamp) < _cacheDuration) {
    return cached.rate;
  }

  try {
    // SIMPLIFIED QUERY: Remove the timestamp filter temporarily
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

    // Filter by date in memory instead of in query
    final thirtyDaysAgo = now.subtract(Duration(days: 30));
    final recentLogs = auditSnapshot.docs.where((doc) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      return timestamp.isAfter(thirtyDaysAgo);
    }).toList();

    if (recentLogs.length < 2) {
      _cacheConsumptionRate(itemId, 0.0);
      return 0.0;
    }

    final consumptionData = _analyzeConsumptionPatterns(recentLogs);
    _cacheConsumptionRate(itemId, consumptionData.weightedRate);
    
    return consumptionData.weightedRate;
  } catch (e) {
    print('Error calculating consumption rate for item $itemId: $e');
    
    // Fallback: return a default consumption rate
    _cacheConsumptionRate(itemId, 0.5); // Default to 0.5 units per day
    return 0.5;
  }
}

  /// 📈 IMPROVED: Advanced consumption pattern analysis
  ConsumptionAnalysisResult _analyzeConsumptionPatterns(List<QueryDocumentSnapshot> auditLogs) {
    double totalUsed = 0;
    int validLogs = 0;
    final List<double> recentUsage = [];
    DateTime? earliest;
    DateTime? latest;

    for (var log in auditLogs) {
      try {
        final data = log.data() as Map<String, dynamic>;
        final oldVal = data['oldValue'] ?? 0;
        final newVal = data['newValue'] ?? 0;
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        if (oldVal is int && newVal is int && oldVal > newVal) {
          final usage = (oldVal - newVal).toDouble();
          totalUsed += usage;
          validLogs++;

          if (timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
            recentUsage.add(usage);
          }

          earliest = earliest == null || timestamp.isBefore(earliest) ? timestamp : earliest;
          latest = latest == null || timestamp.isAfter(latest) ? timestamp : latest;
        }
      } catch (e) {
        _logError('Error processing audit log', e);
        continue;
      }
    }

    if (earliest == null || latest == null || totalUsed == 0 || validLogs < 2) {
      return ConsumptionAnalysisResult(0.0, 0.0);
    }

    final days = latest.difference(earliest).inDays.clamp(1, 365);
    final averageRate = totalUsed / days;

    final recentAverage = recentUsage.isNotEmpty ? 
        recentUsage.reduce((a, b) => a + b) / recentUsage.length : averageRate;
    
    final weightedRate = (recentAverage * 0.6) + (averageRate * 0.4);

    return ConsumptionAnalysisResult(averageRate, weightedRate);
  }

  /// 🎯 PERSONALIZED: Generate recommendations with household preferences
  List<Map<String, dynamic>> _generatePersonalizedItemRecommendations(
    InventoryItem item, 
    double consumptionRate,
    HouseholdProfile householdProfile
  ) {
    final recommendations = <Map<String, dynamic>>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final preferenceScore = _calculateHouseholdPreferenceScore(item, householdProfile);

    // 1. 🚨 LOW STOCK ALERT
    if (item.minStockLevel != null && item.quantity < item.minStockLevel!) {
      final needed = item.minStockLevel! - item.quantity;
      final isPreferred = householdProfile.preferredItems.contains(item.id);
      
      recommendations.add(_buildRecommendation(
        type: 'low_stock',
        priority: isPreferred ? 'high' : 'medium',
        title: '${item.name} is running low',
        message: isPreferred 
            ? 'Your household frequently restocks this. Only ${item.quantity} left.'
            : 'Only ${item.quantity} left. Restock ${needed} more.',
        item: item,
        extraData: {
          'currentQuantity': item.quantity,
          'recommendedQuantity': needed,
          'minStockLevel': item.minStockLevel,
          'preferenceScore': preferenceScore,
          'isHouseholdPreferred': isPreferred,
        },
        icon: Icons.inventory_2_rounded,
        color: isPreferred ? 0xFFFF6B35 : 0xFFFFA726,
        timestamp: timestamp,
      ));
    }

    // 2. ⏰ EXPIRY ALERTS
    if (item.expiryDate != null) {
      final daysLeft = item.expiryDate!.difference(DateTime.now()).inDays;
      if (daysLeft <= 7 && daysLeft >= 0) {
        final isCritical = daysLeft <= 1;
        final isPreferred = householdProfile.preferredItems.contains(item.id);
        
        recommendations.add(_buildRecommendation(
          type: 'expiring_soon',
          priority: isCritical ? 'critical' : (isPreferred ? 'high' : 'medium'),
          title: '${item.name} ${isCritical ? 'expiring today!' : 'expiring soon'}',
          message: isCritical 
              ? 'Expires today! Use it immediately.' 
              : 'Expires in $daysLeft days.' + 
                (isPreferred ? ' Your household likes this item.' : ''),
          item: item,
          extraData: {
            'daysUntilExpiry': daysLeft,
            'preferenceScore': preferenceScore,
          },
          icon: Icons.warning_amber_rounded,
          color: isCritical ? 0xFFE74C3C : (isPreferred ? 0xFFF39C12 : 0xFFFFB74D),
          timestamp: timestamp,
        ));
      }
    }

    // 3. 📊 STOCKOUT PREDICTION
    if (consumptionRate > 0 && item.quantity > 0) {
      final daysRemaining = item.quantity / consumptionRate;
      if (daysRemaining <= 14) {
        final isUrgent = daysRemaining <= 3;
        final isPreferred = householdProfile.preferredItems.contains(item.id);
        final adjustedPriority = isUrgent ? 'high' : (isPreferred ? 'medium' : 'low');
        
        recommendations.add(_buildRecommendation(
          type: 'predicted_out_of_stock',
          priority: adjustedPriority,
          title: '${item.name} running out soon',
          message: 'Predicted to run out in ${daysRemaining.toStringAsFixed(1)} days.' +
                   (isPreferred ? ' Your household uses this frequently.' : ''),
          item: item,
          extraData: {
            'daysRemaining': daysRemaining,
            'consumptionRate': consumptionRate.toStringAsFixed(2),
            'predictedStockoutDate': DateTime.now().add(Duration(days: daysRemaining.ceil())),
            'preferenceScore': preferenceScore,
          },
          icon: Icons.trending_down_rounded,
          color: isPreferred ? 0xFF3498DB : 0xFF81D4FA,
          timestamp: timestamp,
        ));
      }
    }

    // 4. 💰 HIGH-VALUE MONITORING
    if (item.price != null && item.price! > 20 && item.quantity > 5) {
      final totalValue = item.price! * item.quantity;
      if (totalValue > 100) {
        final isPreferred = householdProfile.preferredItems.contains(item.id);
        
        recommendations.add(_buildRecommendation(
          type: 'high_value_stock',
          priority: 'info',
          title: 'High value item',
          message: '${item.name} has high inventory value (RM ${totalValue.toStringAsFixed(2)})' +
                   (isPreferred ? ' - Worth monitoring as your household uses this.' : ''),
          item: item,
          extraData: {
            'totalValue': totalValue,
            'preferenceScore': preferenceScore,
          },
          icon: Icons.attach_money_rounded,
          color: 0xFF27AE60,
          timestamp: timestamp,
        ));
      }
    }

    // 5. 📦 OVERSTOCK DETECTION
    if (item.minStockLevel != null && item.quantity > item.minStockLevel! * 3) {
      final isPreferred = householdProfile.preferredItems.contains(item.id);
      if (!isPreferred) {
        recommendations.add(_buildRecommendation(
          type: 'overstock',
          priority: 'info',
          title: '${item.name} might be overstocked',
          message: 'You have ${item.quantity} units, consider reducing stock.',
          item: item,
          extraData: {
            'currentQuantity': item.quantity,
            'suggestedMax': item.minStockLevel! * 2,
            'excessQuantity': item.quantity - (item.minStockLevel! * 2),
          },
          icon: Icons.archive_rounded,
          color: 0xFF9B59B6,
          timestamp: timestamp,
        ));
      }
    }

    return recommendations;
  }

  /// 🏗️ HELPER: Build consistent recommendation structure
  Map<String, dynamic> _buildRecommendation({
    required String type,
    required String priority,
    required String title,
    required String message,
    required InventoryItem item,
    required Map<String, dynamic> extraData,
    required IconData icon,
    required int color,
    required int timestamp,
  }) {
    return {
      'type': type,
      'priority': priority,
      'title': title,
      'message': message,
      'itemId': item.id,
      'itemName': item.name,
      'action': _getActionForType(type),
      'icon': icon,
      'color': color,
      'timestamp': timestamp,
      ...extraData,
    };
  }

  /// 🧮 CALCULATE HOUSEHOLD PREFERENCE SCORE
  double _calculateHouseholdPreferenceScore(InventoryItem item, HouseholdProfile profile) {
    double score = 0.0;
    
    if (profile.preferredItems.contains(item.id)) {
      score += 0.6;
    }
    
    final categoryCount = profile.categoryPreferences[item.category] ?? 0;
    score += (categoryCount * 0.1).clamp(0.0, 0.3);
      
    final restockCount = profile.restockFrequency[item.id] ?? 0;
    score += (restockCount * 0.05).clamp(0.0, 0.1);
    
    return score.clamp(0.0, 1.0);
  }

  /// 🎯 ENHANCED SORTING WITH HOUSEHOLD PREFERENCES
  List<Map<String, dynamic>> _sortWithHouseholdPreferences(
    List<Map<String, dynamic>> recommendations,
    HouseholdProfile householdProfile
  ) {
    recommendations.sort((a, b) {
      final priorityA = _priorityWeights[a['priority']] ?? 3;
      final priorityB = _priorityWeights[b['priority']] ?? 3;
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      final preferenceA = a['preferenceScore'] as double? ?? 0.0;
      final preferenceB = b['preferenceScore'] as double? ?? 0.0;
      if (preferenceA != preferenceB) {
        return preferenceB.compareTo(preferenceA);
      }
      
      final timestampA = a['timestamp'] as int;
      final timestampB = b['timestamp'] as int;
      return timestampB.compareTo(timestampA);
    });

    return recommendations;
  }

  /// 🛒 SHOPPING LIST GENERATION
  Future<List<Map<String, dynamic>>> getShoppingList(String householdId) async {
    try {
      final recommendations = await getSmartRecommendations(householdId);
      final shoppingList = <Map<String, dynamic>>[];
      final addedItems = <String>{};

      for (var rec in recommendations) {
        final itemId = rec['itemId'] as String?;
        if (itemId == null || addedItems.contains(itemId)) continue;

        final shoppingItem = _convertToShoppingItem(rec);
        if (shoppingItem != null) {
          shoppingList.add(shoppingItem);
          addedItems.add(itemId);
        }
      }

      return _sortShoppingList(shoppingList);
    } catch (e) {
      _logError('Error generating shopping list', e);
      return [];
    }
  }

  Map<String, dynamic>? _convertToShoppingItem(Map<String, dynamic> rec) {
    final type = rec['type'] as String;
    final itemId = rec['itemId'] as String?;
    
    if (itemId == null) return null;

    switch (type) {
      case 'low_stock':
        return {
          'itemName': rec['itemName'],
          'quantity': rec['recommendedQuantity'],
          'priority': rec['priority'],
          'reason': 'Low stock - only ${rec['currentQuantity']} left',
          'itemId': itemId,
          'category': 'restock',
          'urgent': rec['priority'] == 'high' || rec['priority'] == 'critical',
          'estimatedCost': rec['price'] != null ? 
              (rec['price'] as double) * (rec['recommendedQuantity'] as int) : null,
        };
      
      case 'predicted_out_of_stock':
        final daysRemaining = rec['daysRemaining'] as double;
        if (daysRemaining <= 3) {
          return {
            'itemName': rec['itemName'],
            'quantity': _calculateSmartQuantity(rec),
            'priority': rec['priority'],
            'reason': 'Running out in ${daysRemaining.toStringAsFixed(1)} days',
            'itemId': itemId,
            'category': 'predicted',
            'urgent': true,
            'estimatedCost': rec['price'] != null ? 
                (rec['price'] as double) * _calculateSmartQuantity(rec) : null,
          };
        }
        break;
    }
    
    return null;
  }

  /// 🧠 SMART: Calculate restock quantity
  int _calculateSmartQuantity(Map<String, dynamic> rec) {
    final consumptionRate = double.tryParse(rec['consumptionRate'] ?? '0') ?? 0;
    final minStock = rec['minStockLevel'] as int?;
    
    if (consumptionRate > 0 && minStock != null) {
      return (consumptionRate * 14).ceil().clamp(minStock, minStock * 4);
    }
    
    return 2;
  }

  List<Map<String, dynamic>> _sortShoppingList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      if (a['urgent'] != b['urgent']) {
        return (b['urgent'] as bool) ? 1 : -1;
      }
      return _priorityWeights[a['priority']]!.compareTo(_priorityWeights[b['priority']]!);
    });
    return list;
  }

  /// 🏠 HOUSEHOLD CONSUMPTION FORECASTING
  Future<Map<String, dynamic>> predictHouseholdConsumption(String householdId) async {
    try {
      final householdProfile = await _getHouseholdProfile(householdId);
      final predictions = <String, Map<String, dynamic>>{};

      householdProfile.restockFrequency.forEach((itemId, frequency) {
        final averageRestockCycle = 30 / frequency.clamp(1, 30);
        final nextRestockInDays = averageRestockCycle;
        
        predictions[itemId] = {
          'itemId': itemId,
          'predictedRestockInDays': nextRestockInDays,
          'restockFrequency': frequency,
          'confidence': _calculatePredictionConfidence(frequency),
          'nextRestockDate': DateTime.now().add(Duration(days: nextRestockInDays.ceil())),
        };
      });

      return {
        'householdId': householdId,
        'predictions': predictions,
        'generatedAt': DateTime.now().toIso8601String(),
        'totalTrackedItems': predictions.length,
        'mostFrequentItems': _getMostFrequentItems(householdProfile, 5),
      };
    } catch (e) {
      _logError('Error predicting household consumption', e);
      return {'error': e.toString()};
    }
  }

  /// 🧮 CALCULATE PREDICTION CONFIDENCE
  double _calculatePredictionConfidence(int frequency) {
    return (frequency / 10.0).clamp(0.1, 0.9);
  }

  /// 📊 GET MOST FREQUENT ITEMS
  List<Map<String, dynamic>> _getMostFrequentItems(HouseholdProfile profile, int limit) {
    final sortedItems = profile.restockFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedItems.take(limit).map((entry) => {
      'itemId': entry.key,
      'restockCount': entry.value,
    }).toList();
  }

  /// 🏠 GET HOUSEHOLD INSIGHTS
  Future<Map<String, dynamic>> getHouseholdInsights(String householdId) async {
    try {
      final householdProfile = await _getHouseholdProfile(householdId);
      final recommendations = await getSmartRecommendations(householdId);
      
      final totalInteractions = householdProfile.restockFrequency.values.fold(0, (sum, count) => sum + count);
      final preferredCategories = _getTopCategories(householdProfile, 3);
      final consumptionPatterns = await predictHouseholdConsumption(householdId);

      return {
        'householdId': householdId,
        'profileAge': DateTime.now().difference(householdProfile.lastUpdated).inDays,
        'totalInteractions': totalInteractions,
        'preferredItemsCount': householdProfile.preferredItems.length,
        'ignoredItemsCount': householdProfile.ignoredItems.length,
        'topCategories': preferredCategories,
        'consumptionPatterns': consumptionPatterns,
        'activeRecommendations': recommendations.length,
        'householdBehaviorScore': _calculateHouseholdBehaviorScore(householdProfile),
        'insights': _generateHouseholdInsights(householdProfile, recommendations),
      };
    } catch (e) {
      _logError('Error generating household insights', e);
      return {'error': e.toString()};
    }
  }

  /// 📈 CALCULATE HOUSEHOLD BEHAVIOR SCORE
  double _calculateHouseholdBehaviorScore(HouseholdProfile profile) {
    final totalInteractions = profile.restockFrequency.values.fold(0, (sum, count) => sum + count);
    final diversity = profile.categoryPreferences.length / 10.0;
    const maxExpectedInteractions = 100;
    
    final interactionScore = (totalInteractions / maxExpectedInteractions).clamp(0.0, 1.0);
    final diversityScore = diversity.clamp(0.0, 1.0);
    
    return (interactionScore * 0.7 + diversityScore * 0.3);
  }

  /// 🎯 GENERATE HOUSEHOLD INSIGHTS
  List<String> _generateHouseholdInsights(HouseholdProfile profile, List<Map<String, dynamic>> recommendations) {
    final insights = <String>[];
    
    if (profile.preferredItems.isEmpty) {
      insights.add('Start tracking your restocks to get personalized recommendations');
    } else {
      insights.add('Your household has ${profile.preferredItems.length} frequently used items');
    }
    
    if (profile.categoryPreferences.isNotEmpty) {
      final topCategory = _getTopCategories(profile, 1).first;
      insights.add('Your household prefers ${topCategory['category']} items');
    }
    
    final urgentCount = recommendations.where((r) => 
      r['priority'] == 'critical' || r['priority'] == 'high').length;
    if (urgentCount > 0) {
      insights.add('You have $urgentCount urgent recommendations needing attention');
    }
    
    return insights;
  }

  List<Map<String, dynamic>> _getTopCategories(HouseholdProfile profile, int limit) {
    final sortedCategories = profile.categoryPreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedCategories.take(limit).map((entry) => {
      'category': entry.key,
      'preferenceScore': entry.value,
    }).toList();
  }

  /// 📊 RECOMMENDATION STATISTICS
  Future<Map<String, dynamic>> getRecommendationStats(String householdId) async {
    try {
      final recommendations = await getSmartRecommendations(householdId);
      
      final Map<String, int> stats = {
        'critical': 0, 'high': 0, 'medium': 0, 'info': 0,
        'low_stock': 0, 'expiring_soon': 0, 'predicted_out_of_stock': 0,
        'high_value_stock': 0, 'overstock': 0,
      };

      for (var rec in recommendations) {
        final priority = rec['priority'] as String;
        final type = rec['type'] as String;
        
        stats[priority] = (stats[priority] ?? 0) + 1;
        stats[type] = (stats[type] ?? 0) + 1;
      }

      return {
        'total': recommendations.length,
        ...stats,
        'hasUrgent': (stats['critical'] ?? 0) > 0 || (stats['high'] ?? 0) > 0,
        'generatedAt': DateTime.now().toIso8601String(),
        'summary': _generateSummaryMessage(stats),
      };
    } catch (e) {
      _logError('Error generating recommendation stats', e);
      return {'total': 0, 'hasUrgent': false, 'error': e.toString()};
    }
  }

  String _generateSummaryMessage(Map<String, int> stats) {
    final critical = stats['critical'] ?? 0;
    final high = stats['high'] ?? 0;
    
    if (critical > 0) return '$critical critical items need attention!';
    if (high > 0) return '$high high priority items to review';
    if ((stats['total'] ?? 0) > 0) return 'Inventory is well managed';
    return 'Add items to get recommendations';
  }

  /// 🔧 HELPER METHODS
  String _getActionForType(String type) {
    const actions = {
      'low_stock': 'restock',
      'expiring_soon': 'use_soon',
      'predicted_out_of_stock': 'plan_restock',
      'high_value_stock': 'monitor',
      'overstock': 'reduce_stock',
    };
    return actions[type] ?? 'monitor';
  }

  void _cacheConsumptionRate(String itemId, double rate) {
    _consumptionRateCache[itemId] = _CachedConsumptionRate(rate, DateTime.now());
  }

  void _logError(String message, dynamic error) {
    print('❌ $message: $error');
  }

  /// 🏠 DEFAULT RECOMMENDATIONS
  List<Map<String, dynamic>> _getDefaultRecommendations() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return [
      {
        'type': 'welcome',
        'priority': 'info',
        'title': 'Welcome to Smart Inventory!',
        'message': 'Add some items to get personalized recommendations.',
        'itemId': '',
        'itemName': '',
        'action': 'add_items',
        'icon': Icons.emoji_objects_rounded,
        'color': 0xFF3498DB,
        'timestamp': timestamp,
      },
      {
        'type': 'tip',
        'priority': 'info',
        'title': 'Pro Tip',
        'message': 'Set minimum stock levels and expiry dates for better predictions.',
        'itemId': '',
        'itemName': '',
        'action': 'learn_more',
        'icon': Icons.lightbulb_rounded,
        'color': 0xFFF39C12,
        'timestamp': timestamp,
      }
    ];
  }

  /// 🧹 CLEANUP: Clear cache
  void clearCache() {
    _consumptionRateCache.clear();
    _householdProfileCache.clear();
  }
}

/// 🏠 HOUSEHOLD PROFILE MODEL
class HouseholdProfile {
  final String householdId;
  final Set<String> preferredItems;
  final Set<String> ignoredItems;
  final Map<String, int> restockFrequency;
  final Map<String, double> categoryPreferences;
  final Map<String, double> averageConsumptionRates;
  DateTime lastUpdated;

  HouseholdProfile({
    required this.householdId,
    required this.preferredItems,
    required this.ignoredItems,
    required this.restockFrequency,
    required this.categoryPreferences,
    required this.averageConsumptionRates,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'householdId': householdId,
      'preferredItems': preferredItems.toList(),
      'ignoredItems': ignoredItems.toList(),
      'restockFrequency': restockFrequency,
      'categoryPreferences': categoryPreferences,
      'averageConsumptionRates': averageConsumptionRates,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory HouseholdProfile.fromMap(Map<String, dynamic> map) {
    return HouseholdProfile(
      householdId: map['householdId'],
      preferredItems: Set<String>.from(map['preferredItems'] ?? []),
      ignoredItems: Set<String>.from(map['ignoredItems'] ?? []),
      restockFrequency: Map<String, int>.from(map['restockFrequency'] ?? {}),
      categoryPreferences: Map<String, double>.from(map['categoryPreferences'] ?? {}),
      averageConsumptionRates: Map<String, double>.from(map['averageConsumptionRates'] ?? {}),
      lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// 📊 DATA MODELS FOR BETTER TYPE SAFETY
class ConsumptionAnalysisResult {
  final double averageRate;
  final double weightedRate;

  ConsumptionAnalysisResult(this.averageRate, this.weightedRate);
}

class _CachedConsumptionRate {
  final double rate;
  final DateTime timestamp;

  _CachedConsumptionRate(this.rate, this.timestamp);
}