// import 'dart:math';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../pages/inventory_item_model.dart' show InventoryItem;

// // Separate Random Forest implementation
// class RandomForest {
//   final int numTrees;
//   final int maxDepth;
//   final int minSamplesSplit;
//   final Random _random;

//   RandomForest({
//     this.numTrees = 10,
//     this.maxDepth = 5,
//     this.minSamplesSplit = 2,
//   }) : _random = Random();

//   class TreeNode {
//     int? featureIndex;
//     double? threshold;
//     double? value;
//     TreeNode? left;
//     TreeNode? right;
//     bool isLeaf = false;
//   }

//   List<TreeNode> _trees = [];

//   // Train the Random Forest
//   void train(List<List<double>> X, List<double> y) {
//     _trees = [];
//     for (int i = 0; i < numTrees; i++) {
//       // Create bootstrap sample
//       final List<List<double>> XSample = [];
//       final List<double> ySample = [];
//       final int n = X.length;
      
//       for (int j = 0; j < n; j++) {
//         final int idx = _random.nextInt(n);
//         XSample.add(X[idx]);
//         ySample.add(y[idx]);
//       }
      
//       final TreeNode tree = _buildTree(XSample, ySample, depth: 0);
//       _trees.add(tree);
//     }
//   }

//   // Predict using the Random Forest
//   double predict(List<double> features) {
//     final List<double> predictions = [];
//     for (final tree in _trees) {
//       predictions.add(_predictTree(tree, features));
//     }
    
//     // Return average prediction
//     return predictions.reduce((a, b) => a + b) / predictions.length;
//   }

//   TreeNode _buildTree(List<List<double>> X, List<double> y, {int depth = 0}) {
//     final TreeNode node = TreeNode();
    
//     // Stop conditions
//     if (depth >= maxDepth || X.length <= minSamplesSplit || _isPure(y)) {
//       node.isLeaf = true;
//       node.value = _calculateMean(y);
//       return node;
//     }

//     // Find best split
//     final Map<String, dynamic>? bestSplit = _findBestSplit(X, y);
//     if (bestSplit == null) {
//       node.isLeaf = true;
//       node.value = _calculateMean(y);
//       return node;
//     }

//     node.featureIndex = bestSplit['feature_index'];
//     node.threshold = bestSplit['threshold'];

//     // Split data
//     final List<List<double>> leftX = [];
//     final List<double> leftY = [];
//     final List<List<double>> rightX = [];
//     final List<double> rightY = [];

//     for (int i = 0; i < X.length; i++) {
//       if (X[i][node.featureIndex!] <= node.threshold!) {
//         leftX.add(X[i]);
//         leftY.add(y[i]);
//       } else {
//         rightX.add(X[i]);
//         rightY.add(y[i]);
//       }
//     }

//     // Recursively build children
//     node.left = _buildTree(leftX, leftY, depth: depth + 1);
//     node.right = _buildTree(rightX, rightY, depth: depth + 1);

//     return node;
//   }

//   Map<String, dynamic>? _findBestSplit(List<List<double>> X, List<double> y) {
//     final int nFeatures = X[0].length;
//     double bestVariance = double.infinity;
//     int bestFeature = -1;
//     double bestThreshold = 0;

//     // Try random subset of features
//     final int numFeaturesToTry = max(1, (sqrt(nFeatures)).round());
//     final Set<int> featureIndices = {};
    
//     while (featureIndices.length < numFeaturesToTry) {
//       featureIndices.add(_random.nextInt(nFeatures));
//     }

//     for (final featureIndex in featureIndices) {
//       // Get unique thresholds from this feature
//       final Set<double> thresholds = {};
//       for (final sample in X) {
//         thresholds.add(sample[featureIndex]);
//       }

//       for (final threshold in thresholds) {
//         final List<double> leftY = [];
//         final List<double> rightY = [];

//         for (int i = 0; i < X.length; i++) {
//           if (X[i][featureIndex] <= threshold) {
//             leftY.add(y[i]);
//           } else {
//             rightY.add(y[i]);
//           }
//         }

