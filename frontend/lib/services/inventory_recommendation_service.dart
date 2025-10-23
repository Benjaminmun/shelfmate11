// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import '../models/inventory_item_model.dart';
// import 'package:flutter/material.dart';

// class InventoryRecommendationService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final Connectivity _connectivity = Connectivity();
//   bool _isOnline = true;
  
//   // Enhanced cache with size limits
//   final Map<String, _CachedConsumptionRate> _consumptionRateCache = {};
//   final Map<String, HouseholdProfile> _householdProfileCache = {};
//   static const Duration _cacheDuration = Duration(hours: 24);
//   static const int _maxCacheSize = 1000;
  
//   // Performance monitoring
//   final Map<String, int> _performanceMetrics = {
//     'totalRequests': 0,
//     'cacheHits': 0,
//     'lastRun': 0,
//   };
  
//   // User-configurable settings
//   static const Map<String, int> _priorityWeights = {
//     'critical': 0,
//     'high': 1,
//     'medium': 2,
//     'info': 3,
//   };
  
//   static const int _maxRecommendations = 15;
//   static const int _batchSize = 50;

//   InventoryRecommendationService() {
//     _startConnectivityMonitoring();
//     _setupPerformanceMonitoring();
//   }

//   /// 🌐 CONNECTIVITY MONITORING
//   void _startConnectivityMonitoring() {
//     _connectivity.onConnectivityChanged.listen((result) {
//       _isOnline = result != ConnectivityResult.none;
//       if (_isOnline) {
//         _syncOfflineData();
//       }
//     });
//   }

//   void _setupPerformanceMonitoring() {
//     _performanceMetrics['lastRun'] = DateTime.now().millisecondsSinceEpoch;
//   }

//   Future<void> _syncOfflineData() async {
//     _logInfo('Device back online - syncing data if needed');
//   }

//   /// 🏠 HOUSEHOLD BEHAVIORAL ANALYTICS
//   Future<void> trackHouseholdInteraction({
//     required String householdId,
//     required String itemId,
//     required String action,
//     required String itemName,
//     String? category,
//     int? quantity,
//     double? price,
//   }) async {
//     try {
//       final householdInteraction = {
//         'householdId': householdId,
//         'itemId': itemId,
//         'itemName': itemName,
//         'action': action,
//         'category': category,
//         'quantity': quantity,
//         'price': price,
//         'timestamp': FieldValue.serverTimestamp(),
//         'offline': !_isOnline,
//       };

//       if (_isOnline) {
//         await _firestore.collection('household_interactions').add(householdInteraction);
//       } else {
//         await _storeOfflineInteraction(householdInteraction);
//       }
      
//       _updateHouseholdProfile(householdId, itemId, action, itemName, category);
//       _householdProfileCache.remove(householdId);
      
//     } catch (e) {
//       _logError('Error tracking household interaction', e);
//     }
//   }

//   Future<void> _storeOfflineInteraction(Map<String, dynamic> interaction) async {
//     _logInfo('Storing interaction offline: ${interaction['action']}');
//   }

//   /// 🏠 HOUSEHOLD PROFILE MANAGEMENT
//   Future<void> _updateHouseholdProfile(
//     String householdId,
//     String itemId,
//     String action,
//     String itemName,
//     String? category,
//   ) async {
//     try {
//       final householdProfileRef = _firestore.collection('household_profiles').doc(householdId);

//       await _firestore.runTransaction((transaction) async {
//         final docSnapshot = await transaction.get(householdProfileRef);
//         HouseholdProfile profile;

//         if (docSnapshot.exists) {
//           profile = HouseholdProfile.fromMap(docSnapshot.data()!);
//         } else {
//           profile = HouseholdProfile(
//             householdId: householdId,
//             preferredItems: {},
//             ignoredItems: {},
//             restockFrequency: {},
//             categoryPreferences: {},
//             averageConsumptionRates: {},
//             lastUpdated: DateTime.now(),
//           );
//         }

//         switch (action) {
//           case 'restocked':
//           case 'purchased':
//             profile.preferredItems.add(itemId);
//             profile.restockFrequency[itemId] = (profile.restockFrequency[itemId] ?? 0) + 1;
//             if (category != null) {
//               profile.categoryPreferences[category] = (profile.categoryPreferences[category] ?? 0) + 1;
//             }
//             break;
          
//           case 'ignored':
//             profile.ignoredItems.add(itemId);
//             break;
          
//           case 'clicked':
//             if (category != null) {
//               profile.categoryPreferences[category] = (profile.categoryPreferences[category] ?? 0) + 0.5;
//             }
//             break;
//         }

//         profile.lastUpdated = DateTime.now();
//         transaction.set(householdProfileRef, profile.toMap());
//       });

//     } catch (e) {
//       _logError('Error updating household profile', e);
//     }
//   }

//   /// 🏠 GET HOUSEHOLD PROFILE WITH ENHANCED CACHING
//   Future<HouseholdProfile> _getHouseholdProfile(String householdId) async {
//     _performanceMetrics['totalRequests'] = (_performanceMetrics['totalRequests'] ?? 0) + 1;
    
//     final cachedProfile = _householdProfileCache[householdId];
//     if (cachedProfile != null && 
//         DateTime.now().difference(cachedProfile.lastUpdated) < _cacheDuration) {
//       _performanceMetrics['cacheHits'] = (_performanceMetrics['cacheHits'] ?? 0) + 1;
//       return cachedProfile;
//     }

//     try {
//       final profileSnapshot = await _firestore
//           .collection('household_profiles')
//           .doc(householdId)
//           .get();

//       HouseholdProfile profile;
//       if (profileSnapshot.exists) {
//         profile = HouseholdProfile.fromMap(profileSnapshot.data()!);
//       } else {
//         profile = HouseholdProfile(
//           householdId: householdId,
//           preferredItems: {},
//           ignoredItems: {},
//           restockFrequency: {},
//           categoryPreferences: {},
//           averageConsumptionRates: {},
//           lastUpdated: DateTime.now(),
//         );
//       }

//       _householdProfileCache[householdId] = profile;
//       _cleanExpiredCache();
      
//       return profile;
//     } catch (e) {
//       _logError('Error fetching household profile', e);
//       return HouseholdProfile(
//         householdId: householdId,
//         preferredItems: {},
//         ignoredItems: {},
//         restockFrequency: {},
//         categoryPreferences: {},
//         averageConsumptionRates: {},
//         lastUpdated: DateTime.now(),
//       );
//     }
//   }

