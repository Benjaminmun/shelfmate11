import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class ChatPage extends StatefulWidget {
  final String householdId;
  
  const ChatPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add a welcome message
    _messages.add({
      'text': 'Hi! I\'m your inventory assistant. I can help you manage your household items. What would you like to know about your inventory?',
      'sender': 'ai'
    });
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final String message = _messageController.text;
    _messageController.clear();
    
    // Add user message
    setState(() {
      _messages.add({'text': message, 'sender': 'user'});
      _isLoading = true;
    });

    // Scroll to bottom when new message is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Get AI response with household context
    try {
      final String response = await AIService.chat(widget.householdId, message);
      
      setState(() {
        _messages.add({'text': response, 'sender': 'ai'});
        _isLoading = false;
      });
      
      // Scroll to bottom after AI response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'I\'m having technical difficulties. Please check your internet connection and make sure you have inventory items added. Error: ${e.toString()}',
          'sender': 'ai'
        });
        _isLoading = false;
      });
    }
  }

  // Quick action buttons for common inventory queries
  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[50],
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            label: Text('Show all items'),
            onPressed: () {
              _messageController.text = 'What items do I have in my inventory?';
              _sendMessage();
            },
            backgroundColor: Color(0xFF2D5D7C).withOpacity(0.1),
          ),
          ActionChip(
            label: Text('Low stock items'),
            onPressed: () {
              _messageController.text = 'What items are running low in my inventory?';
              _sendMessage();
            },
            backgroundColor: Colors.orange.withOpacity(0.1),
          ),
          ActionChip(
            label: Text('Add an item'),
            onPressed: () {
              // Navigate to add item page
              Navigator.pushNamed(context, '/add_item');
            },
            backgroundColor: Colors.green.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Assistant'),
        backgroundColor: Color(0xFF2D5D7C),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Manual refresh
              setState(() {
                _isLoading = true;
              });
              // Simulate a refresh
              Future.delayed(Duration(seconds: 1), () {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Refreshed inventory data')),
                );
              });
            },
            tooltip: 'Refresh inventory data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D5D7C).withOpacity(0.1),
              Color(0xFF2D5D7C).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildQuickActions(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ChatBubble(
                    text: message['text']!,
                    isUser: message['sender'] == 'user',
                    timestamp: '${DateTime.now().hour}:${DateTime.now().minute}',
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5D7C)),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Accessing your inventory...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              margin: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask about your inventory...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color(0xFF2D5D7C),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
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

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String timestamp;

  const ChatBubble({
    Key? key, 
    required this.text, 
    required this.isUser,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) 
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Color(0xFF2D5D7C),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2, color: Colors.white, size: 18),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isUser ? Color(0xFF2D5D7C) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: isUser ? Radius.circular(20) : Radius.circular(4),
                  bottomRight: isUser ? Radius.circular(4) : Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) 
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Color(0xFF2D5D7C).withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }
}