//         if (leftY.isEmpty || rightY.isEmpty) continue;

//         final double variance = _calculateWeightedVariance(leftY, rightY);
        
//         if (variance < bestVariance) {
//           bestVariance = variance;
//           bestFeature = featureIndex;
//           bestThreshold = threshold;
//         }
//       }
//     }

//     if (bestFeature == -1) return null;

//     return {
//       'feature_index': bestFeature,
//       'threshold': bestThreshold,
//       'variance': bestVariance,
//     };
//   }

//   double _predictTree(TreeNode node, List<double> features) {
//     if (node.isLeaf) {
//       return node.value!;
//     }

//     if (features[node.featureIndex!] <= node.threshold!) {
//       return _predictTree(node.left!, features);
//     } else {
//       return _predictTree(node.right!, features);
//     }
//   }

//   bool _isPure(List<double> y) {
//     if (y.length <= 1) return true;
//     final first = y[0];
//     for (int i = 1; i < y.length; i++) {
//       if (y[i] != first) return false;
//     }
//     return true;
//   }

//   double _calculateMean(List<double> y) {
//     return y.reduce((a, b) => a + b) / y.length;
//   }

//   double _calculateWeightedVariance(List<double> leftY, List<double> rightY) {
//     final double leftVar = _calculateVariance(leftY);
//     final double rightVar = _calculateVariance(rightY);
//     final int n = leftY.length + rightY.length;
    
//     return (leftY.length * leftVar + rightY.length * rightVar) / n;
//   }

//   double _calculateVariance(List<double> y) {
//     if (y.isEmpty) return 0;
//     final double mean = _calculateMean(y);
//     double sum = 0;
//     for (final value in y) {
//       sum += pow(value - mean, 2);
//     }
//     return sum / y.length;
//   }
// }

// class MLInventoryService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Enhanced AI Suggestions with ML
//   Future<List<InventoryItem>> getAISuggestions(String householdId) async {
//     try {
//       // Get historical data for ML training
//       final inventorySnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .get();

//       final auditLogsSnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory_audit_logs')
//           .orderBy('timestamp', descending: true)
//           .limit(1000)
//           .get();

//       // Prepare training data
//       final List<List<double>> X = []; // Features
//       final List<double> y = [];       // Targets (days until restock needed)

//       // Extract features from items and audit logs
//       for (final doc in inventorySnapshot.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final features = await _extractFeatures(data, auditLogsSnapshot.docs, doc.id);
//         if (features != null) {
//           X.add(features['features']);
//           y.add(features['target']);
//         }
//       }

//       if (X.isEmpty) {
//         // Fallback to simple rule-based approach
//         return _getFallbackSuggestions(inventorySnapshot);
//       }

//       // Train Random Forest model
//       final randomForest = RandomForest(numTrees: 20, maxDepth: 6);
//       randomForest.train(X, y);

//       // Predict for all items
//       final List<Map<String, dynamic>> predictions = [];
//       for (final doc in inventorySnapshot.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final features = await _extractFeatures(data, auditLogsSnapshot.docs, doc.id);
//         if (features != null) {
//           final prediction = randomForest.predict(features['features']);
//           predictions.add({
//             'item': InventoryItem.fromMap(data, doc.id),
//             'urgency_score': prediction,
//             'predicted_days_until_restock': prediction,
//           });
//         }
//       }

//       // Sort by urgency (lower score = more urgent)
//       predictions.sort((a, b) => a['urgency_score'].compareTo(b['urgency_score']));

//       // Return top 10 most urgent items
//       return predictions
//           .take(10)
//           .map((pred) => pred['item'] as InventoryItem)
//           .toList();

//     } catch (e) {
//       print('Error in ML suggestions: $e');
//       // Fallback to simple approach
//       return _getFallbackSuggestionsFromFirestore(householdId);
//     }
//   }