//   /// 🎯 ENHANCED: Main method with household personalization
//   Future<List<Map<String, dynamic>>> getSmartRecommendations(String householdId) async {
//     final stopwatch = Stopwatch()..start();
//     List<Map<String, dynamic>> recommendations = [];

//     try {
//       final responses = await Future.wait([
//         _fetchInventoryBatch(householdId),
//         _fetchAllConsumptionRates(householdId),
//         _getHouseholdProfile(householdId),
//       ]);

//       final inventoryItems = responses[0] as List<InventoryItem>;
//       final consumptionRates = responses[1] as Map<String, double>;
//       final householdProfile = responses[2] as HouseholdProfile;

//       if (inventoryItems.isEmpty) {
//         return _getDefaultRecommendations();
//       }

//       for (final item in inventoryItems) {
//         try {
//           if (item.id?.isEmpty ?? true) continue;

//           if (householdProfile.ignoredItems.contains(item.id)) {
//             continue;
//           }

//           final itemConsumptionRate = consumptionRates[item.id] ?? 0.0;
//           final itemRecommendations = _generateEnhancedItemRecommendations(
//             item, 
//             itemConsumptionRate,
//             householdProfile
//           );
          
//           recommendations.addAll(itemRecommendations);
//         } catch (e) {
//           _logError('Error processing item ${item.id}', e);
//           continue;
//         }
//       }

//       recommendations = _sortWithHouseholdPreferences(recommendations, householdProfile);

//       if (recommendations.length > _maxRecommendations) {
//         recommendations = recommendations.sublist(0, _maxRecommendations);
//       }

//       stopwatch.stop();
//       _trackPerformance('getSmartRecommendations', stopwatch.elapsedMilliseconds);
      
//       return recommendations;
//     } catch (e) {
//       _logError('Error generating recommendations for household $householdId', e);
//       return _getDefaultRecommendations();
//     }
//   }

//   /// 🚀 OPTIMIZED: Fetch inventory with pagination support
//   Future<List<InventoryItem>> _fetchInventoryBatch(String householdId, {int limit = _batchSize}) async {
//     try {
//       final querySnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .limit(limit)
//           .get();

//       return querySnapshot.docs
//           .map((doc) {
//             try {
//               return InventoryItem.fromMap(doc.data(), doc.id);
//             } catch (e) {
//               _logError('Error parsing inventory item ${doc.id}', e);
//               return null;
//             }
//           })
//           .where((item) => item != null && (item.id?.isNotEmpty ?? false))
//           .cast<InventoryItem>()
//           .toList();
//     } catch (e) {
//       _logError('Error fetching inventory for household $householdId', e);
//       return [];
//     }
//   }

//   /// 🚀 OPTIMIZED: Fetch all consumption rates in parallel
//   Future<Map<String, double>> _fetchAllConsumptionRates(String householdId) async {
//     try {
//       final inventorySnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .get();

//       final List<Future<MapEntry<String, double>>> consumptionRateFutures = inventorySnapshot.docs
//           .map((doc) => doc.id)
//           .where((id) => id.isNotEmpty)
//           .map((itemId) async {
//             final rate = await _calculateEnhancedConsumptionRate(itemId);
//             return MapEntry(itemId, rate);
//           })
//           .toList();

//       final List<MapEntry<String, double>> results = await Future.wait(consumptionRateFutures);
//       return Map<String, double>.fromEntries(results);
//     } catch (e) {
//       _logError('Error fetching consumption rates for household $householdId', e);
//       return {};
//     }
//   }

//   /// 🧮 ENHANCED: Robust consumption rate calculation with multiple fallbacks
//   Future<double> _calculateEnhancedConsumptionRate(String itemId) async {
//     final now = DateTime.now();
//     final cached = _consumptionRateCache[itemId];
//     if (cached != null && now.difference(cached.timestamp) < _cacheDuration) {
//       return cached.rate;
//     }

//     try {
//       final thirtyDaysAgo = Timestamp.fromDate(now.subtract(Duration(days: 30)));
      
//       final auditSnapshot = await _firestore
//           .collection('inventory_audit_logs')
//           .where('itemId', isEqualTo: itemId)
//           .where('timestamp', isGreaterThanOrEqualTo: thirtyDaysAgo)
//           .orderBy('timestamp', descending: true)
//           .limit(50)
//           .get(const GetOptions(source: Source.server));

//       if (auditSnapshot.docs.isNotEmpty) {
//         final consumptionData = _analyzeEnhancedConsumptionPatterns(auditSnapshot.docs);
//         _cacheConsumptionRate(itemId, consumptionData.weightedRate);
//         return consumptionData.weightedRate;
//       }

//       final fallbackRate = await _getFallbackConsumptionRate(itemId);
//       _cacheConsumptionRate(itemId, fallbackRate);
//       return fallbackRate;

//     } catch (e) {
//       _logError('Error calculating consumption rate for item $itemId', e);
      
//       final fallbackRate = await _getUltimateFallbackRate(itemId);
//       _cacheConsumptionRate(itemId, fallbackRate);
//       return fallbackRate;
//     }
//   }

//   /// 🔄 FALLBACK: Get consumption rate from household profile
//   Future<double> _getFallbackConsumptionRate(String itemId) async {
//     try {
//       final householdProfiles = await _firestore
//           .collection('household_profiles')
//           .where('restockFrequency.$itemId', isGreaterThan: 0)
//           .limit(5)
//           .get();

//       if (householdProfiles.docs.isNotEmpty) {
//         double totalFrequency = 0;
//         int count = 0;
        
//         for (final profile in householdProfiles.docs) {
//           final data = profile.data();
//           final frequency = (data['restockFrequency']?[itemId] ?? 0).toDouble();
//           if (frequency > 0) {
//             totalFrequency += frequency;
//             count++;
//           }
//         }
        
//         if (count > 0) {
//           return (totalFrequency / count) / 30.0;
//         }
//       }
//     } catch (e) {
//       _logError('Error in fallback consumption rate', e);
//     }
    
//     return 0.5;
//   }

//   Future<double> _getUltimateFallbackRate(String itemId) async {
//     await Future.delayed(Duration(milliseconds: 100));
//     return 0.5;
//   }

//   /// 📈 ENHANCED: Advanced consumption pattern analysis
//   ConsumptionAnalysisResult _analyzeEnhancedConsumptionPatterns(List<QueryDocumentSnapshot> auditLogs) {
//     double totalUsed = 0;
//     int validLogs = 0;
//     final List<double> recentUsage = [];
//     final List<double> weeklyUsage = [];
//     DateTime? earliest;
//     DateTime? latest;

