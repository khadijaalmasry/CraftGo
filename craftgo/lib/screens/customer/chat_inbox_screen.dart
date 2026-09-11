import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/chat_service.dart';
import '../../services/session_service.dart';
import 'chat_detail_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  /// Pass the logged-in user's real backend id.
  /// Kept optional so existing screen calls do not break.
  final String userId;

  const ChatInboxScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.userId = '',
  });

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  bool _unreadOnly = false;
  String _searchQuery = '';
  String? _loadError;
  String _resolvedUserId = '';

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

  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final passedId = widget.userId.trim();
    final sessionId = passedId.isNotEmpty
        ? passedId
        : (await SessionService.getUserId() ?? '').trim();

    if (!mounted) return;

    setState(() {
      _resolvedUserId = sessionId;
    });

    await _loadChats();
  }

  @override
  void didUpdateWidget(covariant ChatInboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    // userId is validated server-side via JWT — no client-side check needed.

    try {
      final rawChats = await ChatService.getMyChats();

      if (!mounted) return;

      final normalized = rawChats
          .whereType<Map>()
          .map((raw) => _normalizeChat(Map<String, dynamic>.from(raw)))
          .where((chat) => chat['id'].toString().trim().isNotEmpty)
          .toList();

      normalized.sort((a, b) {
        final aDate = a['updatedAt'] as DateTime?;
        final bDate = b['updatedAt'] as DateTime?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _chats = normalized;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chats = [];
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Map<String, dynamic> _normalizeChat(Map<String, dynamic> raw) {
    final customer = _asMap(raw['customer']);
    final craftsman = _asMap(raw['craftsman']);
    final artisan = _asMap(raw['artisan']);
    final otherUser = _asMap(raw['otherUser']);
    final lastMessageMap = _asMap(raw['lastMessage']);
    final order = _asMap(raw['order']);
    final customOrder = _asMap(raw['customOrder']);

    final currentUserId = _resolvedUserId.trim();

    Map<String, dynamic> participant = otherUser;

    if (participant.isEmpty) {
      final customerId =
      (customer['id'] ?? raw['customerId'] ?? '').toString();
      final craftsmanId =
      (craftsman['id'] ??
          artisan['id'] ??
          raw['craftsmanId'] ??
          raw['artisanId'] ??
          '')
          .toString();

      if (currentUserId.isNotEmpty && customerId == currentUserId) {
        participant = craftsman.isNotEmpty ? craftsman : artisan;
      } else if (currentUserId.isNotEmpty && craftsmanId == currentUserId) {
        participant = customer;
      } else if (customer.isNotEmpty) {
        participant = customer;
      } else if (craftsman.isNotEmpty) {
        participant = craftsman;
      } else {
        participant = artisan;
      }
    }

    final name = _firstNonEmpty([
      participant['name'],
      participant['fullName'],
      participant['username'],
      raw['otherUserName'],
      raw['name'],
      t('مستخدم', 'User'),
    ]);

    final avatar = _firstNonEmpty([
      participant['profileImage'],
      participant['avatar'],
      participant['imageUrl'],
      raw['avatar'],
    ]);

    final lastMessage = _firstNonEmpty([
      lastMessageMap['content'],
      lastMessageMap['text'],
      lastMessageMap['message'],
      raw['lastMessageText'],
      raw['lastMessage'],
      t('لا توجد رسائل بعد', 'No messages yet'),
    ]);

    final unread = _toInt(
      raw['unreadCount'] ??
          raw['unread'] ??
          raw['unreadMessages'] ??
          raw['newMessages'],
    );

    final online =
        participant['online'] == true ||
            participant['isOnline'] == true ||
            raw['online'] == true;

    final orderData = order.isNotEmpty ? order : customOrder;

    final orderTitle = _firstNonEmpty([
      orderData['title'],
      orderData['productName'],
      orderData['name'],
      raw['orderTitle'],
      raw['subject'],
    ]);

    final orderStatus = _firstNonEmpty([
      orderData['status'],
      raw['orderStatus'],
      '',
    ]);

    final orderPriceValue =
        orderData['price'] ??
            orderData['totalPrice'] ??
            raw['orderPrice'];

    final orderPrice = orderPriceValue == null
        ? ''
        : orderPriceValue.toString().contains('JOD')
        ? orderPriceValue.toString()
        : '${orderPriceValue.toString()} JOD';

    final craft = _firstNonEmpty([
      participant['craftCategory'],
      participant['category'],
      participant['craft'],
      raw['craft'],
      t('محادثة', 'Conversation'),
    ]);

    final updatedAt = _parseDate(
      lastMessageMap['createdAt'] ??
          raw['updatedAt'] ??
          raw['lastMessageAt'] ??
          raw['createdAt'],
    );

    return {
      'id': (raw['id'] ?? raw['_id'] ?? raw['chatId'] ?? '').toString(),
      'participantId': (participant['id'] ?? '').toString(),
      'name': name,
      'avatar': avatar,
      'lastMessage': lastMessage,
      'unread': unread,
      'online': online,
      'craft': craft,
      'orderTitle': orderTitle,
      'orderStatus': orderStatus,
      'orderPrice': orderPrice,
      'updatedAt': updatedAt,
      'time': _formatChatTime(updatedAt),
      'raw': raw,
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  String _formatChatTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12
          ? t('م', 'PM')
          : t('ص', 'AM');
      return '$hour:$minute $period';
    }

    if (difference == 1) {
      return t('أمس', 'Yesterday');
    }

    return widget.isArabic
        ? '${date.day}/${date.month}/${date.year}'
        : '${date.month}/${date.day}/${date.year}';
  }

  List<Map<String, dynamic>> get _filteredChats {
    Iterable<Map<String, dynamic>> result = _chats;

    if (_unreadOnly) {
      result = result.where((chat) => (chat['unread'] as int) > 0);
    }

    final query = _searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((chat) {
        final name = chat['name'].toString().toLowerCase();
        final lastMessage =
        chat['lastMessage'].toString().toLowerCase();
        final orderTitle =
        chat['orderTitle'].toString().toLowerCase();

        return name.contains(query) ||
            lastMessage.contains(query) ||
            orderTitle.contains(query);
      });
    }

    return result.toList();
  }

  int get _unreadCount =>
      _chats.where((chat) => (chat['unread'] as int) > 0).length;

  Future<void> _openChat(Map<String, dynamic> chat) async {
    final chatIndex = _chats.indexWhere(
          (item) => item['id'].toString() == chat['id'].toString(),
    );

    if (chatIndex != -1 && (_chats[chatIndex]['unread'] as int) > 0) {
      setState(() => _chats[chatIndex]['unread'] = 0);
    }

    // Determine the other user's ID from raw chat data
    final raw = _asMap(chat['raw']);
    final currentUserId = _resolvedUserId.trim();
    final customer = _asMap(raw['customer']);
    final craftsman = _asMap(raw['craftsman']);
    final artisan = _asMap(raw['artisan']);
    final otherUser = _asMap(raw['otherUser']);

    final customerId =
    (raw['customerId'] ?? customer['id'] ?? '').toString();
    final craftsmanId = (
        raw['craftsmanId'] ??
            raw['artisanId'] ??
            craftsman['id'] ??
            artisan['id'] ??
            ''
    ).toString();

    final participantId = (
        chat['participantId'] ??
            otherUser['id'] ??
            ''
    ).toString();

    final currentUserIsCraftsman =
        currentUserId.isNotEmpty && currentUserId == craftsmanId;

    final otherUserId = currentUserIsCraftsman
        ? customerId
        : (craftsmanId.isNotEmpty ? craftsmanId : participantId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          chatId: chat['id'].toString(),
          currentUserId: currentUserId,
          otherUserId: otherUserId,
          openCustomerProfile: currentUserIsCraftsman,
          name: chat['name'].toString(),
          avatarUrl: chat['avatar'].toString().isEmpty ? null : chat['avatar'].toString(),
          craft: chat['craft'].toString(),
          online: chat['online'] == true,
          orderTitle: chat['orderTitle'].toString(),
          orderStatus: chat['orderStatus'].toString(),
          orderPrice: chat['orderPrice'].toString(),
        ),
      ),
    );

    if (mounted) {
      await _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction =
    widget.isArabic ? TextDirection.rtl : TextDirection.ltr;
    final filtered = _filteredChats;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: Navigator.canPop(context)
            ? AppBar(
                backgroundColor: backgroundColor,
                foregroundColor: primaryTextColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    widget.isArabic ? Icons.arrow_forward : Icons.arrow_back,
                    color: primaryTextColor,
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(
                  t('الرسائل', 'Chats'),
                  style: GoogleFonts.cairo(
                    color: primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: t('تحديث', 'Refresh'),
                    onPressed: _loading ? null : _loadChats,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                textDirection: direction,
                textAlign:
                widget.isArabic ? TextAlign.right : TextAlign.left,
                style: GoogleFonts.cairo(color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: t(
                    'ابحث في المحادثات...',
                    'Search conversations...',
                  ),
                  hintTextDirection: direction,
                  hintStyle: GoogleFonts.cairo(
                    color: secondaryTextColor.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: secondaryTextColor,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: secondaryTextColor,
                    ),
                  ),
                  filled: true,
                  fillColor: surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accent, width: 1.4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: t('الكل', 'All'),
                    selected: !_unreadOnly,
                    accent: accent,
                    surface: surfaceColor,
                    border: cardBorderColor,
                    primaryText: primaryTextColor,
                    onTap: () => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label:
                    '${t('غير مقروءة', 'Unread')}${_unreadCount > 0 ? ' ($_unreadCount)' : ''}',
                    selected: _unreadOnly,
                    accent: accent,
                    surface: surfaceColor,
                    border: cardBorderColor,
                    primaryText: primaryTextColor,
                    onTap: () => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                child: CircularProgressIndicator(color: accent),
              )
                  : RefreshIndicator(
                onRefresh: _loadChats,
                color: accent,
                child: _buildBody(filtered),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> filtered) {
    if (_loadError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          _StateCard(
            icon: Icons.cloud_off_rounded,
            title: t(
              'تعذر تحميل المحادثات',
              'Could not load conversations',
            ),
            message: t(
              'تحققي من اتصال الخادم ثم أعيدي المحاولة.',
              'Check the server connection and try again.',
            ),
            buttonText: t('إعادة المحاولة', 'Retry'),
            onPressed: _loadChats,
            accent: accent,
            surface: surfaceColor,
            border: cardBorderColor,
            primaryText: primaryTextColor,
            secondaryText: secondaryTextColor,
          ),
        ],
      );
    }

    if (_chats.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          _StateCard(
            icon: Icons.forum_outlined,
            title: t(
              'لا توجد محادثات بعد',
              'No conversations yet',
            ),
            message: t(
              'ستظهر هنا المحادثات الحقيقية المرتبطة بطلباتك وتواصلك مع العملاء.',
              'Real conversations linked to your orders and customers will appear here.',
            ),
            accent: accent,
            surface: surfaceColor,
            border: cardBorderColor,
            primaryText: primaryTextColor,
            secondaryText: secondaryTextColor,
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          _StateCard(
            icon: _unreadOnly
                ? Icons.mark_chat_read_outlined
                : Icons.search_off_rounded,
            title: _unreadOnly
                ? t(
              'لا توجد رسائل غير مقروءة',
              'No unread conversations',
            )
                : t(
              'لا توجد نتائج',
              'No results found',
            ),
            message: _unreadOnly
                ? t(
              'لقد قرأت جميع المحادثات الحالية.',
              'You have read all current conversations.',
            )
                : t(
              'جرّبي البحث بكلمة أخرى.',
              'Try searching with another word.',
            ),
            accent: accent,
            surface: surfaceColor,
            border: cardBorderColor,
            primaryText: primaryTextColor,
            secondaryText: secondaryTextColor,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = filtered[index];

        return _ChatTile(
          name: chat['name'].toString(),
          avatar: chat['avatar'].toString(),
          lastMessage: chat['lastMessage'].toString(),
          orderTitle: chat['orderTitle'].toString(),
          time: chat['time'].toString(),
          unread: chat['unread'] as int,
          online: chat['online'] == true,
          accent: accent,
          primaryText: primaryTextColor,
          secondaryText: secondaryTextColor,
          surface: surfaceColor,
          border: cardBorderColor,
          onTap: () => _openChat(chat),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? accent : surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: selected ? Colors.black : primaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String avatar;
  final String lastMessage;
  final String orderTitle;
  final String time;
  final int unread;
  final bool online;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.orderTitle,
    required this.time,
    required this.unread,
    required this.online,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstCharacter =
    name.trim().isEmpty ? '?' : name.characters.first;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
              unread > 0 ? accent.withValues(alpha: 0.55) : border,
              width: unread > 0 ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accent.withValues(alpha: 0.18),
                    backgroundImage:
                    avatar.trim().isEmpty ? null : NetworkImage(avatar),
                    child: avatar.trim().isEmpty
                        ? Text(
                      firstCharacter,
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  ),
                  if (online)
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: primaryText,
                              fontSize: 14.5,
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: GoogleFonts.cairo(
                              color:
                              secondaryText.withValues(alpha: 0.65),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (orderTitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 12,
                            color: accent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              orderTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: unread > 0
                                  ? primaryText
                                  : secondaryText,
                              fontSize: 12.8,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onPressed,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: secondaryText,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                buttonText!,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
