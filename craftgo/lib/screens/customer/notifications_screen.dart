import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen — الإشعارات
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const NotificationsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent =>
      widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  bool _aiSorted = false;
  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await NotificationService.getNotifications();

      final items = response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'exhibition_invite':
        return Icons.mark_email_unread_outlined;
      case 'exhibition_registration_approved':
        return Icons.check_circle_outline;
      case 'exhibition_registration_rejected':
        return Icons.cancel_outlined;
      case 'system':
        return Icons.info_outline;
      case 'ai_suggestion':
        return Icons.auto_awesome;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'message':
        return Colors.green;
      case 'payment':
        return accent;
      case 'exhibition_invite':
        return Colors.blueAccent;
      case 'exhibition_registration_approved':
        return Colors.green;
      case 'exhibition_registration_rejected':
        return Colors.redAccent;
      case 'system':
        return dim;
      case 'ai_suggestion':
        return Colors.purpleAccent;
      default:
        return accent;
    }
  }

  Color _getAIPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getAIPriorityLabel(String priority, bool isArabic) {
    switch (priority) {
      case 'high':
        return isArabic ? '🔴 حرج' : '🔴 Critical';
      case 'medium':
        return isArabic ? '🟡 متوسط' : '🟡 Medium';
      case 'low':
        return isArabic ? '🔵 اقتراح' : '🔵 Suggestion';
      default:
        return '';
    }
  }

  DateTime? _parseCreatedAt(dynamic value) {
    if (value is DateTime) return value.toLocal();

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }

    return null;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  String _formatTime(dynamic createdAt) {
    final date = _parseCreatedAt(createdAt);
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative || difference.inSeconds < 60) {
      return t('الآن', 'Just now');
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return widget.isArabic
          ? 'منذ $minutes دقيقة'
          : '$minutes min${minutes == 1 ? '' : 's'} ago';
    }

    if (difference.inHours < 24 && _isToday(date)) {
      final hours = difference.inHours;
      return widget.isArabic
          ? 'منذ $hours ساعة'
          : '$hours hour${hours == 1 ? '' : 's'} ago';
    }

    final minute = date.minute.toString().padLeft(2, '0');
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final period = date.hour >= 12 ? t('م', 'PM') : t('ص', 'AM');

    if (_isYesterday(date)) {
      return t(
        'أمس، $hour:$minute $period',
        'Yesterday, $hour:$minute $period',
      );
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  String _notificationTitle(Map<String, dynamic> notification) {
    final value = notification[widget.isArabic ? 'titleAr' : 'titleEn'] ??
        notification['titleAr'] ??
        notification['titleEn'];

    return value?.toString() ?? '';
  }

  String _notificationBody(Map<String, dynamic> notification) {
    final value = notification[widget.isArabic ? 'bodyAr' : 'bodyEn'] ??
        notification['bodyAr'] ??
        notification['bodyEn'];

    return value?.toString() ?? '';
  }

  bool _isUnread(Map<String, dynamic> notification) {
    return notification['isRead'] != true;
  }

  String _priorityOf(Map<String, dynamic> notification) {
    final directPriority = notification['priority']?.toString();
    if (directPriority != null && directPriority.isNotEmpty) {
      return directPriority;
    }

    final metadata = notification['metadata'];
    if (metadata is Map) {
      return metadata['priority']?.toString() ?? '';
    }

    return '';
  }

  bool _isAiNotification(Map<String, dynamic> notification) {
    return notification['type']?.toString() == 'ai_suggestion';
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAll ||
        !_notifications.any((notification) => _isUnread(notification))) {
      return;
    }

    setState(() => _isMarkingAll = true);

    final success = await NotificationService.markAllAsRead();

    if (!mounted) return;

    setState(() {
      _isMarkingAll = false;

      if (success) {
        for (final notification in _notifications) {
          notification['isRead'] = true;
        }
      }
    });

    if (!success) {
      _showError(
        t(
          'تعذر تحديد جميع الإشعارات كمقروءة',
          'Could not mark all notifications as read',
        ),
      );
    }
  }

  Future<bool> _dismissNotification(
      Map<String, dynamic> notification,
      ) async {
    final id = notification['id']?.toString() ?? '';
    if (id.isEmpty) return false;

    final originalIndex = _notifications.indexOf(notification);

    setState(() {
      _notifications.remove(notification);
    });

    final success = await NotificationService.deleteNotification(id);

    if (!mounted) return success;

    if (!success) {
      setState(() {
        final safeIndex =
        originalIndex.clamp(0, _notifications.length).toInt();
        _notifications.insert(safeIndex, notification);
      });

      _showError(
        t(
          'تعذر حذف الإشعار',
          'Could not delete notification',
        ),
      );
    }

    return success;
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (!_isUnread(notification)) return;

    final id = notification['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final success = await NotificationService.markAsRead(id);

    if (!mounted) return;

    if (success) {
      setState(() {
        notification['isRead'] = true;
      });
    } else {
      _showError(
        t(
          'تعذر تحديث الإشعار',
          'Could not update notification',
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleNotifications {
    final items = List<Map<String, dynamic>>.from(_notifications);

    if (!_aiSorted) {
      return items
          .where((notification) => !_isAiNotification(notification))
          .toList();
    }

    int priorityWeight(Map<String, dynamic> notification) {
      switch (_priorityOf(notification)) {
        case 'high':
          return 3;
        case 'medium':
          return 2;
        case 'low':
          return 1;
        default:
          return 0;
      }
    }

    items.sort((a, b) {
      final priorityComparison =
      priorityWeight(b).compareTo(priorityWeight(a));

      if (priorityComparison != 0) return priorityComparison;

      final aDate = _parseCreatedAt(a['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _parseCreatedAt(b['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _visibleNotifications;
    final todayNotifications = <Map<String, dynamic>>[];
    final olderNotifications = <Map<String, dynamic>>[];

    for (final notification in visibleNotifications) {
      final createdAt = _parseCreatedAt(notification['createdAt']);

      if (createdAt != null && _isToday(createdAt)) {
        todayNotifications.add(notification);
      } else {
        olderNotifications.add(notification);
      }
    }

    final isEmpty = visibleNotifications.isEmpty;

    return Directionality(
      textDirection:
      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic
                  ? Icons.arrow_forward_ios
                  : Icons.arrow_back_ios,
              color: text,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('الإشعارات', 'Notifications'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: _aiSorted ? Colors.purpleAccent : dim,
              ),
              onPressed: () => setState(() => _aiSorted = !_aiSorted),
            ),
            if (!isEmpty)
              IconButton(
                icon: _isMarkingAll
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
                    : Icon(Icons.done_all, color: accent),
                tooltip: t(
                  'تحديد الكل كمقروء',
                  'Mark all read',
                ),
                onPressed: _isMarkingAll ? null : _markAllAsRead,
              ),
          ],
        ),
        body: _buildBody(
          todayNotifications,
          olderNotifications,
        ),
      ),
    );
  }

  Widget _buildBody(
      List<Map<String, dynamic>> todayNotifications,
      List<Map<String, dynamic>> olderNotifications,
      ) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: accent),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (todayNotifications.isEmpty && olderNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: _loadNotifications,
      child: _buildList(
        todayNotifications,
        olderNotifications,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 72,
              color: dim,
            ),
            const SizedBox(height: 20),
            Text(
              t(
                'تعذر تحميل الإشعارات',
                'Could not load notifications',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: Text(
                t('إعادة المحاولة', 'Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: accent,
      onRefresh: _loadNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: border,
                ),
                child: Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: dim,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                t(
                  'لا يوجد إشعارات',
                  'No notifications',
                ),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'سيظهر لك هنا أي تحديثات جديدة',
                  'You will see new updates here',
                ),
                style: GoogleFonts.cairo(
                  color: dim,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      List<Map<String, dynamic>> todayNotifications,
      List<Map<String, dynamic>> olderNotifications,
      ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (_aiSorted)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.purpleAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.purpleAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(
                      'تم ترتيب الإشعارات حسب أهميتها بالذكاء الاصطناعي 🤖',
                      'Notifications sorted by AI priority 🤖',
                    ),
                    style: GoogleFonts.cairo(
                      color: Colors.purpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (todayNotifications.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            child: Text(
              t('اليوم', 'Today'),
              style: GoogleFonts.cairo(
                color: dim,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...todayNotifications.map(_buildNotificationTile),
        ],
        if (olderNotifications.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            child: Text(
              t('السابق', 'Earlier'),
              style: GoogleFonts.cairo(
                color: dim,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...olderNotifications.map(_buildNotificationTile),
        ],
      ],
    );
  }

  Widget _buildNotificationTile(
      Map<String, dynamic> notification,
      ) {
    final type = notification['type']?.toString() ?? '';
    final color = _getColorForType(type);
    final isUnread = _isUnread(notification);
    final priority = _priorityOf(notification);
    final id = notification['id']?.toString() ??
        notification.hashCode.toString();

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _dismissNotification(notification),
      background: Container(
        alignment: widget.isArabic
            ? Alignment.centerLeft
            : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.redAccent,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      child: InkWell(
        onTap: () => _markAsRead(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          color: isUnread
              ? accent.withValues(alpha: 0.05)
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForType(type),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _notificationTitle(notification),
                            style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(notification['createdAt']),
                          style: GoogleFonts.cairo(
                            color: dim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (_aiSorted && priority.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getAIPriorityColor(priority)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getAIPriorityLabel(
                            priority,
                            widget.isArabic,
                          ),
                          style: GoogleFonts.cairo(
                            color: _getAIPriorityColor(priority),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _notificationBody(notification),
                      style: GoogleFonts.cairo(
                        color: isUnread ? text : dim,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 12),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