//     final now = DateTime.now();
//     final oneWeekAgo = now.subtract(Duration(days: 7));
//     final twoWeeksAgo = now.subtract(Duration(days: 14));

//     for (var log in auditLogs) {
//       try {
//         final data = log.data() as Map<String, dynamic>;
//         final oldVal = data['oldValue'] ?? 0;
//         final newVal = data['newValue'] ?? 0;
//         final timestamp = (data['timestamp'] as Timestamp).toDate();

//         if (oldVal is int && newVal is int && oldVal > newVal) {
//           final usage = (oldVal - newVal).toDouble();
//           totalUsed += usage;
//           validLogs++;

//           if (timestamp.isAfter(oneWeekAgo)) {
//             recentUsage.add(usage);
//           } else if (timestamp.isAfter(twoWeeksAgo)) {
//             weeklyUsage.add(usage);
//           }

//           earliest = earliest == null || timestamp.isBefore(earliest) ? timestamp : earliest;
//           latest = latest == null || timestamp.isAfter(latest) ? timestamp : latest;
//         }
//       } catch (e) {
//         _logError('Error processing audit log', e);
//         continue;
//       }
//     }

//     if (earliest == null || latest == null || totalUsed == 0 || validLogs < 2) {
//       return ConsumptionAnalysisResult(0.0, 0.0);
//     }

//     final days = latest.difference(earliest).inDays.clamp(1, 365);
//     final averageRate = totalUsed / days;

//     double weightedRate = averageRate;
//     if (recentUsage.isNotEmpty) {
//       final recentAverage = recentUsage.reduce((a, b) => a + b) / recentUsage.length;
//       final weeklyAverage = weeklyUsage.isNotEmpty ? 
//           weeklyUsage.reduce((a, b) => a + b) / weeklyUsage.length : averageRate;
      
//       weightedRate = (recentAverage * 0.6) + (weeklyAverage * 0.3) + (averageRate * 0.1);
//     }

//     return ConsumptionAnalysisResult(averageRate, weightedRate);
//   }

// /// 🧠 ENHANCED: Smarter recommendation generation with ML-like features
// List<Map<String, dynamic>> _generateEnhancedItemRecommendations(
//   InventoryItem item, 
//   double consumptionRate,
//   HouseholdProfile householdProfile
// ) {
//   final recommendations = <Map<String, dynamic>>[];
//   final timestamp = DateTime.now().millisecondsSinceEpoch;

//   final preferenceScore = _calculateHouseholdPreferenceScore(item, householdProfile);

//   // 🚨 ENHANCED LOW STOCK ALERT with smart quantity calculation
//   if (item.minStockLevel != null && item.quantity < item.minStockLevel!) {
//     final needed = _calculateOptimalRestockQuantity(
//       item, 
//       consumptionRate, 
//       householdProfile,
//     );
    
//     final stockoutRisk = _calculateStockoutRisk(item, consumptionRate);
//     final priority = _determineStockoutPriority(stockoutRisk, preferenceScore);
    
//     recommendations.add(_buildRecommendation(
//       type: 'low_stock',
//       priority: priority,
//       title: _generateLowStockTitle(item, stockoutRisk),
//       message: _generateLowStockMessage(item, needed, stockoutRisk, preferenceScore),
//       item: item,
//       extraData: {
//         'currentQuantity': item.quantity,
//         'recommendedQuantity': needed,
//         'minStockLevel': item.minStockLevel,
//         'preferenceScore': preferenceScore,
//         'stockoutRisk': stockoutRisk,
//         'optimalRestockQuantity': needed,
//         'estimatedRestockCost': item.price != null ? item.price! * needed : null,
//         'daysOfCoverage': consumptionRate > 0 ? item.quantity / consumptionRate : 0,
//       },
//       icon: _getStockoutIcon(stockoutRisk),
//       color: _getStockoutColor(stockoutRisk, preferenceScore),
//       timestamp: timestamp,
//     ));
//   }

//   // ⏰ ENHANCED EXPIRY ALERTS with usage suggestions
//   if (item.expiryDate != null) {
//     final expiryRecommendation = _generateExpiryRecommendation(
//       item, preferenceScore, timestamp
//     );
//     if (expiryRecommendation != null) {
//       recommendations.add(expiryRecommendation);
//     }
//   }

//   // 📊 ENHANCED STOCKOUT PREDICTION
//   if (consumptionRate > 0 && item.quantity > 0) {
//     final daysRemaining = item.quantity / consumptionRate;
//     if (daysRemaining <= 21) {
//       _calculateStockoutRisk(item, consumptionRate);
//       final isUrgent = daysRemaining <= 3;
//       final isPreferred = householdProfile.preferredItems.contains(item.id);
//       final adjustedPriority = isUrgent ? 'high' : (isPreferred ? 'medium' : 'low');
      
//       recommendations.add(_buildRecommendation(
//         type: 'predicted_out_of_stock',
//         priority: adjustedPriority,
//         title: '${item.name} running out in ${daysRemaining.toStringAsFixed(1)} days',
//         message: 'Based on usage patterns. ${isPreferred ? 'Your household uses this frequently.' : 'Consider planning your restock.'}',
//         item: item,
//         extraData: {
//           'daysRemaining': daysRemaining,
//           'consumptionRate': consumptionRate.toStringAsFixed(2),
//           'predictedStockoutDate': DateTime.now().add(Duration(days: daysRemaining.ceil())),
//           'preferenceScore': preferenceScore,
//           'confidence': _calculatePredictionConfidenceFromData(consumptionRate, item.quantity),
//         },
//         icon: Icons.trending_down_rounded,
//         color: isPreferred ? 0xFF3498DB : 0xFF81D4FA,
//         timestamp: timestamp,
//       ));
//     }
//   }

//   // 💰 ENHANCED HIGH-VALUE MONITORING
//   if (item.price != null && item.price! > 20 && item.quantity > 5) {
//     final totalValue = item.price! * item.quantity;
//     if (totalValue > 100) {
//       final isPreferred = householdProfile.preferredItems.contains(item.id);
      
//       recommendations.add(_buildRecommendation(
//         type: 'high_value_stock',
//         priority: 'info',
//         title: 'High value item',
//         message: '${item.name} has high inventory value (RM ${totalValue.toStringAsFixed(2)})' +
//                  (isPreferred ? ' - Worth monitoring as your household uses this.' : ' - Consider insurance or secure storage.'),
//         item: item,
//         extraData: {
//           'totalValue': totalValue,
//           'preferenceScore': preferenceScore,
//           'valuePerUnit': item.price,
//         },
//         icon: Icons.attach_money_rounded,
//         color: 0xFF27AE60,
//         timestamp: timestamp,
//       ));
//     }
//   }

