import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/ai_service.dart';
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
  bool _showQuickActions = true;

  // Enhanced Color Palette
  final Color _primaryColor = Color(0xFF2D5D7C); // More vibrant blue
  final Color _secondaryColor = Color(0xFF2D5D7C);
  final Color _accentColor = Color(0xFF10B981); // Emerald green
  final Color _warningColor = Color(0xFFF59E0B); // Amber
  final Color _errorColor = Color(0xFFEF4444); // Red
  final Color _textPrimary = Color(0xFF1F2937); // Almost black
  final Color _textSecondary = Color(0xFF6B7280); // Gray
  final Color _textLight = Color(0xFF9CA3AF); // Light gray
  final Color _backgroundLight = Color(0xFFF9FAFB); // Very light gray

  // Typography Scale
  final double _fontSizeLarge = 18.0;
  final double _fontSizeMedium = 16.0;
  final double _fontSizeSmall = 14.0;
  final double _fontSizeXSmall = 12.0;

  @override
  void initState() {
    super.initState();
    
    timeago.setLocaleMessages('en', timeago.EnMessages());
    
    // Enhanced welcome message with better formatting
    _messages.add(ChatMessage(
      text: 'Hello! I\'m your inventory assistant. I can help you manage your household items. \n\n🔍 **What you can ask me:**\n• Items currently in stock\n• Low inventory alerts  \n• Expiration dates tracking\n• Adding new items to inventory\n• Search specific products',
      sender: 'ai',
      timestamp: DateTime.now(),
    ));
    
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _typingAnimation = CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    );
    
    _checkConnection();
    
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
    FocusScope.of(context).unfocus();
    
    if (_showQuickActions) {
      setState(() {
        _showQuickActions = false;
      });
    }
    
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        sender: 'user',
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      if (!_isConnected) {
        throw Exception('No internet connection');
      }
      
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

  Widget _buildQuickActions() {
    if (!_showQuickActions) return SizedBox.shrink();

    final List<Map<String, dynamic>> actions = [
      {
        'label': 'Show All Items',
        'icon': Icons.inventory_2_rounded,
        'action': () {
          _messageController.text = 'What items do I have in my inventory?';
          _sendMessage();
        },
        'color': _primaryColor,
      },
      {
        'label': 'Low Stock',
        'icon': Icons.warning_amber_rounded,
        'action': () {
          _messageController.text = 'What items are running low in my inventory?';
          _sendMessage();
        },
        'color': _warningColor,
      },
      {
        'label': 'Add Item',
        'icon': Icons.add_circle_outline_rounded,
        'action': () {
          Navigator.pushNamed(context, '/add_item');
        },
        'color': _accentColor,
      },
      {
        'label': 'Expiring Soon',
        'icon': Icons.calendar_today_rounded,
        'action': () {
          _messageController.text = 'What items are expiring soon?';
          _sendMessage();
        },
        'color': _errorColor,
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: _primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  fontSize: _fontSizeLarge,
                  letterSpacing: -0.3,
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showQuickActions = false;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _textLight.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: _textSecondary, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions.map((action) {
              return Container(
                decoration: BoxDecoration(
                  color: action['color'].withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: action['color'].withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: action['action'],
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(action['icon'], 
                            size: 18, 
                            color: action['color']
                          ),
                          SizedBox(width: 8),
                          Text(
                            action['label'],
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: _fontSizeSmall,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: _warningColor.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(
              color: _warningColor.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 18, color: _warningColor),
            SizedBox(width: 10),
            Text(
              'No internet connection',
              style: TextStyle(
                color: _warningColor,
                fontSize: _fontSizeSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Searching your inventory...',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: _fontSizeSmall,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Voice input button
          Container(
            margin: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isListening ? _errorColor : _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.white : _primaryColor,
                size: 22,
              ),
              onPressed: _handleVoiceInput,
              tooltip: 'Voice input',
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: _fontSizeMedium,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about your inventory...',
                  hintStyle: TextStyle(
                    color: _textLight,
                    fontSize: _fontSizeMedium,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                maxLines: 3,
                minLines: 1,
                maxLength: 500,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          
          // Send button
          Container(
            margin: EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: Colors.white, size: 22),
              onPressed: _sendMessage,
              tooltip: 'Send message',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVoiceInput() async {
    try {
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        _showSnackBar('Microphone permission is required for voice input');
        return;
      }

      setState(() {
        _isListening = true;
      });
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _VoiceInputDialog(
            onCancel: () {
              Navigator.of(context).pop();
              SpeechService.stopListening();
              setState(() {
                _isListening = false;
              });
            },
          );
        },
      );
      
      final String speechResult = await SpeechService.getSpeechInput(context);
      
      Navigator.of(context).pop();
      
      setState(() {
        _isListening = false;
      });
      
      if (speechResult.isNotEmpty) {
        _messageController.text = speechResult;
        _sendMessage();
      } else {
        _showSnackBar('No speech recognized. Please try again.');
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isListening = false;
      });
      
      _showSnackBar('Voice input failed: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: _fontSizeSmall,
          ),
        ),
        backgroundColor: _textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_rounded, size: 22),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _fontSizeLarge,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Always here to help',
                  style: TextStyle(
                    fontSize: _fontSizeXSmall,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              Future.delayed(Duration(seconds: 1), () {
                setState(() {
                  _isLoading = false;
                });
                _showSnackBar('Inventory data refreshed');
              });
            },
            tooltip: 'Refresh inventory data',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          _buildQuickActions(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _primaryColor.withOpacity(0.02),
                  ],
                ),
              ),
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
                      primaryColor: _primaryColor,
                      accentColor: _accentColor,
                      errorColor: _errorColor,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                      textLight: _textLight,
                      fontSizeMedium: _fontSizeMedium,
                      fontSizeSmall: _fontSizeSmall,
                      fontSizeXSmall: _fontSizeXSmall,
                    );
                  } else {
                    return _buildTypingIndicator();
                  }
                },
              ),
            ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }
}