//   Future<Map<String, dynamic>?> _extractFeatures(
//     Map<String, dynamic> itemData,
//     List<QueryDocumentSnapshot> auditLogs,
//     String itemId,
//   ) async {
//     try {
//       final quantity = (itemData['quantity'] ?? 0).toDouble();
//       final price = (itemData['price'] ?? 0.0).toDouble();
//       final category = itemData['category'] ?? 'Uncategorized';
      
//       // Calculate usage rate from audit logs
//       final itemLogs = auditLogs.where((log) {
//         final logData = log.data() as Map<String, dynamic>;
//         return logData['itemId'] == itemId && logData['fieldName'] == 'quantity';
//       }).toList();

//       double usageRate = 1.0; // Default
//       if (itemLogs.length >= 2) {
//         final recentChange = (itemLogs[0]['newValue'] ?? 0).toDouble() - 
//                            (itemLogs[0]['oldValue'] ?? 0).toDouble();
//         final timeDiff = _calculateTimeDifference(
//           (itemLogs[0]['timestamp'] as Timestamp).toDate(),
//           (itemLogs[1]['timestamp'] as Timestamp).toDate(),
//         );
//         usageRate = recentChange.abs() / max(timeDiff, 1);
//       }

//       // Feature vector
//       final List<double> features = [
//         quantity,
//         price,
//         _encodeCategory(category),
//         usageRate,
//         _isPerishable(category) ? 1.0 : 0.0,
//         _getSeasonalFactor(),
//       ];

//       // Target: days until restock needed (simplified)
//       final double target = max(1.0, quantity / max(usageRate, 0.1));

//       return {
//         'features': features,
//         'target': target,
//       };
//     } catch (e) {
//       print('Error extracting features: $e');
//       return null;
//     }
//   }

//   double _encodeCategory(String category) {
//     // Simple category encoding
//     const categoryWeights = {
//       'Dairy': 0.8,
//       'Produce': 0.9,
//       'Meat': 0.7,
//       'Bakery': 0.6,
//       'Beverages': 0.4,
//       'Canned Goods': 0.2,
//       'Frozen': 0.3,
//       'Cleaning': 0.1,
//       'Personal Care': 0.2,
//     };
//     return categoryWeights[category] ?? 0.5;
//   }

//   bool _isPerishable(String category) {
//     final perishableCategories = {'Dairy', 'Produce', 'Meat', 'Bakery'};
//     return perishableCategories.contains(category);
//   }

//   double _getSeasonalFactor() {
//     final month = DateTime.now().month;
//     // Simple seasonal adjustment (higher in winter months)
//     return month >= 11 || month <= 2 ? 1.2 : 1.0;
//   }

//   double _calculateTimeDifference(DateTime date1, DateTime date2) {
//     return date1.difference(date2).inDays.toDouble();
//   }

//   List<InventoryItem> _getFallbackSuggestions(QuerySnapshot snapshot) {
//     return snapshot.docs.map((doc) {
//       return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
//     }).where((item) => item.quantity < 3).toList();
//   }

//   Future<List<InventoryItem>> _getFallbackSuggestionsFromFirestore(String householdId) async {
//     try {
//       final snapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .where('quantity', isLessThan: 3)
//           .get();

//       return snapshot.docs.map((doc) {
//         return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
//       }).toList();
//     } catch (e) {
//       print('Error in fallback suggestions: $e');
//       return [];
//     }
//   }

//   // Consumption pattern analysis
//   Future<Map<String, dynamic>> analyzeConsumptionPatterns(String householdId) async {
//     try {
//       final auditLogsSnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory_audit_logs')
//           .orderBy('timestamp', descending: false)
//           .get();

//       final Map<String, List<Map<String, dynamic>>> itemPatterns = {};

//       for (final doc in auditLogsSnapshot.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         if (data['fieldName'] == 'quantity') {
//           final itemId = data['itemId'];
//           final pattern = {
//             'timestamp': (data['timestamp'] as Timestamp).toDate(),
//             'oldValue': data['oldValue'],
//             'newValue': data['newValue'],
//             'change': (data['newValue'] ?? 0).toDouble() - (data['oldValue'] ?? 0).toDouble(),
//           };