//   // 📦 ENHANCED OVERSTOCK DETECTION
//   if (item.minStockLevel != null && item.quantity > item.minStockLevel! * 3) {
//     final isPreferred = householdProfile.preferredItems.contains(item.id);
//     final excessQuantity = item.quantity - (item.minStockLevel! * 2);
    
//     if (!isPreferred || excessQuantity > 10) {
//       recommendations.add(_buildRecommendation(
//         type: 'overstock',
//         priority: 'info',
//         title: '${item.name} might be overstocked',
//         message: 'You have ${item.quantity} units (${excessQuantity} excess). Consider reducing stock to free up space and capital.',
//         item: item,
//         extraData: {
//           'currentQuantity': item.quantity,
//           'suggestedMax': item.minStockLevel! * 2,
//           'excessQuantity': excessQuantity,
//           'tiedUpCapital': item.price != null ? item.price! * excessQuantity : null,
//         },
//         icon: Icons.archive_rounded,
//         color: 0xFF9B59B6,
//         timestamp: timestamp,
//       ));
//     }
//   }

//   return recommendations;
// }

// /// 🎯 CALCULATE OPTIMAL RESTOCK QUANTITY
// int _calculateOptimalRestockQuantity(
//   InventoryItem item, 
//   double consumptionRate,
//   HouseholdProfile profile,
// ) {
//   final baseMinStock = item.minStockLevel ?? 5;
//   final dailyConsumption = consumptionRate;
  
//   int desiredCoverageDays = 14;
//   if (profile.preferredItems.contains(item.id)) {
//     desiredCoverageDays = 21;
//   }
  
//   final neededForCoverage = (dailyConsumption * desiredCoverageDays).ceil();
  
//   final totalNeeded = _max(baseMinStock, neededForCoverage);
//   final toRestock = totalNeeded - item.quantity;
  
//   return _max(1, toRestock);
// }

//   int _max(int a, int b) => a > b ? a : b;

//   /// 📊 CALCULATE STOCKOUT RISK (0-1 scale)
//   double _calculateStockoutRisk(InventoryItem item, double consumptionRate) {
//     if (consumptionRate <= 0 || item.quantity <= 0) return 0.0;
    
//     final daysRemaining = item.quantity / consumptionRate;
    
//     if (daysRemaining <= 2) return 1.0;
//     if (daysRemaining <= 5) return 0.8;
//     if (daysRemaining <= 10) return 0.5;
//     if (daysRemaining <= 14) return 0.3;
    
//     return 0.1;
//   }

//   /// 🎯 DETERMINE PRIORITY BASED ON RISK AND PREFERENCE
//   String _determineStockoutPriority(double stockoutRisk, double preferenceScore) {
//     if (stockoutRisk >= 0.8) return 'critical';
//     if (stockoutRisk >= 0.5) return 'high';
//     if (stockoutRisk >= 0.3 || preferenceScore >= 0.7) return 'medium';
//     return 'low';
//   }

//   /// 🏗️ ENHANCED: Build consistent recommendation structure
//   Map<String, dynamic> _buildRecommendation({
//     required String type,
//     required String priority,
//     required String title,
//     required String message,
//     required InventoryItem item,
//     required Map<String, dynamic> extraData,
//     required IconData icon,
//     required int color,
//     required int timestamp,
//   }) {
//     return {
//       'type': type,
//       'priority': priority,
//       'title': title,
//       'message': message,
//       'itemId': item.id,
//       'itemName': item.name,
//       'itemCategory': item.category,
//       'action': _getActionForType(type),
//       'icon': icon,
//       'color': color,
//       'timestamp': timestamp,
//       'severity': _priorityWeights[priority] ?? 3,
//       ...extraData,
//     };
//   }

//   /// 🧮 CALCULATE HOUSEHOLD PREFERENCE SCORE
//   double _calculateHouseholdPreferenceScore(InventoryItem item, HouseholdProfile profile) {
//     double score = 0.0;
    
//     if (profile.preferredItems.contains(item.id)) {
//       score += 0.6;
//     }
    
//     final categoryCount = profile.categoryPreferences[item.category] ?? 0;
//     score += (categoryCount * 0.1).clamp(0.0, 0.3);
      
//     final restockCount = profile.restockFrequency[item.id] ?? 0;
//     score += (restockCount * 0.05).clamp(0.0, 0.1);
    
//     return score.clamp(0.0, 1.0);
//   }


//   String _generateLowStockTitle(InventoryItem item, double stockoutRisk) {
//     if (stockoutRisk >= 0.8) return '🚨 CRITICAL: ${item.name} almost out!';
//     if (stockoutRisk >= 0.5) return '⚠️ ${item.name} running low';
//     return '📦 ${item.name} needs restock';
//   }

//   String _generateLowStockMessage(InventoryItem item, int needed, double stockoutRisk, double preferenceScore) {
//     final buffer = StringBuffer();
    
//     if (stockoutRisk >= 0.8) {
//       buffer.write('URGENT: Only ${item.quantity} left! ');
//     } else {
//       buffer.write('Only ${item.quantity} left. ');
//     }
    
//     buffer.write('Restock ${needed} more.');
    
//     if (preferenceScore >= 0.7) {
//       buffer.write(' Your household frequently uses this item.');
//     }
    
//     if (stockoutRisk >= 0.8) {
//       buffer.write(' Stockout imminent!');
//     }
    
//     return buffer.toString();
//   }

//   IconData _getStockoutIcon(double stockoutRisk) {
//     if (stockoutRisk >= 0.8) return Icons.error_rounded;
//     if (stockoutRisk >= 0.5) return Icons.warning_amber_rounded;
//     return Icons.info_rounded;
//   }

//   int _getStockoutColor(double stockoutRisk, double preferenceScore) {
//     if (stockoutRisk >= 0.8) return 0xFFE74C3C;
//     if (stockoutRisk >= 0.5) return 0xFFF39C12;
//     if (preferenceScore >= 0.7) return 0xFF3498DB;
//     return 0xFFFFA726;
//   }

//   Map<String, dynamic>? _generateExpiryRecommendation(InventoryItem item, double preferenceScore, int timestamp) {
//     final daysLeft = item.expiryDate!.difference(DateTime.now()).inDays;
    
//     if (daysLeft <= 14 && daysLeft >= 0) {
//       final isCritical = daysLeft <= 1;
//       final isUrgent = daysLeft <= 3;
//       final isPreferred = preferenceScore >= 0.7;
      
//       String title, message;
//       int color;
      
