import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIService {
  // Securely manage API keys
  static String _getApiKey() {
    if (kReleaseMode) {
      return const String.fromEnvironment('GEMINI_API_KEY');
    } else {
      return 'AIzaSyC7XjzHmYU143j2zLj-LEKdTIdygiYKCz'; // Replace with your actual API key
    }
  }

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // Enhanced chat method with better error handling
  static Future<String> chat(String householdId, String message) async {
    try {
      // Check if householdId is valid
      if (householdId.isEmpty) {
        return "I can't access your inventory because your household ID is missing. Please make sure you're logged in correctly.";
      }

      // Get current inventory from Firestore with error handling
      Map<String, dynamic> inventoryData;
      try {
        inventoryData = await _getHouseholdInventoryData(householdId);
      } catch (e) {
        print('Error fetching inventory: $e');
        return "I'm having trouble accessing your inventory data. Please check your internet connection and try again. If the problem persists, make sure you have inventory items added to your household.";
      }

      // Check if inventory is empty
      if (inventoryData['items'].isEmpty) {
        return "Your inventory is empty. Please add some items to your inventory first. You can do this by going to the Inventory tab and tapping the + button.";
      }

      final householdContext = await _getHouseholdContext(householdId);
      
      final prompt = '''
      You are HomeBot, an intelligent household inventory assistant with access to this home's inventory.

      HOUSEHOLD CONTEXT:
      $householdContext

      CURRENT INVENTORY ITEMS:
      ${jsonEncode(inventoryData)}

      USER QUESTION: $message

      Instructions:
      1. Answer based on the inventory data provided above
      2. If the user asks about specific items, check if they exist in the inventory
      3. Provide practical advice about inventory management
      4. If you can't find an item, politely say so and suggest adding it
      5. Be friendly, helpful, and concise

      Format your response in a natural, conversational way.
      ''';

      final response = await _safeRequest(
        '$_baseUrl?key=${_getApiKey()}',
        {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'topK': 40,
            'topP': 0.8,
            'maxOutputTokens': 1024,
          }
        },
      );

      final data = jsonDecode(response);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? 'I need to learn more about your household to answer that accurately.';
    } catch (e) {
      print('Error in chat method: $e');
      return "I'm experiencing technical difficulties right now. Please try again in a few moments. If the problem continues, check your internet connection.";
    }
  }

  // Enhanced method to fetch inventory data with better error handling
  static Future<Map<String, dynamic>> _getHouseholdInventoryData(String householdId) async {
    try {
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      final items = inventorySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Item',
          'quantity': data['quantity'] ?? 0,
          'category': data['category'] ?? 'Uncategorized',
          'location': data['location'] ?? 'Unknown location',
          'expiry_date': data['expiry_date'] != null 
              ? (data['expiry_date'] as Timestamp).toDate().toString() 
              : 'No expiry date',
        };
      }).toList();

      return {
        'household_id': householdId,
        'item_count': items.length,
        'items': items,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error in _getHouseholdInventoryData: $e');
      rethrow;
    }
  }

  // Generate comprehensive household context for AI prompts
  static Future<String> _getHouseholdContext(String householdId) async {
    try {
      // Get additional household data from Firestore
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();
          
      final householdData = householdDoc.data() ?? {};
      
      return '''
      HOUSEHOLD INFORMATION:
      - ID: $householdId
      - Name: ${householdData['name'] ?? 'Unnamed Household'}
      - Member Count: ${householdData['member_count'] ?? 'Unknown'}
      - Created: ${householdData['created_at'] != null ? (householdData['created_at'] as Timestamp).toDate().toString() : 'Unknown'}
      ''';
    } catch (e) {
      return 'Basic household context: This is a household with inventory management needs.';
    }
  }

  // Safe HTTP request with enhanced error handling and logging
  static Future<String> _safeRequest(String url, Map<String, dynamic> body) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey.isEmpty || apiKey == 'YOUR_ACTUAL_API_KEY_HERE') {
        throw Exception('API key not configured properly. Please update the AIService with your actual API key.');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication error: Please check your API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded: Please try again later');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: Please try again later');
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('API request failed: $e');
      rethrow;
    }
  }
}