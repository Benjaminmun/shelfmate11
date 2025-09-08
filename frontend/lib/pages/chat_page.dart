import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/speech_service.dart';

class ChatPage extends StatefulWidget {
  final String householdId;
  
  const ChatPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = true;
  bool _isListening = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;
  final FocusNode _messageFocusNode = FocusNode();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Initialize timeago messages
    timeago.setLocaleMessages('en', timeago.EnMessages());
    
    // Add a welcome message
    _messages.add(ChatMessage(
      text: 'Hi! I\'m your inventory assistant. I can help you manage your household items. What would you like to know about your inventory?',
      sender: 'ai',
      timestamp: DateTime.now(),
    ));
    
    // Initialize typing animation
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _typingAnimation = CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    );
    
    // Check network connection
    _checkConnection();
    
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });
  }
  
  @override
  void dispose() {
    _typingController.dispose();
    _messageFocusNode.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _checkConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final String message = _messageController.text;
    _messageController.clear();
    FocusScope.of(context).unfocus(); // Unfocus the text field
    
    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        sender: 'user',
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    // Scroll to bottom when new message is added
    _scrollToBottom();

    // Get AI response with household context
    try {
      if (!_isConnected) {
        throw Exception('No internet connection');
      }
      
      // Use timeout for the AI service call
      final String response = await AIService.chat(widget.householdId, message)
          .timeout(const Duration(seconds: 30), onTimeout: () {
            return 'I\'m taking longer than usual to respond. Please check your connection or try again.';
          });
      
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          sender: 'ai',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      // Scroll to bottom after AI response
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'I\'m having technical difficulties. Please check your internet connection and make sure you have inventory items added.',
          sender: 'ai',
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Quick action buttons for common inventory queries
  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> actions = [
      {
        'label': 'Show all items',
        'icon': Icons.list_alt,
        'action': () {
          _messageController.text = 'What items do I have in my inventory?';
          _sendMessage();
        },
        'color': Color(0xFF2D5D7C),
      },
      {
        'label': 'Low stock items',
        'icon': Icons.warning,
        'action': () {
          _messageController.text = 'What items are running low in my inventory?';
          _sendMessage();
        },
        'color': Colors.orange,
      },
      {
        'label': 'Add an item',
        'icon': Icons.add_circle,
        'action': () {
          Navigator.pushNamed(context, '/add_item');
        },
        'color': Colors.green,
      },
      {
        'label': 'Expiring soon',
        'icon': Icons.calendar_today,
        'action': () {
          _messageController.text = 'What items are expiring soon?';
          _sendMessage();
        },
        'color': Colors.red,
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((action) {
              return ActionChip(
                label: Text(action['label']),
                avatar: Icon(action['icon'], size: 18, color: action['color']),
                onPressed: action['action'],
                backgroundColor: action['color'].withOpacity(0.1),
                labelStyle: TextStyle(color: action['color']),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (!_isConnected) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.orange[50],
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'No internet connection',
              style: TextStyle(color: Colors.orange[800], fontSize: 12),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildTypingIndicator() {
    return Padding(
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
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white),
            onPressed: () async {
              try {
                // Check microphone permission first
                final hasPermission = await _checkMicrophonePermission();
                if (!hasPermission) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Microphone permission is required for voice input')),
                  );
                  return;
                }

                setState(() {
                  _isListening = true;
                });
                
                // Show a dialog or indicator that we're listening
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Listening..."),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Speak now"),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            SpeechService.stopListening();
                            setState(() {
                              _isListening = false;
                            });
                          },
                          child: Text("Cancel"),
                        ),
                      ],
                    );
                  },
                );
                
                final String speechResult = await SpeechService.getSpeechInput(context);
                
                // Dismiss the dialog
                Navigator.of(context).pop();
                
                setState(() {
                  _isListening = false;
                });
                
                if (speechResult.isNotEmpty) {
                  _messageController.text = speechResult;
                  _sendMessage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No speech recognized. Please try again.')),
                  );
                }
              } catch (e) {
                // Dismiss the dialog if it's still open
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                
                setState(() {
                  _isListening = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Voice input failed: ${e.toString()}')),
                );
              }
            },
            tooltip: 'Voice input',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
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
            _buildConnectionStatus(),
            _buildQuickActions(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16.0),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final message = _messages[index];
                    return ChatBubble(
                      text: message.text,
                      isUser: message.sender == 'user',
                      timestamp: message.timestamp,
                      isError: message.isError,
                    );
                  } else {
                    return _buildTypingIndicator();
                  }
                },
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
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Ask about your inventory...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        maxLength: 500,
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

class ChatMessage {
  final String text;
  final String sender;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isError = false,
  });
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const ChatBubble({
    Key? key, 
    required this.text, 
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  }) : super(key: key);

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays < 1) {
      return timeago.format(dateTime, locale: 'en');
    } else {
      return DateFormat('MMM d, y • HH:mm').format(dateTime);
    }
  }

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
                color: isError ? Colors.red : Color(0xFF2D5D7C),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error : Icons.inventory_2, 
                color: Colors.white, 
                size: 18
              ),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isUser 
                  ? Color(0xFF2D5D7C) 
                  : (isError ? Colors.red[50] : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: isUser ? Radius.circular(20) : Radius.circular(4),
                  bottomRight: isUser ? Radius.circular(4) : Radius.circular(20),
                ),
                border: isError 
                  ? Border.all(color: Colors.red.withOpacity(0.3))
                  : null,
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
                      color: isUser 
                        ? Colors.white 
                        : (isError ? Colors.red[800] : Colors.black87),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      color: isUser 
                        ? Colors.white70 
                        : (isError ? Colors.red[600] : Colors.grey[600]),
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