// ml_prediction_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/inventory_item_model.dart';

class MLPredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _getUserId() {
    return _auth.currentUser?.uid;
  }

  // Track item usage
  Future<void> recordUsage(String householdId, String itemId, int quantityUsed, {String? notes}) async {
    try {
      final usageRecord = UsageRecord(
        timestamp: DateTime.now(),
        quantityChange: -quantityUsed, // Negative for usage
        type: 'used',
        notes: notes,
      );

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .collection('usage_history')
          .add(usageRecord.toMap());

      // Update consumption pattern
      await _updateConsumptionPattern(householdId, itemId);
    } catch (e) {
      print('Error recording usage: $e');
    }
  }

  // Track restocking
  Future<void> recordRestock(String householdId, String itemId, int quantityAdded, {String? notes}) async {
    try {
      final restockRecord = UsageRecord(
        timestamp: DateTime.now(),
        quantityChange: quantityAdded, // Positive for restocking
        type: 'restocked',
        notes: notes,
      );

      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .collection('usage_history')
          .add(restockRecord.toMap());

      // Update consumption pattern
      await _updateConsumptionPattern(householdId, itemId);
    } catch (e) {
      print('Error recording restock: $e');
    }
  }

  // Calculate consumption patterns
  Future<void> _updateConsumptionPattern(String householdId, String itemId) async {
    try {
      final historySnapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .collection('usage_history')
          .orderBy('timestamp', descending: true)
          .limit(50) // Last 50 records
          .get();

      if (historySnapshot.docs.isEmpty) return;

      final usageHistory = historySnapshot.docs
          .map((doc) => UsageRecord.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Calculate average daily usage
      final dailyUsage = _calculateAverageDailyUsage(usageHistory);
      final usageFrequency = _calculateUsageFrequency(usageHistory);
      final typicalQuantity = _calculateTypicalRestockQuantity(usageHistory);

      final consumptionPattern = ConsumptionPattern(
        itemId: itemId,
        householdId: householdId,
        averageDailyUsage: dailyUsage,
        usageFrequency: usageFrequency,
        lastUsed: _findLastUsed(usageHistory),
        lastRestocked: _findLastRestocked(usageHistory),
        typicalRestockQuantity: typicalQuantity,
        usageHistory: usageHistory,
      );

      // Save consumption pattern
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .update({
        'consumptionPattern': consumptionPattern.toMap(),
        'lastPatternUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating consumption pattern: $e');
    }
  }

  double _calculateAverageDailyUsage(List<UsageRecord> history) {
    final usageRecords = history.where((record) => record.type == 'used').toList();
    if (usageRecords.length < 2) return 0.0;

    final firstDate = usageRecords.last.timestamp;
    final lastDate = usageRecords.first.timestamp;
    final totalDays = lastDate.difference(firstDate).inDays;

    if (totalDays <= 0) return 0.0;

    final totalUsage = usageRecords.fold<int>(0, (sum, record) => sum + record.quantityChange.abs());
    return totalUsage / totalDays;
  }

  int _calculateUsageFrequency(List<UsageRecord> history) {
    final usageRecords = history.where((record) => record.type == 'used').toList();
    if (usageRecords.isEmpty) return 0;

    final firstDate = usageRecords.last.timestamp;
    final lastDate = usageRecords.first.timestamp;
    final totalWeeks = lastDate.difference(firstDate).inDays / 7;

    if (totalWeeks <= 0) return usageRecords.length;

    return (usageRecords.length / totalWeeks).round();
  }

  int _calculateTypicalRestockQuantity(List<UsageRecord> history) {
    final restockRecords = history.where((record) => record.type == 'restocked').toList();
    if (restockRecords.isEmpty) return 1;

    final quantities = restockRecords.map((record) => record.quantityChange).toList();
    quantities.sort();
    
    // Return median
    final middle = quantities.length ~/ 2;
    if (quantities.length.isOdd) {
      return quantities[middle];
    } else {
      return ((quantities[middle - 1] + quantities[middle]) ~/ 2);
    }
  }

  DateTime _findLastUsed(List<UsageRecord> history) {
    final lastUsed = history.where((record) => record.type == 'used').firstOrNull;
    return lastUsed?.timestamp ?? DateTime.now();
  }

  DateTime _findLastRestocked(List<UsageRecord> history) {
    final lastRestocked = history.where((record) => record.type == 'restocked').firstOrNull;
    return lastRestocked?.timestamp ?? DateTime.now();
  }

  // Predict when item will run out
  Future<PredictionResult?> predictStockOut(String householdId, String itemId) async {
    try {
      final itemDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) return null;

      final data = itemDoc.data() as Map<String, dynamic>;
      final currentQuantity = data['quantity'] as int;
      final consumptionPattern = data['consumptionPattern'] as Map<String, dynamic>?;

      if (consumptionPattern == null || currentQuantity <= 0) {
        return null;
      }

      final pattern = ConsumptionPattern.fromMap(consumptionPattern);
      final dailyUsage = pattern.averageDailyUsage;

      if (dailyUsage <= 0) return null;

      // Simple linear prediction
      final daysUntilEmpty = (currentQuantity / dailyUsage).floor();
      final predictedDate = DateTime.now().add(Duration(days: daysUntilEmpty));

      // Calculate confidence based on data quality
      final confidence = _calculateConfidence(pattern);
      final recommendation = _generateRecommendation(daysUntilEmpty, pattern);

      final prediction = PredictionResult(
        itemId: itemId,
        predictedDepletionDate: predictedDate,
        confidenceScore: confidence,
        daysUntilEmpty: daysUntilEmpty,
        recommendation: recommendation,
        calculatedAt: DateTime.now(),
      );

      // Save prediction
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .doc(itemId)
          .update({
        'prediction': prediction.toMap(),
        'lastPredictionUpdate': FieldValue.serverTimestamp(),
      });

      return prediction;
    } catch (e) {
      print('Error predicting stock out: $e');
      return null;
    }
  }

  double _calculateConfidence(ConsumptionPattern pattern) {
    double confidence = 0.5; // Base confidence

    // More usage history = higher confidence
    if (pattern.usageHistory.length > 10) confidence += 0.3;
    else if (pattern.usageHistory.length > 5) confidence += 0.2;
    else if (pattern.usageHistory.length > 2) confidence += 0.1;

    // Consistent usage pattern = higher confidence
    if (pattern.usageFrequency > 0) {
      final consistency = (pattern.averageDailyUsage / pattern.typicalRestockQuantity).abs();
      if (consistency < 0.5) confidence += 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  String _generateRecommendation(int daysUntilEmpty, ConsumptionPattern pattern) {
    if (daysUntilEmpty <= 0) {
      return 'Out of stock - restock immediately';
    } else if (daysUntilEmpty <= 2) {
      return 'Critical - restock today';
    } else if (daysUntilEmpty <= 7) {
      return 'Low stock - restock soon';
    } else if (daysUntilEmpty <= 14) {
      return 'Adequate stock - plan future purchase';
    } else {
      return 'Well stocked - no immediate action needed';
    }
  }

  // Batch prediction for all household items
  Future<List<PredictionResult>> predictAllItems(String householdId) async {
    try {
      final snapshot = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      final predictions = <PredictionResult>[];

      for (final doc in snapshot.docs) {
        final prediction = await predictStockOut(householdId, doc.id);
        if (prediction != null) {
          predictions.add(prediction);
        }
      }

      return predictions;
    } catch (e) {
      print('Error predicting all items: $e');
      return [];
    }
  }

  // Get items that need restocking soon
  Stream<QuerySnapshot> getItemsNeedingRestock(String householdId, {int daysThreshold = 7}) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('inventory')
        .where('prediction.daysUntilEmpty', isLessThanOrEqualTo: daysThreshold)
        .snapshots();
  }
}