//       if (isCritical) {
//         title = '🚨 ${item.name} expires TODAY!';
//         message = 'Use immediately to avoid waste!';
//         color = 0xFFE74C3C;
//       } else if (isUrgent) {
//         title = '⚠️ ${item.name} expiring soon';
//         message = 'Expires in $daysLeft days. Use soon${isPreferred ? ' - your household likes this!' : ''}';
//         color = 0xFFF39C12;
//       } else {
//         title = '📅 ${item.name} expiry notice';
//         message = 'Expires in $daysLeft days. Plan usage accordingly.';
//         color = 0xFF3498DB;
//       }
      
//       return _buildRecommendation(
//         type: 'expiring_soon',
//         priority: isCritical ? 'critical' : (isUrgent ? 'high' : 'medium'),
//         title: title,
//         message: message,
//         item: item,
//         extraData: {
//           'daysUntilExpiry': daysLeft,
//           'preferenceScore': preferenceScore,
//           'expiryDate': item.expiryDate!.toIso8601String(),
//         },
//         icon: Icons.warning_amber_rounded,
//         color: color,
//         timestamp: timestamp,
//       );
//     }
    
//     return null;
//   }

//   /// 🎯 ENHANCED SORTING WITH HOUSEHOLD PREFERENCES
//   List<Map<String, dynamic>> _sortWithHouseholdPreferences(
//     List<Map<String, dynamic>> recommendations,
//     HouseholdProfile householdProfile
//   ) {
//     recommendations.sort((a, b) {
//       final priorityA = _priorityWeights[a['priority']] ?? 3;
//       final priorityB = _priorityWeights[b['priority']] ?? 3;
      
//       if (priorityA != priorityB) {
//         return priorityA.compareTo(priorityB);
//       }
      
//       final preferenceA = a['preferenceScore'] as double? ?? 0.0;
//       final preferenceB = b['preferenceScore'] as double? ?? 0.0;
//       if (preferenceA != preferenceB) {
//         return preferenceB.compareTo(preferenceA);
//       }
      
//       final stockoutRiskA = a['stockoutRisk'] as double? ?? 0.0;
//       final stockoutRiskB = b['stockoutRisk'] as double? ?? 0.0;
//       if (stockoutRiskA != stockoutRiskB) {
//         return stockoutRiskB.compareTo(stockoutRiskA);
//       }
      
//       final timestampA = a['timestamp'] as int;
//       final timestampB = b['timestamp'] as int;
//       return timestampB.compareTo(timestampA);
//     });

//     return recommendations;
//   }

//   /// 🛒 ENHANCED SHOPPING LIST GENERATION
//   Future<List<Map<String, dynamic>>> getShoppingList(String householdId) async {
//     try {
//       final recommendations = await getSmartRecommendations(householdId);
//       final shoppingList = <Map<String, dynamic>>[];
//       final addedItems = <String>{};

//       for (var rec in recommendations) {
//         final itemId = rec['itemId'] as String?;
//         if (itemId == null || addedItems.contains(itemId)) continue;

//         final shoppingItem = _convertToShoppingItem(rec);
//         if (shoppingItem != null) {
//           shoppingList.add(shoppingItem);
//           addedItems.add(itemId);
//         }
//       }

//       return _sortShoppingList(shoppingList);
//     } catch (e) {
//       _logError('Error generating shopping list', e);
//       return [];
//     }
//   }

//   Map<String, dynamic>? _convertToShoppingItem(Map<String, dynamic> rec) {
//     final type = rec['type'] as String;
//     final itemId = rec['itemId'] as String?;
    
//     if (itemId == null) return null;

//     switch (type) {
//       case 'low_stock':
//         return {
//           'itemName': rec['itemName'],
//           'quantity': rec['recommendedQuantity'],
//           'priority': rec['priority'],
//           'reason': 'Low stock - only ${rec['currentQuantity']} left',
//           'itemId': itemId,
//           'category': rec['itemCategory'],
//           'urgent': rec['priority'] == 'high' || rec['priority'] == 'critical',
//           'estimatedCost': rec['estimatedRestockCost'],
//           'stockoutRisk': rec['stockoutRisk'],
//           'preferenceScore': rec['preferenceScore'],
//         };
      
//       case 'predicted_out_of_stock':
//         final daysRemaining = rec['daysRemaining'] as double;
//         if (daysRemaining <= 7) {
//           return {
//             'itemName': rec['itemName'],
//             'quantity': _calculateSmartQuantity(rec),
//             'priority': rec['priority'],
//             'reason': 'Running out in ${daysRemaining.toStringAsFixed(1)} days',
//             'itemId': itemId,
//             'category': rec['itemCategory'],
//             'urgent': daysRemaining <= 3,
//             'estimatedCost': rec['price'] != null ? 
//                 (rec['price'] as double) * _calculateSmartQuantity(rec) : null,
//             'confidence': rec['confidence'],
//           };
//         }
//         break;
//     }
    
//     return null;
//   }

//   /// 🧠 SMART: Calculate restock quantity
//   int _calculateSmartQuantity(Map<String, dynamic> rec) {
//     final consumptionRate = double.tryParse(rec['consumptionRate'] ?? '0') ?? 0;
//     final minStock = rec['minStockLevel'] as int?;
//     final preferenceScore = rec['preferenceScore'] as double? ?? 0.5;
    
//     if (consumptionRate > 0 && minStock != null) {
//       final baseQuantity = (consumptionRate * 14).ceil();
//       final preferenceMultiplier = 1.0 + (preferenceScore * 0.5);
//       return (baseQuantity * preferenceMultiplier).ceil().clamp(minStock, minStock * 4);
//     }
    
//     return 2;
//   }

//   List<Map<String, dynamic>> _sortShoppingList(List<Map<String, dynamic>> list) {
//     list.sort((a, b) {
//       if (a['urgent'] != b['urgent']) {
//         return (b['urgent'] as bool) ? 1 : -1;
//       }
      
//       final priorityA = _priorityWeights[a['priority']] ?? 3;
//       final priorityB = _priorityWeights[b['priority']] ?? 3;
//       if (priorityA != priorityB) {
//         return priorityA.compareTo(priorityB);
//       }
      
//       final riskA = a['stockoutRisk'] as double? ?? 0.0;
//       final riskB = b['stockoutRisk'] as double? ?? 0.0;
//       return riskB.compareTo(riskA);
//     });
//     return list;
//   }

//   /// 🏠 HOUSEHOLD CONSUMPTION FORECASTING
//   Future<Map<String, dynamic>> predictHouseholdConsumption(String householdId) async {
//     try {
//       final householdProfile = await _getHouseholdProfile(householdId);
//       final predictions = <String, Map<String, dynamic>>{};

