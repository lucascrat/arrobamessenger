import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final User contact;
  final String currentUserId;
  
  const ChatScreen({super.key, required this.contact, required this.currentUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _setupSocket();
  }

  Future<void> _loadHistory() async {
    final history = await ApiService.getMessages(widget.currentUserId, widget.contact.id);
    if (mounted) {
      setState(() {
        _messages = history.map((msg) => {
          'text': msg['content'],
          'isMe': msg['senderId'] == widget.currentUserId,
          'time': _formatTime(DateTime.parse(msg['timestamp'])),
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _setupSocket() {
    _socketService.connectAndJoin(widget.currentUserId, widget.contact.id, (data) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': data['content'],
            'isMe': data['senderId'] == widget.currentUserId,
            'time': _formatTime(DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String())),
          });
        });
      }
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Send via socket
    _socketService.sendMessage(widget.currentUserId, widget.contact.id, text);
    
    // Add locally immediately for better UX
    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _formatTime(DateTime.now()),
      });
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFEDE9FE),
              child: Text(widget.contact.username[0].toUpperCase(), style: const TextStyle(fontSize: 14, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${widget.contact.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true, // we reverse it to keep newest at bottom visually if we build list differently, or just use normal if list is chronological.
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['isMe'];
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF7C3AED) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['text'],
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              msg['time'],
              style: TextStyle(color: isMe ? Colors.white70 : Colors.black45, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add, color: Color(0xFF7C3AED)), onPressed: () {}),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Sua mensagem...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF7C3AED),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
