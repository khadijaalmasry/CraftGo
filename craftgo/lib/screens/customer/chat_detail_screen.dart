// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../services/craftsman_service.dart';
import '../../services/session_service.dart';
import '../../services/upload_service.dart';
import 'artisan_profile_page.dart';
import 'customer_public_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatDetailScreen
//
// Displays a real chat conversation loaded from the backend.
// - No mock messages.
// - isMe is determined by comparing message.senderId to currentUserId.
// - createdAt from backend is formatted properly (no "Now" string).
// - Loading / Empty / Error states are all handled.
// - Sending is disabled while a message is in flight.
// - Messages are added to UI only after a successful backend response.
// - Socket.io listens for newMessage events to receive replies in real-time.
// - Socket is disconnected in dispose().
// ─────────────────────────────────────────────────────────────────────────────

class ChatDetailScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  // ── Real IDs (required for API calls) ────────────────────────────────────
  final String chatId;
  final String currentUserId;

  final String otherUserId;
  final bool openCustomerProfile;

  // ── Display data (shown in AppBar / order card) ───────────────────────────
  final String name;
  final String? avatarUrl;
  final String craft;
  final bool online;
  final String orderTitle;
  final String orderStatus;
  final String orderPrice;

  const ChatDetailScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.chatId,
    required this.currentUserId,
    this.otherUserId = '',
    this.openCustomerProfile = false,
    required this.name,
    required this.craft,
    required this.online,
    required this.orderTitle,
    required this.orderStatus,
    required this.orderPrice,
    this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _loadError;
  String _currentUserId = '';

  // ── Theme colors ────────────────────────────────────────────────────────
  Color get backgroundColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get primaryTextColor =>
      widget.isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor =>
      widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get cardBorderColor => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get bubbleOtherColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  String get orderStatusLabel {
    switch (widget.orderStatus) {
      case 'bidding':
        return t('قيد العروض', 'Bidding');
      case 'in_progress':
        return t('قيد التنفيذ', 'In Progress');
      case 'completed':
        return t('مكتمل', 'Completed');
      case 'pending':
        return t('قيد الانتظار', 'Pending');
      case 'accepted':
        return t('مقبول', 'Accepted');
      case 'cancelled':
        return t('ملغى', 'Cancelled');
      default:
        return widget.orderStatus;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    _init();
  }

  Future<void> _init() async {
    // If currentUserId wasn't passed, try reading from session
    if (_currentUserId.isEmpty) {
      final id = await SessionService.getUserId();
      if (mounted) setState(() => _currentUserId = id ?? '');
    }
    await _fetchMessages();
    _connectSocket();
    // Mark messages as read when entering the chat
    await ChatService.markChatAsRead(widget.chatId);
  }

  Future<void> _fetchMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final raw = await ChatService.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  void _connectSocket() {
    ChatService.connectSocket(
      chatId: widget.chatId,
      onMessage: (data) {
        if (!mounted) return;
        final msgId = data['id']?.toString() ?? '';
        // Prevent duplicates (REST response + socket event)
        final alreadyExists =
        _messages.any((m) => m['id']?.toString() == msgId);
        if (!alreadyExists && msgId.isNotEmpty) {
          setState(() => _messages.add(data));
          _scrollToBottom();
        }
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ChatService.disconnectSocket();
    super.dispose();
  }

  // ── Send message via REST, add to UI on success ─────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final saved = await ChatService.sendMessage(
        chatId: widget.chatId,
        content: text,
      );

      if (!mounted) return;

      if (saved != null) {
        // Only add if socket didn't already deliver it
        final id = saved['id']?.toString() ?? '';
        final alreadyExists =
        _messages.any((m) => m['id']?.toString() == id);
        if (!alreadyExists) {
          setState(() => _messages.add(saved));
          _scrollToBottom();
        }
      } else {
        // Restore the text so the user can try again
        _messageController.text = text;
        _showError(t('فشل إرسال الرسالة', 'Failed to send message'));
      }
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      _showError(t('حدث خطأ', 'An error occurred'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _isImageMessage(String content) {
    final uri = Uri.tryParse(content.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return false;
    }

    final path = uri.path.toLowerCase();
    return path.contains('/uploads/') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage || _isSending) return;

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (pickedImage == null || !mounted) return;

      setState(() => _isUploadingImage = true);

      final imageUrl = await UploadService.uploadImage(pickedImage);

      if (!mounted) return;

      if (imageUrl == null || imageUrl.trim().isEmpty) {
        _showError(t('فشل رفع الصورة', 'Failed to upload image'));
        return;
      }

      final saved = await ChatService.sendMessage(
        chatId: widget.chatId,
        content: imageUrl.trim(),
      );

      if (!mounted) return;

      if (saved == null) {
        _showError(t('فشل إرسال الصورة', 'Failed to send image'));
        return;
      }

      final id = saved['id']?.toString() ?? '';
      final alreadyExists =
      _messages.any((message) => message['id']?.toString() == id);

      if (!alreadyExists) {
        setState(() => _messages.add(saved));
        _scrollToBottom();
      }
    } catch (error) {
      debugPrint('[ChatDetailScreen] Image send error: $error');

      if (mounted) {
        _showError(
          t(
            'تعذر اختيار أو إرسال الصورة',
            'Could not select or send the image',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openOtherUserProfile() async {
    final otherUserId = widget.otherUserId.trim();

    if (otherUserId.isEmpty || !mounted) {
      return;
    }

    try {
      final roles = await SessionService.getRoles();
      final isCraftsman = roles.any(
            (role) =>
        role.toLowerCase() == 'craftsman' ||
            role.toLowerCase() == 'artisan',
      );

      if (!mounted) return;

      if (isCraftsman || widget.openCustomerProfile) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerPublicProfile(
              customerId: otherUserId,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
        return;
      }

      Map<String, dynamic>? artisan =
      await CraftsmanService.getProfile(otherUserId);

      if (artisan == null || artisan.isEmpty) {
        final response = await ApiService.get('/auth/user/$otherUserId');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            artisan = Map<String, dynamic>.from(decoded);
          }
        }
      }

      if (!mounted) return;

      if (artisan == null || artisan.isEmpty) {
        _showError(
          t(
            'تعذر تحميل ملف الحرفي',
            'Could not load the craftsman profile',
          ),
        );
        return;
      }

      final normalizedArtisan = <String, dynamic>{
        ...artisan,
        'id': (artisan['id'] ?? otherUserId).toString(),
        'artisanId': (artisan['artisanId'] ?? artisan['id'] ?? otherUserId)
            .toString(),
        'nameAr': (artisan['nameAr'] ?? artisan['name'] ?? widget.name)
            .toString(),
        'nameEn': (artisan['nameEn'] ?? artisan['name'] ?? widget.name)
            .toString(),
        'craftAr': (artisan['craftAr'] ??
            artisan['craft'] ??
            artisan['category'] ??
            widget.craft)
            .toString(),
        'craftEn': (artisan['craftEn'] ??
            artisan['craft'] ??
            artisan['category'] ??
            widget.craft)
            .toString(),
        'image': (artisan['image'] ??
            artisan['profileImage'] ??
            artisan['imageUrl'] ??
            widget.avatarUrl ??
            '')
            .toString(),
      };

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtisanProfilePage(
            artisan: normalizedArtisan,
            isArabic: widget.isArabic,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } catch (error) {
      debugPrint('[ChatDetailScreen] Open profile error: $error');

      if (mounted) {
        _showError(
          t(
            'تعذر فتح الملف الشخصي',
            'Could not open the profile',
          ),
        );
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Format timestamp ─────────────────────────────────────────────────────
  String _formatTime(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    final dt = DateTime.tryParse(text)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? t('م', 'PM') : t('ص', 'AM');
    return '$h:$m $period';
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(child: CircularProgressIndicator(color: accent));
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 72, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 20),
            Text(
              t('تعذّر تحميل الرسائل', 'Could not load messages'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchMessages,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(t('إعادة المحاولة', 'Retry'),
                  style: GoogleFonts.cairo(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 72, color: accent.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            t('لا توجد رسائل بعد', 'No messages yet'),
            style: GoogleFonts.cairo(
                color: secondaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            t('ابدأ المحادثة الآن!', 'Start the conversation now!'),
            style: GoogleFonts.cairo(color: secondaryTextColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final senderId =
        (msg['senderId'] ?? msg['sender']?['id'] ?? '').toString();
        final isMe = _currentUserId.isNotEmpty && senderId == _currentUserId;
        final content = (msg['content'] ?? '').toString();
        final time = _formatTime(msg['createdAt']);

        return _MessageBubble(
          text: content,
          imageUrl: _isImageMessage(content) ? content : null,
          isMe: isMe,
          time: time,
          accent: accent,
          primaryText: primaryTextColor,
          bubbleOther: bubbleOtherColor,
          border: cardBorderColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = widget.isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,

        // ── AppBar ────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: primaryTextColor,
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          ),
          titleSpacing: 0,
          title: InkWell(
            onTap: widget.otherUserId.trim().isNotEmpty
                ? _openOtherUserProfile
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      backgroundImage: (widget.avatarUrl != null &&
                          widget.avatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      onBackgroundImageError: (widget.avatarUrl != null &&
                          widget.avatarUrl!.isNotEmpty)
                          ? (_, __) {}
                          : null,
                      child: (widget.avatarUrl == null ||
                          widget.avatarUrl!.isEmpty)
                          ? Text(
                        widget.name.isNotEmpty ? widget.name[0] : '?',
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                    if (widget.online)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: backgroundColor, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.online
                            ? t('متصل الآن', 'Online now')
                            : widget.craft,
                        style: TextStyle(
                            color: widget.online
                                ? Colors.green
                                : secondaryTextColor,
                            fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: primaryTextColor),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),

        body: Column(
          children: [
            // ── Order shortcut card ───────────────────────────────────────
            if (widget.orderTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.orderTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (widget.orderStatus.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      orderStatusLabel,
                                      style: TextStyle(
                                          color: accent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                if (widget.orderPrice.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.orderPrice,
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6)),
                        child: Text(
                          t('عرض', 'View'),
                          style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Messages area ─────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _loadError != null
                  ? _buildErrorState()
                  : _buildMessageList(),
            ),

            // ── Input bar ─────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: cardBorderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: t('إرسال صورة', 'Send image'),
                    icon: _isUploadingImage
                        ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                        : Icon(
                      Icons.add_photo_alternate_outlined,
                      color: secondaryTextColor,
                    ),
                    onPressed: (_isUploadingImage || _isSending)
                        ? null
                        : _pickAndSendImage,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: primaryTextColor),
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSending,
                        decoration: InputDecoration(
                          hintText:
                          t('اكتب رسالة...', 'Type a message...'),
                          hintStyle: TextStyle(
                              color: secondaryTextColor.withValues(alpha: 0.6)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isSending
                            ? LinearGradient(colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade400
                        ])
                            : const LinearGradient(
                          colors: [
                            Color(0xFFF7B500),
                            Color(0xFFD89A00),
                          ],
                        ),
                      ),
                      child: _isSending
                          ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                          : const Icon(Icons.send_rounded,
                          color: Colors.black, size: 20),
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

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMe;
  final String time;
  final Color accent;
  final Color primaryText;
  final Color bubbleOther;
  final Color border;

  const _MessageBubble({
    required this.text,
    required this.imageUrl,
    required this.isMe,
    required this.time,
    required this.accent,
    required this.primaryText,
    required this.bubbleOther,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? accent : bubbleOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 140,
                    maxWidth: 240,
                    maxHeight: 300,
                  ),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isMe ? Colors.black54 : accent,
                            value: progress.expectedTotalBytes == null
                                ? null
                                : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 180,
                      height: 120,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: isMe ? Colors.black54 : primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.black : primaryText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                time,
                style: TextStyle(
                    color: isMe
                        ? Colors.black54
                        : primaryText.withValues(alpha: 0.5),
                    fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
