import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AIService {
  static String _getApiKey() {
    if (kReleaseMode) {
      return const String.fromEnvironment('GEMINI_API_KEY');
    } else {
      return 'AIzaSyC7XjzHmYU143j2zLj-LEKdTIdygiYKCzI'; // ⚠️ Replace with secure key handling
    }
  }

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// 🔹 Chat with HomeBot - Enhanced with smarter response handling
  static Future<String> chat(String householdId, String message) async {
    try {
      _log("Starting chat for householdId=$householdId");

      // ✅ Step 1: Validate
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in to access your inventory.";
      if (householdId.isEmpty || householdId == 'null') {
        return "I can't access your inventory because no household is selected.";
      }

      // ✅ Step 2: Get data
      final householdContext = await _getHouseholdContext(householdId);
      final inventoryData = await _getHouseholdInventoryData(householdId);

      if (inventoryData['items'].isEmpty) {
        return "Your inventory is empty. Add items first by going to the Inventory tab.";
      }

      // ✅ Step 3: Check for special queries that need immediate responses
      final quickResponse = _handleQuickResponses(message, inventoryData);
      if (quickResponse != null) return quickResponse;

      // ✅ Step 4: Check low stock and expiring items
      final lowStockItems = _filterLowStockItems(inventoryData);
      final expiringSoonItems = _filterExpiringSoonItems(inventoryData);
      final expiredItems = _filterExpiredItems(inventoryData);
      
      String advisoryNote = _buildAdvisoryNote(lowStockItems, expiringSoonItems, expiredItems);

      // ✅ Step 5: Build enhanced prompt with conversation context
      final prompt = _buildEnhancedPrompt(
        user.displayName ?? "User",
        householdContext,
        inventoryData,
        message,
        advisoryNote,
      );

      // ✅ Step 6: Send request
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
            'temperature': 0.7, // Slightly higher for more creative responses
            'topK': 50,
            'topP': 0.95,
            'maxOutputTokens': 2048, // Increased for more detailed responses
          }
        },
      );

      // ✅ Step 7: Parse and format response
      final aiResponse = _extractTextResponse(response) ??
          "I wasn't able to generate a proper response. Could you rephrase your question?";

      // ✅ Step 8: Smart formatting based on query type
      return _formatSmartResponse(aiResponse, message, inventoryData);
    } catch (e) {
      _log("Chat error: $e");
      return "⚠️ Something went wrong while processing your request. Please try again later.";
    }
  }

  /// 🆕 Handle common queries with quick, pre-formatted responses
  static String? _handleQuickResponses(String message, Map<String, dynamic> inventoryData) {
    final lowerMessage = message.toLowerCase().trim();
    final items = (inventoryData['items'] as List).cast<Map<String, dynamic>>();
    
    // Quick inventory summary
    if (lowerMessage.contains('how many items') || 
        lowerMessage.contains('inventory count') ||
        lowerMessage.contains('total items')) {
      return "📊 Your inventory has ${items.length} items. ${_getInventorySummary(inventoryData)}";
    }
    
    // Quick expiry check
    if (lowerMessage.contains('what expired') || 
        lowerMessage.contains('any expired') ||
        lowerMessage.contains('check expired')) {
      final expiredItems = _filterExpiredItems(inventoryData);
      if (expiredItems.isEmpty) return "✅ No expired items found!";
      return "🚫 Found ${expiredItems.length} expired items:\n${_formatProductListForDisplay(expiredItems)}";
    }
    
    // Quick low stock check
    if (lowerMessage.contains('what\'s low') || 
        lowerMessage.contains('low stock') ||
        lowerMessage.contains('running low')) {
      final lowStockItems = _filterLowStockItems(inventoryData);
      if (lowStockItems.isEmpty) return "✅ All items are well stocked!";
      return "📉 Low stock items (less than 3):\n${_formatProductListForDisplay(lowStockItems)}";
    }
    
    // Empty inventory check
    if (lowerMessage.contains('is empty') || 
        lowerMessage.contains('anything in') ||
        lowerMessage.contains('do i have anything')) {
      if (items.isEmpty) return "📭 Your inventory is empty. Add some items to get started!";
      return "✅ Your inventory has ${items.length} items. ${_getInventorySummary(inventoryData)}";
    }

    return null;
  }

  /// 🆕 Build comprehensive advisory note
  static String _buildAdvisoryNote(
    List<Map<String, dynamic>> lowStockItems,
    List<Map<String, dynamic>> expiringSoonItems,
    List<Map<String, dynamic>> expiredItems,
  ) {
    String advisoryNote = "";
    
    if (expiredItems.isNotEmpty) {
      advisoryNote += '''
🚫 URGENT - EXPIRED ITEMS:
These items have expired and should be disposed of:
${_formatProductListForAI(expiredItems)}

''';
    }
    
    if (expiringSoonItems.isNotEmpty) {
      advisoryNote += '''
⏰ EXPIRING SOON (within 7 days):
Consider using these items first:
${_formatProductListForAI(expiringSoonItems)}

''';
    }
    
    if (lowStockItems.isNotEmpty) {
      advisoryNote += '''
📉 LOW STOCK ALERT (below 3):
Time to restock these:
${_formatProductListForAI(lowStockItems)}

''';
    }

    return advisoryNote;
  }

  /// 🆕 Get inventory summary statistics
  static String _getInventorySummary(Map<String, dynamic> inventoryData) {
    final items = (inventoryData['items'] as List).cast<Map<String, dynamic>>();
    final lowStockCount = _filterLowStockItems(inventoryData).length;
    final expiringSoonCount = _filterExpiringSoonItems(inventoryData).length;
    final expiredCount = items.where((item) => item['is_expired'] == true).length;
    
    final categories = items.map((item) => item['category']).toSet();
    final locations = items.map((item) => item['location']).toSet();
    
    return '''
• 📦 Categories: ${categories.length}
• 🏠 Storage areas: ${locations.length}
• 📉 Low stock: $lowStockCount items
• ⏰ Expiring soon: $expiringSoonCount items
• 🚫 Expired: $expiredCount items''';
  }

  /// 🆕 Enhanced prompt for smarter responses
  static String _buildEnhancedPrompt(
    String userName,
    String householdContext,
    Map<String, dynamic> inventory,
    String userMessage,
    String advisoryNote,
  ) {
    final items = inventory['items'] as List;
    final currentDate = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(currentDate);

    return '''
You are **HomeBot**, an intelligent household inventory assistant with expertise in food management, expiry tracking, and smart shopping. Today is $formattedDate.

USER: $userName

HOUSEHOLD CONTEXT:
$householdContext

CURRENT INVENTORY STATS:
- Total items: ${items.length}
- Categories: ${items.map((item) => item['category']).toSet().length}
- Storage locations: ${items.map((item) => item['location']).toSet().length}
${_getInventoryStatsForPrompt(inventory)}

ADVISORY ALERTS:
$advisoryNote

USER'S QUESTION: "$userMessage"

RESPONSE STRATEGY:
1. **Understand Intent**: First, determine what the user really needs
2. **Provide Value**: Offer practical, actionable advice
3. **Be Proactive**: Suggest related actions they might find helpful
4. **Use Data**: Reference specific inventory items when relevant
5. **Personalize**: Tailor advice to their household context

EXPIRY & INVENTORY MANAGEMENT EXPERTISE:
- **First-In-First-Out (FIFO)**: Recommend using older items first
- **Meal Planning**: Suggest recipes based on expiring items
- **Shopping Strategy**: Advise on what to buy and when
- **Storage Tips**: Provide optimal storage advice
- **Waste Reduction**: Help minimize food waste

CONVERSATIONAL GUIDELINES:
- Be friendly, empathetic, and genuinely helpful
- Ask clarifying questions if the request is ambiguous
- Provide multiple options when appropriate
- Use emojis tastefully to enhance communication
- Admit when you don't have enough information
- Suggest next steps or related questions

PRODUCT FORMATTING:
When listing specific items, use this exact format for each product:
[PRODUCT]
name: [Item Name]
quantity: [Quantity]
category: [Category]
expiry: [Expiry Date]
location: [Storage Location]
id: [Item ID]
[/PRODUCT]

Use product blocks when:
- Listing multiple items
- Showing search results
- Highlighting expiring/low stock items
- Providing specific recommendations

CRITICAL: Always prioritize safety - clearly warn about expired items and advise proper disposal.

Now, provide a helpful, intelligent response to the user's question:
''';
  }

  /// 🆕 Get detailed inventory stats for prompt
  static String _getInventoryStatsForPrompt(Map<String, dynamic> inventory) {
    final items = (inventory['items'] as List).cast<Map<String, dynamic>>();
    
    // Category breakdown
    final categoryCount = <String, int>{};
    final locationCount = <String, int>{};
    
    for (final item in items) {
      final category = item['category'];
      final location = item['location'];
      
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      locationCount[location] = (locationCount[location] ?? 0) + 1;
    }
    
    final topCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(3);
      
    final topLocations = locationCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(3);
    
    return '''
- Top categories: ${topCategories.map((e) => '${e.key} (${e.value})').join(', ')}
- Main storage: ${topLocations.map((e) => '${e.key} (${e.value})').join(', ')}
- Expiring soon: ${_filterExpiringSoonItems(inventory).length} items
- Low stock: ${_filterLowStockItems(inventory).length} items
- Expired: ${items.where((item) => item['is_expired'] == true).length} items''';
  }

  /// 🆕 Smart response formatting based on query type
  static String _formatSmartResponse(String aiResponse, String userMessage, Map<String, dynamic> inventoryData) {
    final lowerMessage = userMessage.toLowerCase();
    
    // Determine response type and format accordingly
    if (_isListingQuery(lowerMessage)) {
      return _formatListingResponse(aiResponse, userMessage, inventoryData);
    } else if (_isAnalysisQuery(lowerMessage)) {
      return _formatAnalysisResponse(aiResponse, inventoryData);
    } else if (_isRecommendationQuery(lowerMessage)) {
      return _formatRecommendationResponse(aiResponse, inventoryData);
    } else {
      return _formatConversationalResponse(aiResponse, inventoryData);
    }
  }

  /// 🆕 Check if query is asking for a list
  static bool _isListingQuery(String message) {
    final listingPhrases = [
      'list',
      'show me',
      'what items',
      'which items',
      'display',
      'see all',
      'view',
      'what do i have',
      'what do we have'
    ];
    return listingPhrases.any((phrase) => message.contains(phrase));
  }

  /// 🆕 Check if query is asking for analysis
  static bool _isAnalysisQuery(String message) {
    final analysisPhrases = [
      'how many',
      'analyze',
      'summary',
      'overview',
      'statistics',
      'report',
      'status',
      'how are we',
      'situation'
    ];
    return analysisPhrases.any((phrase) => message.contains(phrase));
  }

  /// 🆕 Check if query is asking for recommendations
  static bool _isRecommendationQuery(String message) {
    final recommendationPhrases = [
      'suggest',
      'recommend',
      'what should',
      'advice',
      'tips',
      'how to',
      'help me',
      'what can i'
    ];
    return recommendationPhrases.any((phrase) => message.contains(phrase));
  }

  /// 🆕 Format listing responses with product cards
  static String _formatListingResponse(String aiResponse, String userMessage, Map<String, dynamic> inventoryData) {
    final relevantItems = _getRelevantItemsForQuery(userMessage, inventoryData);
    
    if (relevantItems.isEmpty) {
      return "$aiResponse\n\n📝 No matching items found in your inventory.";
    }
    
    final productBlocks = relevantItems.map((item) => _formatProductBlock(item)).join('\n\n');
    return '$aiResponse\n\n$productBlocks';
  }

  /// 🆕 Format analysis responses with enhanced insights
  static String _formatAnalysisResponse(String aiResponse, Map<String, dynamic> inventoryData) {
    final summary = _getInventorySummary(inventoryData);
    return '$aiResponse\n\n---\n📊 **Inventory Summary**:\n$summary';
  }

  /// 🆕 Format recommendation responses with actionable steps
  static String _formatRecommendationResponse(String aiResponse, Map<String, dynamic> inventoryData) {
    final expiringSoon = _filterExpiringSoonItems(inventoryData);
    final lowStock = _filterLowStockItems(inventoryData);
    
    String actionItems = '';
    
    if (expiringSoon.isNotEmpty) {
      actionItems += '⏰ **Priority Items**: Consider using ${expiringSoon.take(3).map((item) => item['name']).join(', ')} soon.\n\n';
    }
    
    if (lowStock.isNotEmpty) {
      actionItems += '🛒 **Restock Needed**: ${lowStock.take(3).map((item) => item['name']).join(', ')}\n\n';
    }
    
    if (actionItems.isNotEmpty) {
      return '$aiResponse\n\n---\n🎯 **Action Items**:\n$actionItems';
    }
    
    return aiResponse;
  }

  /// 🆕 Format conversational responses naturally
  static String _formatConversationalResponse(String aiResponse, Map<String, dynamic> inventoryData) {
    // For conversational responses, just return the AI response as-is
    // but ensure it includes relevant product info when needed
    final mentionedItems = _extractMentionedItems(aiResponse, (inventoryData['items'] as List).cast<Map<String, dynamic>>());
    
    if (mentionedItems.isNotEmpty && mentionedItems.length <= 5) {
      final productBlocks = mentionedItems.map((item) => _formatProductBlock(item)).join('\n\n');
      return '$aiResponse\n\n$productBlocks';
    }
    
    return aiResponse;
  }

  /// 🆕 Enhanced product block with more details
  static String _formatProductBlock(Map<String, dynamic> product) {
    final status = _getProductStatus(product);
    final statusIcon = status == 'Expired' ? '🚫' : 
                      status == 'Expiring soon' ? '⏰' : 
                      status == 'Low stock' ? '📉' : '✅';
    
    return '''
[PRODUCT]
name: ${product['name']}
quantity: ${product['quantity']}
category: ${product['category']}
location: ${product['location']}
expiry: ${product['expiry_date_display']}
status: $statusIcon $status
id: ${product['id']}
[/PRODUCT]''';
  }

  /// 🆕 Get product status for display
  static String _getProductStatus(Map<String, dynamic> product) {
    if (product['is_expired'] == true) return 'Expired';
    
    final daysUntilExpiry = product['days_until_expiry'];
    if (daysUntilExpiry != null && daysUntilExpiry <= 7) return 'Expiring soon';
    
    final quantity = product['quantity'];
    if (quantity is int && quantity < 3) return 'Low stock';
    
    return 'Good';
  }

  /// 🆕 Format product list for display (simple version)
  static String _formatProductListForDisplay(List<Map<String, dynamic>> products) {
    return products.map((product) {
      final status = _getProductStatus(product);
      final statusIcon = status == 'Expired' ? '🚫' : 
                        status == 'Expiring soon' ? '⏰' : 
                        status == 'Low stock' ? '📉' : '✅';
      return '$statusIcon ${product['name']} (${product['quantity']} left) - ${product['expiry_date_display']}';
    }).join('\n');
  }

  /// 🆕 Enhanced item relevance detection
  static List<Map<String, dynamic>> _getRelevantItemsForQuery(String query, Map<String, dynamic> inventoryData) {
    final lowerQuery = query.toLowerCase();
    final allItems = (inventoryData['items'] as List).cast<Map<String, dynamic>>();
    
    // Priority-based matching
    if (lowerQuery.contains('expired') || lowerQuery.contains('old') || lowerQuery.contains('bad')) {
      return _filterExpiredItems(inventoryData);
    } else if (lowerQuery.contains('expiring') || lowerQuery.contains('soon') || lowerQuery.contains('about to expire')) {
      return _filterExpiringSoonItems(inventoryData);
    } else if (lowerQuery.contains('low') || lowerQuery.contains('running out') || lowerQuery.contains('almost out')) {
      return _filterLowStockItems(inventoryData);
    } else if (lowerQuery.contains('category')) {
      final category = _extractCategoryFromQuery(lowerQuery);
      if (category.isNotEmpty) {
        return allItems.where((item) => 
          (item['category'] as String).toLowerCase().contains(category)
        ).toList();
      }
    } else if (lowerQuery.contains('location') || lowerQuery.contains('fridge') || lowerQuery.contains('pantry') || lowerQuery.contains('freezer')) {
      final location = _extractLocationFromQuery(lowerQuery);
      if (location.isNotEmpty) {
        return allItems.where((item) => 
          (item['location'] as String).toLowerCase().contains(location)
        ).toList();
      }
    }
    
    // Smart keyword matching for common food items
    final foodKeywords = {
      'dairy': ['milk', 'cheese', 'yogurt', 'butter', 'cream'],
      'vegetables': ['vegetable', 'carrot', 'broccoli', 'lettuce', 'tomato', 'potato', 'onion'],
      'fruits': ['fruit', 'apple', 'banana', 'orange', 'grape', 'berry', 'mango'],
      'meat': ['meat', 'chicken', 'beef', 'pork', 'fish', 'steak', 'bacon'],
      'beverages': ['drink', 'soda', 'juice', 'water', 'coffee', 'tea', 'beer', 'wine'],
      'grains': ['bread', 'rice', 'pasta', 'cereal', 'flour', 'oats'],
    };
    
    for (final entry in foodKeywords.entries) {
      if (entry.value.any((keyword) => lowerQuery.contains(keyword))) {
        return allItems.where((item) => 
          item['category'].toLowerCase().contains(entry.key) ||
          item['name'].toLowerCase().contains(entry.key) ||
          entry.value.any((keyword) => item['name'].toLowerCase().contains(keyword))
        ).toList();
      }
    }
    
    // Return all items for general inventory queries
    if (_isGeneralInventoryQuery(lowerQuery)) {
      return allItems;
    }
    
    // Text-based search for item names
    if (lowerQuery.length > 3) {
      return allItems.where((item) => 
        (item['name'] as String).toLowerCase().contains(lowerQuery)
      ).toList();
    }
    
    return [];
  }

  /// 🆕 Check if query is general inventory related
  static bool _isGeneralInventoryQuery(String query) {
    final generalPhrases = [
      'inventory',
      'items',
      'stock',
      'what do i have',
      'everything',
      'all items',
      'what\'s in my inventory'
    ];
    return generalPhrases.any((phrase) => query.contains(phrase));
  }

  /// 🆕 Extract category from user query
  static String _extractCategoryFromQuery(String query) {
    final categories = ['dairy', 'meat', 'vegetables', 'fruits', 'beverages', 'cleaning', 'personal', 'medication', 'other', 'grains'];
    for (final category in categories) {
      if (query.contains(category)) {
        return category;
      }
    }
    return '';
  }

  /// 🆕 Extract location from user query
  static String _extractLocationFromQuery(String query) {
    final locations = ['fridge', 'freezer', 'pantry', 'cupboard', 'shelf', 'cabinet', 'counter'];
    for (final location in locations) {
      if (query.contains(location)) {
        return location;
      }
    }
    return '';
  }

  /// 🆕 Extract items mentioned in AI response
  static List<Map<String, dynamic>> _extractMentionedItems(String aiResponse, List<Map<String, dynamic>> items) {
    final List<Map<String, dynamic>> mentionedItems = [];
    final lowerResponse = aiResponse.toLowerCase();
    
    for (final item in items) {
      final itemName = (item['name'] as String).toLowerCase();
      if (lowerResponse.contains(itemName)) {
        mentionedItems.add(item);
      }
    }
    
    return mentionedItems;
  }

  /// 🆕 Format product list for AI context
  static String _formatProductListForAI(List<Map<String, dynamic>> products) {
    return products.map((product) {
      final expiryInfo = product['expiryDate'] != 'No expiry date' 
          ? ' (expires: ${_formatExpiryDateForDisplay(product['expiryDate'])})'
          : '';
      return "- ${product['name']} (qty: ${product['quantity']}$expiryInfo)";
    }).join("\n");
  }

  /// 🔹 Get expiring soon items specifically
  static Future<String> getExpiringItems(String householdId, {int daysThreshold = 7}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in first.";
      if (householdId.isEmpty || householdId == 'null') {
        return "Please select a household first.";
      }

      final inventoryData = await _getHouseholdInventoryData(householdId);
      final expiringSoonItems = _filterExpiringSoonItems(inventoryData, daysThreshold: daysThreshold);

      if (expiringSoonItems.isEmpty) {
        return "✅ No items are expiring in the next $daysThreshold days. Great job managing your inventory!";
      }

      final productBlocks = expiringSoonItems.map((item) => _formatProductBlock(item)).join('\n\n');
      
      return '''
⏰ Items Expiring in the Next $daysThreshold Days:

$productBlocks
  
💡 Tip: Consider using these items soon or check if they need to be consumed first.
''';
    } catch (e) {
      _log("Expiring items error: $e");
      return "⚠️ Unable to check expiring items right now.";
    }
  }

  /// 🔹 Check for expired items
  static Future<String> getExpiredItems(String householdId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in first.";
      if (householdId.isEmpty || householdId == 'null') {
        return "Please select a household first.";
      }

      final inventoryData = await _getHouseholdInventoryData(householdId);
      final expiredItems = _filterExpiredItems(inventoryData);

      if (expiredItems.isEmpty) {
        return "✅ No expired items found. Great job managing your inventory!";
      }

      final productBlocks = expiredItems.map((item) => _formatProductBlock(item)).join('\n\n');

      return '''
🚫 Expired Items (Please Dispose Safely):

$productBlocks
  
⚠️ Warning: These items have passed their expiry date and should not be consumed.
''';
    } catch (e) {
      _log("Expired items error: $e");
      return "⚠️ Unable to check expired items right now.";
    }
  }

  /// 🔹 Suggest shopping list with expiry awareness
  static Future<String> suggestShoppingList(String householdId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in first.";
      if (householdId.isEmpty || householdId == 'null') {
        return "Please select a household first.";
      }

      final inventoryData = await _getHouseholdInventoryData(householdId);
      final lowStockItems = _filterLowStockItems(inventoryData);
      final expiringSoonItems = _filterExpiringSoonItems(inventoryData);

      if (lowStockItems.isEmpty) {
        return "✅ All items are sufficiently stocked. No shopping needed right now!";
      }

      final shoppingProductBlocks = lowStockItems.map((item) => _formatProductBlock(item)).join('\n\n');
      String shoppingList = '''
🛒 Suggested Shopping List (Low Stock Items):

$shoppingProductBlocks
''';

      if (expiringSoonItems.isNotEmpty) {
        final expiringBlocks = expiringSoonItems.take(3).map((item) => _formatProductBlock(item)).join('\n\n');
        shoppingList += '''

⚠️ Note: You have ${expiringSoonItems.length} items expiring soon. Consider using these before they expire:

$expiringBlocks
''';
      }

      return shoppingList;
    } catch (e) {
      _log("Shopping list error: $e");
      return "⚠️ Unable to generate shopping list right now.";
    }
  }

  /// 🔹 Get items by category
  static Future<String> getItemsByCategory(String householdId, String category) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in first.";
      if (householdId.isEmpty || householdId == 'null') {
        return "Please select a household first.";
      }

      final inventoryData = await _getHouseholdInventoryData(householdId);
      final items = (inventoryData['items'] as List).cast<Map<String, dynamic>>();
      final categoryItems = items.where((item) => 
        (item['category'] as String).toLowerCase().contains(category.toLowerCase())
      ).toList();

      if (categoryItems.isEmpty) {
        return "No items found in the $category category.";
      }

      final productBlocks = categoryItems.map((item) => _formatProductBlock(item)).join('\n\n');

      return '''
📂 Items in $category category:

$productBlocks
''';
    } catch (e) {
      _log("Category items error: $e");
      return "⚠️ Unable to fetch category items right now.";
    }
  }

  /// 🔹 Search items by name
  static Future<String> searchItems(String householdId, String searchQuery) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Please log in first.";
      if (householdId.isEmpty || householdId == 'null') {
        return "Please select a household first.";
      }

      final inventoryData = await _getHouseholdInventoryData(householdId);
      final items = (inventoryData['items'] as List).cast<Map<String, dynamic>>();
      final searchResults = items.where((item) => 
        (item['name'] as String).toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();

      if (searchResults.isEmpty) {
        return "No items found matching '$searchQuery'.";
      }

      final productBlocks = searchResults.map((item) => _formatProductBlock(item)).join('\n\n');

      return '''
🔍 Search Results for "$searchQuery":

$productBlocks
''';
    } catch (e) {
      _log("Search items error: $e");
      return "⚠️ Unable to search items right now.";
    }
  }

  // ------------------ Core Helper Methods ------------------

  static List<Map<String, dynamic>> _filterLowStockItems(
      Map<String, dynamic> inventory,
      {int threshold = 3}) {
    final items = (inventory['items'] as List).cast<Map<String, dynamic>>();
    return items.where((item) {
      final qty = item['quantity'] ?? 0;
      return qty is int && qty < threshold;
    }).toList();
  }

  static List<Map<String, dynamic>> _filterExpiringSoonItems(
      Map<String, dynamic> inventory,
      {int daysThreshold = 7}) {
    final items = (inventory['items'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final thresholdDate = now.add(Duration(days: daysThreshold));

    return items.where((item) {
      final expiryDate = item['expiryDate'];
      if (expiryDate == null || expiryDate == 'No expiry date') return false;

      try {
        final expiry = DateTime.parse(expiryDate);
        return expiry.isAfter(now) && expiry.isBefore(thresholdDate);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  static List<Map<String, dynamic>> _filterExpiredItems(
      Map<String, dynamic> inventory) {
    final items = (inventory['items'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();

    return items.where((item) {
      final expiryDate = item['expiryDate'];
      if (expiryDate == null || expiryDate == 'No expiry date') return false;

      try {
        final expiry = DateTime.parse(expiryDate);
        return expiry.isBefore(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  static Future<Map<String, dynamic>> _getHouseholdInventoryData(
      String householdId) async {
    try {
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('inventory')
          .get();

      final items = inventorySnapshot.docs.map((doc) {
        final data = doc.data();
        final expiryDate = data['expiryDate'];
        String expiryDisplay = 'No expiry date';
        DateTime? expiryDateTime;
        
        // Handle expiry date conversion and formatting
        if (expiryDate is Timestamp) {
          expiryDateTime = expiryDate.toDate();
          expiryDisplay = _formatExpiryDate(expiryDateTime);
        } else if (expiryDate is String && expiryDate.isNotEmpty) {
          try {
            expiryDateTime = DateTime.parse(expiryDate);
            expiryDisplay = _formatExpiryDate(expiryDateTime);
          } catch (e) {
            expiryDisplay = 'Invalid date';
          }
        }

        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'quantity': data['quantity'] ?? 0,
          'category': data['category'] ?? 'Uncategorized',
          'location': data['location'] ?? 'Unknown',
          'expiryDate': expiryDateTime?.toIso8601String() ?? 'No expiry date',
          'expiry_date_display': expiryDisplay,
          'is_expired': expiryDateTime != null ? expiryDateTime.isBefore(DateTime.now()) : false,
          'days_until_expiry': expiryDateTime != null ? 
              expiryDateTime.difference(DateTime.now()).inDays : null,
        };
      }).toList();

      // Sort items by expiry date (soonest first)
      items.sort((a, b) {
        if (a['expiryDate'] == 'No expiry date') return 1;
        if (b['expiryDate'] == 'No expiry date') return -1;
        
        try {
          final aExpiry = DateTime.parse(a['expiryDate']);
          final bExpiry = DateTime.parse(b['expiryDate']);
          return aExpiry.compareTo(bExpiry);
        } catch (e) {
          return 0;
        }
      });

      return {
        'household_id': householdId,
        'item_count': items.length,
        'items': items,
        'expiring_soon_count': _filterExpiringSoonItems({'items': items}).length,
        'expired_count': items.where((item) => item['is_expired'] == true).length,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _log("Inventory fetch error: $e");
      rethrow;
    }
  }

  static String _formatExpiryDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays < 0) {
      return 'Expired ${difference.inDays.abs()} days ago';
    } else if (difference.inDays == 0) {
      return 'Expires today';
    } else if (difference.inDays == 1) {
      return 'Expires tomorrow';
    } else if (difference.inDays <= 7) {
      return 'Expires in ${difference.inDays} days';
    } else {
      return 'Expires ${DateFormat('MMM d, y').format(date)}';
    }
  }

  static String _formatExpiryDateForDisplay(String expiryDate) {
    if (expiryDate == 'No expiry date') return 'No expiry date';
    
    try {
      final date = DateTime.parse(expiryDate);
      return _formatExpiryDate(date);
    } catch (e) {
      return expiryDate;
    }
  }

  static Future<String> _getHouseholdContext(String householdId) async {
    try {
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      final data = householdDoc.data() ?? {};
      return '''
- ID: $householdId
- Name: ${data['name'] ?? data['householdName'] ?? 'Unnamed'}
- Created: ${(data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate().toIso8601String() : 'Unknown'}
''';
    } catch (e) {
      _log("Household context error: $e");
      return 'Household context unavailable.';
    }
  }

  static Future<String> _safeRequest(
      String url, Map<String, dynamic> body) async {
    final apiKey = _getApiKey();
    if (apiKey.isEmpty || apiKey.contains('YOUR_API_KEY')) {
      throw Exception('API key missing or invalid');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    _log("API status: ${response.statusCode}");
    if (response.statusCode == 200) return response.body;

    switch (response.statusCode) {
      case 401:
        throw Exception('Invalid API key');
      case 429:
        throw Exception('Rate limit exceeded');
      default:
        throw Exception(
            'API error ${response.statusCode}: ${response.body.substring(0, 200)}');
    }
  }

  static String? _extractTextResponse(String rawResponse) {
    try {
      final data = jsonDecode(rawResponse);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      return parts[0]['text'];
    } catch (e) {
      _log("Response parsing error: $e");
      return null;
    }
  }

  static void _log(String msg) {
    if (kDebugMode) print("🤖 [AIService] $msg");
  }
}