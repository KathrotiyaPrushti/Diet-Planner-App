import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  final TextEditingController _textController = TextEditingController();
  final String _geminiApiKey = 'AIzaSyCZxC0X6ZFE_k4PX8oQjoKBxrwCuBdJj0w';
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: "Hello! I'm your Diet Planning Assistant. How can I help you today?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Status: $status'),
      onError: (error) => print('Error: $error'),
    );
    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) => setState(() {
            _lastWords = result.recognizedWords;
            _textController.text = _lastWords;
          }),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
      _textController.clear();
    });

    try {
      String response = await _getGeminiResponse(text);
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<String> _getGeminiResponse(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey',
    );

    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      "contents": [
        {"parts": [{"text": prompt}]}
      ],
      "generationConfig": {
        "temperature": 0.9,
        "topK": 1,
        "topP": 1,
        "maxOutputTokens": 2048,
      }
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "I couldn't generate a response. Please try again.";
      }
    } else {
      throw Exception('Failed to get AI response: ${response.statusCode}');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.height <= 462;
    final padding = isVerySmallScreen ? 4.0 : 8.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isVerySmallScreen ? 40.0 : 56.0),
        child: AppBar(
          title: Text(
            'Diet Planner',
            style: TextStyle(
              color: Colors.white,
              fontSize: isVerySmallScreen ? 16 : 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFD8BFD8),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              iconSize: isVerySmallScreen ? 18 : 22,
              padding: EdgeInsets.all(padding),
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.white,
                size: isVerySmallScreen ? 18 : 22,
              ),
              onPressed: _toggleListening,
              padding: EdgeInsets.all(padding),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFFFE4E1),
              child: ListView.builder(
                reverse: true,
                padding: EdgeInsets.all(padding),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0 && _isLoading) {
                    return Padding(
                      padding: EdgeInsets.all(padding),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final messageIndex = _isLoading ? index - 1 : index;
                  return Padding(
                    padding: EdgeInsets.only(bottom: padding / 2),
                    child: _messages[messageIndex],
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFADADD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: padding / 2,
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: isVerySmallScreen ? 32 : 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : 16),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening...' : 'Type a message...',
                          hintStyle: TextStyle(fontSize: isVerySmallScreen ? 12 : 14),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: padding * 2,
                            vertical: isVerySmallScreen ? 6 : 8,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(fontSize: isVerySmallScreen ? 12 : 14),
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                      ),
                    ),
                  ),
                  SizedBox(width: padding / 2),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      size: isVerySmallScreen ? 18 : 22,
                      color: const Color(0xFFD8BFD8),
                    ),
                    onPressed: () => _handleSubmitted(_textController.text),
                    padding: EdgeInsets.all(padding),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.height <= 462;
    final maxWidth = screenSize.width * (isVerySmallScreen ? 0.65 : 0.7);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(isVerySmallScreen ? 6 : 8),
        margin: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 2 : 4,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFD8BFD8) : Colors.white,
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : 12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 11 : 13,
                color: isUser ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: isVerySmallScreen ? 8 : 9,
                color: isUser 
                    ? Colors.white.withOpacity(0.7) 
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 