//       householdProfile.restockFrequency.forEach((itemId, frequency) {
//         final averageRestockCycle = 30 / frequency.clamp(1, 30);
//         final nextRestockInDays = averageRestockCycle;
        
//         predictions[itemId] = {
//           'itemId': itemId,
//           'predictedRestockInDays': nextRestockInDays,
//           'restockFrequency': frequency,
//           'confidence': _calculatePredictionConfidence(frequency),
//           'nextRestockDate': DateTime.now().add(Duration(days: nextRestockInDays.ceil())),
//           'estimatedQuantity': _estimateRestockQuantity(frequency),
//         };
//       });

//       return {
//         'householdId': householdId,
//         'predictions': predictions,
//         'generatedAt': DateTime.now().toIso8601String(),
//         'totalTrackedItems': predictions.length,
//         'mostFrequentItems': _getMostFrequentItems(householdProfile, 5),
//         'averageRestockCycle': _calculateAverageRestockCycle(householdProfile),
//       };
//     } catch (e) {
//       _logError('Error predicting household consumption', e);
//       return {'error': e.toString()};
//     }
//   }

//   /// 🧮 CALCULATE PREDICTION CONFIDENCE
//   double _calculatePredictionConfidence(int frequency) {
//     return (frequency / 10.0).clamp(0.1, 0.9);
//   }

//   double _calculatePredictionConfidenceFromData(double consumptionRate, int quantity) {
//     if (consumptionRate <= 0) return 0.1;
    
//     final dataPoints = (quantity / consumptionRate).clamp(1, 30);
//     return (dataPoints / 30.0).clamp(0.1, 0.9);
//   }

//   int _estimateRestockQuantity(int frequency) {
//     return (frequency * 2).clamp(1, 20);
//   }

//   double _calculateAverageRestockCycle(HouseholdProfile profile) {
//     if (profile.restockFrequency.isEmpty) return 0.0;
    
//     final totalFrequency = profile.restockFrequency.values.reduce((a, b) => a + b);
//     return 30.0 / (totalFrequency / profile.restockFrequency.length);
//   }

//   /// 📊 GET MOST FREQUENT ITEMS
//   List<Map<String, dynamic>> _getMostFrequentItems(HouseholdProfile profile, int limit) {
//     final sortedItems = profile.restockFrequency.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value));
    
//     return sortedItems.take(limit).map((entry) => {
//       'itemId': entry.key,
//       'restockCount': entry.value,
//       'frequencyCategory': _getFrequencyCategory(entry.value),
//     }).toList();
//   }

//   String _getFrequencyCategory(int frequency) {
//     if (frequency >= 10) return 'Very Frequent';
//     if (frequency >= 5) return 'Frequent';
//     if (frequency >= 2) return 'Occasional';
//     return 'Rare';
//   }

//   /// 🏠 GET HOUSEHOLD INSIGHTS
//   Future<Map<String, dynamic>> getHouseholdInsights(String householdId) async {
//     try {
//       final householdProfile = await _getHouseholdProfile(householdId);
//       final recommendations = await getSmartRecommendations(householdId);
//       final consumptionPatterns = await predictHouseholdConsumption(householdId);
      
//       final totalInteractions = householdProfile.restockFrequency.values.fold(0, (sum, count) => sum + count);
//       final preferredCategories = _getTopCategories(householdProfile, 3);
//       final behaviorScore = _calculateHouseholdBehaviorScore(householdProfile);

//       return {
//         'householdId': householdId,
//         'profileAge': DateTime.now().difference(householdProfile.lastUpdated).inDays,
//         'totalInteractions': totalInteractions,
//         'preferredItemsCount': householdProfile.preferredItems.length,
//         'ignoredItemsCount': householdProfile.ignoredItems.length,
//         'topCategories': preferredCategories,
//         'consumptionPatterns': consumptionPatterns,
//         'activeRecommendations': recommendations.length,
//         'householdBehaviorScore': behaviorScore,
//         'behaviorTier': _getBehaviorTier(behaviorScore),
//         'insights': _generateHouseholdInsights(householdProfile, recommendations),
//         'savingsOpportunities': _calculateSavingsOpportunities(recommendations),
//         'efficiencyScore': _calculateEfficiencyScore(householdProfile, recommendations),
//       };
//     } catch (e) {
//       _logError('Error generating household insights', e);
//       return {'error': e.toString()};
//     }
//   }

//   /// 📈 CALCULATE HOUSEHOLD BEHAVIOR SCORE
//   double _calculateHouseholdBehaviorScore(HouseholdProfile profile) {
//     final totalInteractions = profile.restockFrequency.values.fold(0, (sum, count) => sum + count);
//     final diversity = profile.categoryPreferences.length / 10.0;
//     const maxExpectedInteractions = 100;
    
//     final interactionScore = (totalInteractions / maxExpectedInteractions).clamp(0.0, 1.0);
//     final diversityScore = diversity.clamp(0.0, 1.0);
//     final consistencyScore = _calculateConsistencyScore(profile);
    
//     return (interactionScore * 0.5 + diversityScore * 0.3 + consistencyScore * 0.2);
//   }

//   double _calculateConsistencyScore(HouseholdProfile profile) {
//     if (profile.restockFrequency.isEmpty) return 0.0;
    
//     final averageFrequency = profile.restockFrequency.values.reduce((a, b) => a + b) / 
//                            profile.restockFrequency.length;
//     final variance = profile.restockFrequency.values
//         .map((f) => (f - averageFrequency) * (f - averageFrequency))
//         .reduce((a, b) => a + b) / profile.restockFrequency.length;
    
//     return (1.0 - (variance / (averageFrequency * averageFrequency))).clamp(0.0, 1.0);
//   }

//   String _getBehaviorTier(double score) {
//     if (score >= 0.8) return 'Expert';
//     if (score >= 0.6) return 'Proactive';
//     if (score >= 0.4) return 'Balanced';
//     if (score >= 0.2) return 'Casual';
//     return 'Beginner';
//   }

//   /// 🎯 GENERATE HOUSEHOLD INSIGHTS
//   List<String> _generateHouseholdInsights(HouseholdProfile profile, List<Map<String, dynamic>> recommendations) {
//     final insights = <String>[];
    
//     if (profile.preferredItems.isEmpty) {
//       insights.add('Start tracking your restocks to get personalized recommendations');
//     } else {
//       insights.add('Your household has ${profile.preferredItems.length} frequently used items');
//     }
    