//           itemPatterns.putIfAbsent(itemId, () => []).add(pattern);
//         }
//       }

//       // Calculate consumption rates
//       final Map<String, double> consumptionRates = {};
//       for (final entry in itemPatterns.entries) {
//         final patterns = entry.value;
//         if (patterns.length >= 2) {
//           double totalChange = 0;
//           double totalDays = 0;

//           for (int i = 1; i < patterns.length; i++) {
//             final change = patterns[i]['change'] as double;
//             final timeDiff = patterns[i]['timestamp'].difference(patterns[i-1]['timestamp']).inDays;
            
//             if (timeDiff > 0) {
//               totalChange += change.abs();
//               totalDays += timeDiff;
//             }
//           }

//           if (totalDays > 0) {
//             consumptionRates[entry.key] = totalChange / totalDays;
//           }
//         }
//       }

//       return {
//         'consumptionRates': consumptionRates,
//         'totalItemsAnalyzed': itemPatterns.length,
//       };
//     } catch (e) {
//       print('Error analyzing consumption patterns: $e');
//       return {'consumptionRates': {}, 'totalItemsAnalyzed': 0};
//     }
//   }

//   // Get inventory health score
//   Future<Map<String, dynamic>> getInventoryHealth(String householdId) async {
//     try {
//       final inventorySnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .get();

//       final stats = await _calculateInventoryStats(inventorySnapshot);
//       final suggestions = await getAISuggestions(householdId);
      
//       return {
//         'healthScore': _calculateHealthScore(stats),
//         'totalItems': stats['totalItems'],
//         'lowStockItems': stats['lowStockItems'],
//         'expiringSoon': stats['expiringSoon'],
//         'totalValue': stats['totalValue'],
//         'aiSuggestions': suggestions.length,
//         'recommendations': _generateRecommendations(stats, suggestions),
//       };
//     } catch (e) {
//       print('Error calculating inventory health: $e');
//       return {
//         'healthScore': 0,
//         'totalItems': 0,
//         'lowStockItems': 0,
//         'expiringSoon': 0,
//         'totalValue': 0.0,
//         'aiSuggestions': 0,
//         'recommendations': [],
//       };
//     }
//   }

//   Future<Map<String, dynamic>> _calculateInventoryStats(QuerySnapshot snapshot) async {
//     int totalItems = snapshot.docs.length;
//     int lowStockItems = 0;
//     int expiringSoon = 0;
//     double totalValue = 0.0;

//     final now = DateTime.now();
//     final weekFromNow = now.add(const Duration(days: 7));

//     for (final doc in snapshot.docs) {
//       final data = doc.data() as Map<String, dynamic>;
//       final quantity = (data['quantity'] ?? 0).toInt();
//       final price = (data['price'] ?? 0).toDouble();
//       final expiryDate = data['expiryDate'] as Timestamp?;

//       totalValue += quantity * price;

//       if (quantity < 5) {
//         lowStockItems++;
//       }

//       if (expiryDate != null) {
//         final expiry = expiryDate.toDate();
//         if (expiry.isAfter(now) && expiry.isBefore(weekFromNow)) {
//           expiringSoon++;
//         }
//       }
//     }

//     return {
//       'totalItems': totalItems,
//       'lowStockItems': lowStockItems,
//       'expiringSoon': expiringSoon,
//       'totalValue': totalValue,
//     };
//   }

//   double _calculateHealthScore(Map<String, dynamic> stats) {
//     final totalItems = stats['totalItems'] ?? 0;
//     final lowStockItems = stats['lowStockItems'] ?? 0;
//     final expiringSoon = stats['expiringSoon'] ?? 0;

//     if (totalItems == 0) return 100.0; // Empty inventory is "healthy" in a way

//     final lowStockRatio = lowStockItems / totalItems;
//     final expiringRatio = expiringSoon / totalItems;