class _VoiceInputDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const _VoiceInputDialog({required this.onCancel});

  @override
  __VoiceInputDialogState createState() => __VoiceInputDialogState();
}

class __VoiceInputDialogState extends State<_VoiceInputDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF2563EB).withOpacity(0.4),
                        blurRadius: 15 + (_animation.value * 15),
                        spreadRadius: _animation.value * 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
            SizedBox(height: 24),
            Text(
              "Listening...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Speak now to ask about your inventory",
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
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
  final Color primaryColor;
  final Color accentColor;
  final Color errorColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final double fontSizeMedium;
  final double fontSizeSmall;
  final double fontSizeXSmall;

  const ChatBubble({
    Key? key, 
    required this.text, 
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    required this.primaryColor,
    required this.accentColor,
    required this.errorColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.fontSizeMedium,
    required this.fontSizeSmall,
    required this.fontSizeXSmall,
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
              width: 40,
              height: 40,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isError 
                    ? [errorColor, Color(0xFFDC2626)] 
                    : [primaryColor, accentColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isError ? errorColor : primaryColor).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.inventory_2_rounded, 
                color: Colors.white, 
                size: 20
              ),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                gradient: isUser 
                  ? LinearGradient(
                      colors: [primaryColor, accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : (isError 
                      ? LinearGradient(
                          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                        )
                      : LinearGradient(
                          colors: [Colors.white, Color(0xFFF9FAFB)],
                        )),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: isUser ? Radius.circular(24) : Radius.circular(8),
                  bottomRight: isUser ? Radius.circular(8) : Radius.circular(24),
                ),
                border: isError 
                  ? Border.all(color: errorColor.withOpacity(0.2), width: 1.5)
                  : Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: Offset(0, 4),
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
                        : (isError ? errorColor : textPrimary),
                      fontSize: fontSizeMedium,
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      color: isUser 
                        ? Colors.white.withOpacity(0.9) 
                        : (isError ? errorColor.withOpacity(0.7) : textLight),
                      fontSize: fontSizeXSmall,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) 
            Container(
              width: 40,
              height: 40,
              margin: EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, primaryColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }
}