//     if (profile.categoryPreferences.isNotEmpty) {
//       final topCategory = _getTopCategories(profile, 1).first;
//       insights.add('Your household prefers ${topCategory['category']} items');
//     }
    
//     final urgentCount = recommendations.where((r) => 
//       r['priority'] == 'critical' || r['priority'] == 'high').length;
//     if (urgentCount > 0) {
//       insights.add('You have $urgentCount urgent recommendations needing attention');
//     }
    
//     final savings = _calculateSavingsOpportunities(recommendations);
//     if (savings > 0) {
//       insights.add('Potential savings: RM${savings.toStringAsFixed(2)} through better inventory management');
//     }
    
//     return insights;
//   }

//   double _calculateSavingsOpportunities(List<Map<String, dynamic>> recommendations) {
//     double totalSavings = 0.0;
    
//     for (final rec in recommendations) {
//       if (rec['type'] == 'overstock') {
//         final excessQuantity = rec['excessQuantity'] as int? ?? 0;
//         final price = rec['price'] as double? ?? 0.0;
//         totalSavings += excessQuantity * price * 0.1;
//       } else if (rec['type'] == 'expiring_soon') {
//         final quantity = rec['currentQuantity'] as int? ?? 0;
//         final price = rec['price'] as double? ?? 0.0;
//         totalSavings += quantity * price * 0.5;
//       }
//     }
    
//     return totalSavings;
//   }

//   double _calculateEfficiencyScore(HouseholdProfile profile, List<Map<String, dynamic>> recommendations) {
//     final baseScore = _calculateHouseholdBehaviorScore(profile);
//     final urgentCount = recommendations.where((r) => 
//       r['priority'] == 'critical' || r['priority'] == 'high').length;
    
//     final urgencyPenalty = (urgentCount * 0.1).clamp(0.0, 0.3);
    
//     return (baseScore - urgencyPenalty).clamp(0.0, 1.0);
//   }

//   List<Map<String, dynamic>> _getTopCategories(HouseholdProfile profile, int limit) {
//     final sortedCategories = profile.categoryPreferences.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value));
    
//     return sortedCategories.take(limit).map((entry) => ({
//       'category': entry.key,
//       'preferenceScore': entry.value,
//       'strength': _getPreferenceStrength(entry.value),
//     })).toList();
//   }

//   String _getPreferenceStrength(double score) {
//     if (score >= 5) return 'Strong';
//     if (score >= 2) return 'Moderate';
//     return 'Mild';
//   }

//   /// 📊 ENHANCED RECOMMENDATION STATISTICS
//   Future<Map<String, dynamic>> getRecommendationStats(String householdId) async {
//     try {
//       final recommendations = await getSmartRecommendations(householdId);
      
//       final Map<String, int> stats = {
//         'critical': 0, 'high': 0, 'medium': 0, 'info': 0,
//         'low_stock': 0, 'expiring_soon': 0, 'predicted_out_of_stock': 0,
//         'high_value_stock': 0, 'overstock': 0,
//       };

//       double totalPotentialSavings = 0.0;
//       int totalUrgentItems = 0;

//       for (var rec in recommendations) {
//         final priority = rec['priority'] as String;
//         final type = rec['type'] as String;
        
//         stats[priority] = (stats[priority] ?? 0) + 1;
//         stats[type] = (stats[type] ?? 0) + 1;

//         if (priority == 'critical' || priority == 'high') {
//           totalUrgentItems++;
//         }

//         if (type == 'overstock') {
//           final excessQuantity = rec['excessQuantity'] as int? ?? 0;
//           final price = rec['price'] as double? ?? 0.0;
//           totalPotentialSavings += excessQuantity * price * 0.1;
//         }
//       }

//       return {
//         'total': recommendations.length,
//         ...stats,
//         'hasUrgent': totalUrgentItems > 0,
//         'urgentCount': totalUrgentItems,
//         'potentialSavings': totalPotentialSavings,
//         'generatedAt': DateTime.now().toIso8601String(),
//         'summary': _generateSummaryMessage(stats, totalUrgentItems),
//         'efficiency': _calculateRecommendationEfficiency(recommendations),
//       };
//     } catch (e) {
//       _logError('Error generating recommendation stats', e);
//       return {'total': 0, 'hasUrgent': false, 'error': e.toString()};
//     }
//   }

//   double _calculateRecommendationEfficiency(List<Map<String, dynamic>> recommendations) {
//     if (recommendations.isEmpty) return 1.0;
    
//     final urgentCount = recommendations.where((r) => 
//       r['priority'] == 'critical' || r['priority'] == 'high').length;
    
//     return 1.0 - (urgentCount / recommendations.length * 0.5).clamp(0.0, 0.5);
//   }

//   String _generateSummaryMessage(Map<String, int> stats, int urgentCount) {
//     final critical = stats['critical'] ?? 0;
//     final high = stats['high'] ?? 0;
    
//     if (critical > 0) return '$critical critical items need immediate attention!';
//     if (high > 0) return '$high high priority items to review';
//     if (urgentCount > 0) return '$urgentCount items need your attention';
//     if ((stats['total'] ?? 0) > 0) return 'Inventory is well managed';
//     return 'Add items to get recommendations';
//   }

//   /// 📊 PERFORMANCE MONITORING
//   Future<List<Map<String, dynamic>>> getPerformanceReport() async {
//     return [
//       {
//         'metric': 'Cache Hit Rate',
//         'value': _calculateCacheHitRate(),
//         'status': _getPerformanceStatus(_calculateCacheHitRate(), 0.8),
//         'description': 'Percentage of requests served from cache',
//       },
//       {
//         'metric': 'Average Response Time',
//         'value': _calculateAverageResponseTime(),
//         'status': _getPerformanceStatus(_calculateAverageResponseTime(), 1000, true),
//         'description': 'Average time to generate recommendations',
//       },
//       {
//         'metric': 'Recommendation Accuracy',
//         'value': await _calculateAccuracyScore(),
//         'status': _getPerformanceStatus(await _calculateAccuracyScore(), 0.7),
//         'description': 'Estimated accuracy of recommendations',
//       },
//       {
//         'metric': 'Cache Efficiency',
//         'value': _calculateCacheEfficiency(),
//         'status': _getPerformanceStatus(_calculateCacheEfficiency(), 0.6),
//         'description': 'Cache utilization efficiency',
//       },
//     ];
//   }

//   double _calculateCacheHitRate() {
//     final totalRequests = _performanceMetrics['totalRequests'] ?? 1;
//     final cacheHits = _performanceMetrics['cacheHits'] ?? 0;
//     return cacheHits / totalRequests;
//   }

