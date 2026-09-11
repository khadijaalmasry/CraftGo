import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserName;
  final bool isArabic;
  final bool isDarkMode;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserName,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF0F2F5);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white54 : Colors.black45;
  Color get accent => const Color(0xFFD4A017);
  Color get bubbleMe => const Color(0xFFD4A017);
  Color get bubbleOther => widget.isDarkMode ? const Color(0xFF253040) : const Color(0xFFE8EBF0);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    ChatService.connectSocket(
      chatId: widget.chatId,
      onMessage: (msg) {
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      },
    );
  }

  @override
  void dispose() {
    ChatService.disconnectSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final msgs = await ChatService.getMessages(widget.chatId);
    if (mounted) {
      setState(() {
        _messages.addAll(msgs.cast<Map<String, dynamic>>());
        _isLoading = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    _messageController.clear();

    final saved = await ChatService.sendMessage(
      chatId: widget.chatId,
      content: content,
    );
    if (saved != null && mounted) {
      final id = saved['id']?.toString() ?? '';
      final alreadyExists = _messages.any((m) => m['id']?.toString() == id);
      if (!alreadyExists) {
        setState(() => _messages.add(saved));
        _scrollToBottom();
      }
    }
  }

  bool _isMe(Map<String, dynamic> msg) => msg['senderId'] == widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Icon(Icons.person, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t('���� ����', 'Online'),
                        style: GoogleFonts.cairo(color: Colors.green, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Messages Area
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: dim, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                t('�� ���� ����� ���\n���� �������� ����!', 'No messages yet.\nStart the conversation!'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(color: dim, fontSize: 14, height: 1.6),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = _isMe(msg);
                            final content = msg['content']?.toString() ?? '';
                            final time = msg['createdAt'] != null
                                ? DateTime.tryParse(msg['createdAt'].toString())
                                : null;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? bubbleMe : bubbleOther,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      content,
                                      style: GoogleFonts.cairo(
                                        color: isMe ? Colors.black87 : text,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (time != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.cairo(
                                          color: isMe
                                              ? Colors.black45
                                              : dim,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Input Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: text, fontSize: 14),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: t('���� �����...', 'Type a message...'),
                            hintStyle: GoogleFonts.cairo(color: dim, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8B84B), Color(0xFFD4A017)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isArabic ? Icons.send : Icons.send,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
