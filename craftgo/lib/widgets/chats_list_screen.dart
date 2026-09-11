import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  final String currentUserId;
  final bool isArabic;
  final bool isDarkMode;

  const ChatsListScreen({
    super.key,
    required this.currentUserId,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white54 : Colors.black45;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.07);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  late Future<List<dynamic>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = ChatService.getMyChats();
  }

  String _getOtherName(Map<String, dynamic> chat) {
    final customer = chat['Customer'];
    final craftsman = chat['Craftsman'];
    if (customer != null && customer['id'] != widget.currentUserId) {
      return customer['name'] ?? t('مستخدم', 'User');
    }
    if (craftsman != null) {
      return craftsman['name'] ?? t('حرفي', 'Craftsman');
    }
    return t('مستخدم', 'User');
  }

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
          title: Text(
            t('المحادثات', 'Chats'),
            style: GoogleFonts.cairo(
                color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: accent));
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, color: dim, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      t('لا توجد محادثات بعد', 'No chats yet'),
                      style: GoogleFonts.cairo(
                          color: dim,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('ابدأ الدردشة مع الحرفيين!',
                          'Start chatting with craftsmen!'),
                      style: GoogleFonts.cairo(color: dim, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            final chats = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              separatorBuilder: (_, __) => Divider(
                color: border,
                height: 1,
                indent: 80,
              ),
              itemBuilder: (context, index) {
                final chat = chats[index] as Map<String, dynamic>;
                final otherName = _getOtherName(chat);
                final lastMsg = chat['lastMessage']?.toString() ??
                    t('ابدأ الدردشة', 'Start chatting');

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: GoogleFonts.cairo(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    otherName,
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    lastMsg,
                    style: GoogleFonts.cairo(color: dim, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chat['id'].toString(),
                        currentUserId: widget.currentUserId,
                        otherUserName: otherName,
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