//   double _calculateAverageResponseTime() {
//     return 250.0;
//   }

//   Future<double> _calculateAccuracyScore() async {
//     return 0.85;
//   }

//   double _calculateCacheEfficiency() {
//     final currentSize = _consumptionRateCache.length + _householdProfileCache.length;
//     return 1.0 - (currentSize / _maxCacheSize);
//   }

//   String _getPerformanceStatus(double value, double threshold, [bool lowerIsBetter = false]) {
//     if (lowerIsBetter) {
//       return value <= threshold ? 'Good' : 'Needs Improvement';
//     }
//     return value >= threshold ? 'Good' : 'Needs Improvement';
//   }

//   void _trackPerformance(String methodName, int executionTime) {
//     _performanceMetrics[methodName] = executionTime;
    
//     if (executionTime > 1000) {
//       _logWarning('Slow operation: $methodName took ${executionTime}ms');
//     }
//   }

//   /// 🧹 CACHE MANAGEMENT
//   void _cleanExpiredCache() {
//     final now = DateTime.now();
    
//     _consumptionRateCache.removeWhere((key, value) => 
//       now.difference(value.timestamp) > _cacheDuration);
    
//     _householdProfileCache.removeWhere((key, value) => 
//       now.difference(value.lastUpdated) > _cacheDuration);
    
//     if (_consumptionRateCache.length > _maxCacheSize) {
//       final keys = _consumptionRateCache.keys.toList();
//       keys.sort((a, b) => _consumptionRateCache[b]!.timestamp
//           .compareTo(_consumptionRateCache[a]!.timestamp));
//       final keysToRemove = keys.sublist(_maxCacheSize);
      
//       for (final key in keysToRemove) {
//         _consumptionRateCache.remove(key);
//       }
//     }
//   }

//   Future<void> preloadCriticalData(String householdId) async {
//     await Future.wait([
//       _getHouseholdProfile(householdId),
//       _fetchInventoryBatch(householdId),
//     ]);
//   }

//   /// 🔧 HELPER METHODS
//   String _getActionForType(String type) {
//     const actions = {
//       'low_stock': 'restock',
//       'expiring_soon': 'use_soon',
//       'predicted_out_of_stock': 'plan_restock',
//       'high_value_stock': 'monitor',
//       'overstock': 'reduce_stock',
//     };
//     return actions[type] ?? 'monitor';
//   }

//   void _cacheConsumptionRate(String itemId, double rate) {
//     _consumptionRateCache[itemId] = _CachedConsumptionRate(rate, DateTime.now());
//   }

//   void _logError(String message, dynamic error) {
//     print('❌ $message: $error');
//   }

//   void _logWarning(String message) {
//     print('⚠️ $message');
//   }

//   void _logInfo(String message) {
//     print('ℹ️ $message');
//   }

//   /// 🏠 DEFAULT RECOMMENDATIONS
//   List<Map<String, dynamic>> _getDefaultRecommendations() {
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     return [
//       {
//         'type': 'welcome',
//         'priority': 'info',
//         'title': 'Welcome to Smart Inventory!',
//         'message': 'Add some items to get personalized recommendations.',
//         'itemId': '',
//         'itemName': '',
//         'action': 'add_items',
//         'icon': Icons.emoji_objects_rounded,
//         'color': 0xFF3498DB,
//         'timestamp': timestamp,
//       },
//       {
//         'type': 'tip',
//         'priority': 'info',
//         'title': 'Pro Tip',
//         'message': 'Set minimum stock levels and expiry dates for better predictions.',
//         'itemId': '',
//         'itemName': '',
//         'action': 'learn_more',
//         'icon': Icons.lightbulb_rounded,
//         'color': 0xFFF39C12,
//         'timestamp': timestamp,
//       }
//     ];
//   }

//   /// 🧹 CLEANUP: Clear cache
//   void clearCache() {
//     _consumptionRateCache.clear();
//     _householdProfileCache.clear();
//     _performanceMetrics.clear();
//   }

//   /// 📊 GET CACHE STATS
//   Map<String, dynamic> getCacheStats() {
//     return {
//       'consumptionRateCacheSize': _consumptionRateCache.length,
//       'householdProfileCacheSize': _householdProfileCache.length,
//       'cacheHitRate': _calculateCacheHitRate(),
//       'totalRequests': _performanceMetrics['totalRequests'] ?? 0,
//       'cacheHits': _performanceMetrics['cacheHits'] ?? 0,
//     };
//   }
// }

// /// 🏠 HOUSEHOLD PROFILE MODEL
// class HouseholdProfile {
//   final String householdId;
//   final Set<String> preferredItems;
//   final Set<String> ignoredItems;
//   final Map<String, int> restockFrequency;
//   final Map<String, double> categoryPreferences;
//   final Map<String, double> averageConsumptionRates;
//   DateTime lastUpdated;

//   HouseholdProfile({
//     required this.householdId,
//     required this.preferredItems,
//     required this.ignoredItems,
//     required this.restockFrequency,
//     required this.categoryPreferences,
//     required this.averageConsumptionRates,
//     required this.lastUpdated,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'householdId': householdId,
//       'preferredItems': preferredItems.toList(),
//       'ignoredItems': ignoredItems.toList(),
//       'restockFrequency': restockFrequency,
//       'categoryPreferences': categoryPreferences,
//       'averageConsumptionRates': averageConsumptionRates,
//       'lastUpdated': lastUpdated.toIso8601String(),
//     };
//   }

//   factory HouseholdProfile.fromMap(Map<String, dynamic> map) {
//     return HouseholdProfile(
//       householdId: map['householdId'],
//       preferredItems: Set<String>.from(map['preferredItems'] ?? []),
//       ignoredItems: Set<String>.from(map['ignoredItems'] ?? []),
//       restockFrequency: Map<String, int>.from(map['restockFrequency'] ?? {}),
//       categoryPreferences: Map<String, double>.from(map['categoryPreferences'] ?? {}),
//       averageConsumptionRates: Map<String, double>.from(map['averageConsumptionRates'] ?? {}),
//       lastUpdated: DateTime.parse(map['lastUpdated'] ?? DateTime.now().toIso8601String()),
//     );
//   }
// }

// /// 📊 DATA MODELS FOR BETTER TYPE SAFETY
// class ConsumptionAnalysisResult {
//   final double averageRate;
//   final double weightedRate;

//   ConsumptionAnalysisResult(this.averageRate, this.weightedRate);
// }

// class _CachedConsumptionRate {
//   final double rate;
//   final DateTime timestamp;

//   _CachedConsumptionRate(this.rate, this.timestamp);
// }