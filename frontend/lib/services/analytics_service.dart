// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:collection/collection.dart';
// import 'package:frontend/pages/inventory_item_model.dart';

// class AnalyticsService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   String? _getUserId() {
//     return _auth.currentUser?.uid;
//   }

//   // Get consumption trends
//   Future<Map<String, dynamic>> getConsumptionTrends(String householdId, {int days = 30}) async {
//     final endDate = DateTime.now();
//     final startDate = endDate.subtract(Duration(days: days));

//     try {
//       final snapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .get();

//       final trends = <String, List<Map<String, dynamic>>>{};
//       double totalValue = 0;
//       int totalItems = 0;
//       int lowStockItems = 0;

//       for (final doc in snapshot.docs) {
//         final data = doc.data();
//         final category = data['category'] as String? ?? 'Uncategorized';
        
//         // Calculate item value
//         final quantity = (data['quantity'] ?? 0).toDouble();
//         final price = (data['price'] ?? 0).toDouble();
//         final itemValue = quantity * price;
//         totalValue += itemValue;
//         totalItems++;

//         // Check if low stock
//         final minStock = (data['minStockLevel'] ?? 1).toDouble();
//         if (quantity < minStock) {
//           lowStockItems++;
//         }

//         // Initialize category if not exists
//         if (!trends.containsKey(category)) {
//           trends[category] = [];
//         }

//         trends[category]!.add({
//           'name': data['name'],
//           'quantity': quantity,
//           'value': itemValue,
//           'category': category,
//           'isLowStock': quantity < minStock,
//         });
//       }

//       // Calculate category distribution
//       final categoryDistribution = _calculateCategoryDistribution(trends);
//       final lowStockPercentage = totalItems > 0 ? (lowStockItems / totalItems) * 100 : 0;

//       return {
//         'totalValue': totalValue,
//         'totalItems': totalItems,
//         'lowStockItems': lowStockItems,
//         'lowStockPercentage': lowStockPercentage,
//         'categoryDistribution': categoryDistribution,
//         'itemsByCategory': trends,
//         'topConsumedItems': _getTopConsumedItems(trends),
//       };
//     } catch (e) {
//       print('Error getting consumption trends: $e');
//       return {};
//     }
//   }

//   Map<String, double> _calculateCategoryDistribution(Map<String, List<Map<String, dynamic>>> trends) {
//     final distribution = <String, double>{};
//     double totalValue = 0;

//     // Calculate total value across all categories
//     trends.forEach((category, items) {
//       final categoryValue = items.fold<double>(0, (sum, item) => sum + (item['value'] as double));
//       distribution[category] = categoryValue;
//       totalValue += categoryValue;
//     });

//     // Convert to percentages
//     if (totalValue > 0) {
//       distribution.forEach((category, value) {
//         distribution[category] = (value / totalValue) * 100;
//       });
//     }

//     return distribution;
//   }

//   List<Map<String, dynamic>> _getTopConsumedItems(Map<String, List<Map<String, dynamic>>> trends) {
//     final allItems = <Map<String, dynamic>>[];
//     trends.forEach((category, items) {
//       allItems.addAll(items);
//     });

//     // Sort by value (most valuable first)
//     allItems.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

//     return allItems.take(10).toList();
//   }

//   // Get monthly spending trends
//   Future<Map<String, double>> getMonthlySpending(String householdId, {int months = 6}) async {
//     final spending = <String, double>{};
//     final now = DateTime.now();

//     for (int i = 0; i < months; i++) {
//       final month = DateTime(now.year, now.month - i);
//       final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      
//       // This would require additional data collection for purchases
//       // For now, we'll return mock data or calculate from current inventory
//       spending[monthKey] = _calculateEstimatedMonthlySpending(householdId, month);
//     }

//     return spending;
//   }

//   double _calculateEstimatedMonthlySpending(String householdId, DateTime month) {
//     // This is a simplified calculation - in a real app, you'd track actual purchases
//     return 0.0;
//   }

//   // Get usage patterns for recommendations
//   Future<Map<String, dynamic>> getUsagePatterns(String householdId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .where('consumptionPattern', isNotEqualTo: null)
//           .get();

//       final patterns = <String, List<double>>{};
//       final recommendations = <String, dynamic>{};

//       for (final doc in snapshot.docs) {
//         final data = doc.data();
//         final patternData = data['consumptionPattern'] as Map<String, dynamic>;
//         final pattern = ConsumptionPattern.fromMap(patternData);

//         if (pattern.averageDailyUsage > 0) {
//           final category = data['category'] as String? ?? 'Uncategorized';
          
//           if (!patterns.containsKey(category)) {
//             patterns[category] = [];
//           }
          
//           patterns[category]!.add(pattern.averageDailyUsage);
//         }
//       }

//       // Generate category-level insights
//       patterns.forEach((category, usageRates) {
//         if (usageRates.isNotEmpty) {
//           final avgUsage = usageRates.average;
//           final maxUsage = usageRates.reduce((a, b) => a > b ? a : b);
//           final minUsage = usageRates.reduce((a, b) => a < b ? a : b);

//           recommendations[category] = {
//             'averageDailyUsage': avgUsage,
//             'maxUsage': maxUsage,
//             'minUsage': minUsage,
//             'volatility': (maxUsage - minUsage) / avgUsage,
//             'recommendation': _generateCategoryRecommendation(avgUsage, maxUsage - minUsage),
//           };
//         }
//       });

//       return {
//         'categoryPatterns': patterns,
//         'recommendations': recommendations,
//         'mostVolatileCategory': _findMostVolatileCategory(recommendations),
//         'mostStableCategory': _findMostStableCategory(recommendations),
//       };
//     } catch (e) {
//       print('Error getting usage patterns: $e');
//       return {};
//     }
//   }

//   String _generateCategoryRecommendation(double avgUsage, double range) {
//     if (range > avgUsage * 0.5) {
//       return 'High volatility - consider buying in smaller, more frequent quantities';
//     } else if (avgUsage > 10) {
//       return 'High usage - consider bulk purchases for cost savings';
//     } else {
//       return 'Stable usage pattern - maintain current purchasing habits';
//     }
//   }

//   String? _findMostVolatileCategory(Map<String, dynamic> recommendations) {
//     double maxVolatility = 0;
//     String? mostVolatile;

//     recommendations.forEach((category, data) {
//       final volatility = data['volatility'] as double;
//       if (volatility > maxVolatility) {
//         maxVolatility = volatility;
//         mostVolatile = category;
//       }
//     });

//     return mostVolatile;
//   }

//   String? _findMostStableCategory(Map<String, dynamic> recommendations) {
//     double minVolatility = double.infinity;
//     String? mostStable;

//     recommendations.forEach((category, data) {
//       final volatility = data['volatility'] as double;
//       if (volatility < minVolatility) {
//         minVolatility = volatility;
//         mostStable = category;
//       }
//     });

//     return mostStable;
//   }
// }