//     // Score out of 100
//     double score = 100.0;
//     score -= (lowStockRatio * 50); // Up to 50 points deduction for low stock
//     score -= (expiringRatio * 30); // Up to 30 points deduction for expiring items

//     return max(0.0, score);
//   }

//   List<String> _generateRecommendations(Map<String, dynamic> stats, List<InventoryItem> suggestions) {
//     final List<String> recommendations = [];
//     final lowStockItems = stats['lowStockItems'] ?? 0;
//     final expiringSoon = stats['expiringSoon'] ?? 0;

//     if (lowStockItems > 5) {
//       recommendations.add('Consider bulk purchasing for frequently used items to save costs');
//     }

//     if (expiringSoon > 3) {
//       recommendations.add('Plan meals around expiring items to reduce waste');
//     }

//     if (suggestions.isNotEmpty) {
//       recommendations.add('Restock ${suggestions.length} critical items soon to avoid shortages');
//     }

//     if (lowStockItems == 0 && expiringSoon == 0) {
//       recommendations.add('Your inventory is in great condition! Consider optimizing storage space');
//     }

//     return recommendations;
//   }

//   // Predictive ordering
//   Future<Map<String, dynamic>> getPredictiveOrdering(String householdId) async {
//     try {
//       final consumptionPatterns = await analyzeConsumptionPatterns(householdId);
//       final inventorySnapshot = await _firestore
//           .collection('households')
//           .doc(householdId)
//           .collection('inventory')
//           .get();

//       final List<Map<String, dynamic>> orderingSuggestions = [];

//       for (final doc in inventorySnapshot.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final itemId = doc.id;
//         final quantity = (data['quantity'] ?? 0).toDouble();
//         final consumptionRate = consumptionPatterns['consumptionRates'][itemId] ?? 1.0;

//         // Predict when to reorder (when quantity falls below 2 weeks of supply)
//         final weeksOfSupply = quantity / (consumptionRate * 7);
//         final reorderUrgency = _calculateReorderUrgency(weeksOfSupply);

//         if (reorderUrgency > 0.3) { // Only suggest if somewhat urgent
//           orderingSuggestions.add({
//             'item': InventoryItem.fromMap(data, doc.id),
//             'currentQuantity': quantity,
//             'consumptionRate': consumptionRate,
//             'weeksOfSupply': weeksOfSupply,
//             'reorderUrgency': reorderUrgency,
//             'suggestedOrderQuantity': max(consumptionRate * 14, 5), // 2 weeks supply, min 5 units
//           });
//         }
//       }

//       // Sort by urgency
//       orderingSuggestions.sort((a, b) => b['reorderUrgency'].compareTo(a['reorderUrgency']));

//       return {
//         'orderingSuggestions': orderingSuggestions,
//         'totalSuggestions': orderingSuggestions.length,
//         'estimatedWeeklyCost': _calculateEstimatedCost(orderingSuggestions),
//       };
//     } catch (e) {
//       print('Error in predictive ordering: $e');
//       return {
//         'orderingSuggestions': [],
//         'totalSuggestions': 0,
//         'estimatedWeeklyCost': 0.0,
//       };
//     }
//   }

//   double _calculateReorderUrgency(double weeksOfSupply) {
//     if (weeksOfSupply <= 1) return 1.0; // Critical
//     if (weeksOfSupply <= 2) return 0.7; // High
//     if (weeksOfSupply <= 3) return 0.4; // Medium
//     if (weeksOfSupply <= 4) return 0.2; // Low
//     return 0.0; // No urgency
//   }

//   double _calculateEstimatedCost(List<Map<String, dynamic>> suggestions) {
//     double totalCost = 0.0;
//     for (final suggestion in suggestions) {
//       final item = suggestion['item'] as InventoryItem;
//       final suggestedQuantity = suggestion['suggestedOrderQuantity'] ?? 0;
//       totalCost += item.price * suggestedQuantity;
//     }
//     return totalCost;
//   }
// }