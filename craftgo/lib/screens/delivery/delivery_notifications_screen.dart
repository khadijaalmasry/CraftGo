import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import 'delivery_order_detail_screen.dart';

class DeliveryNotificationsScreen extends StatefulWidget {
  const DeliveryNotificationsScreen({super.key});

  @override
  State<DeliveryNotificationsScreen> createState() =>
      _DeliveryNotificationsScreenState();
}

class _DeliveryNotificationsScreenState
    extends State<DeliveryNotificationsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  String _getDriverId() {
    final appState = context.read<AppState>();
    return appState.userId ?? '';
  }

  Future<void> _fetchNotifications() async {
    final driverId = _getDriverId();
    if (driverId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await DeliveryService.getNotifications(driverId);
      if (data != null) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  // ── Theme helpers ─────────────────────────────────────────────────
  Color get bg => context.watch<AppState>().isDarkMode
      ? const Color(0xFF0D1420)
      : const Color(0xFFF5F6F8);
  Color get surface => context.watch<AppState>().isDarkMode
      ? const Color(0xFF1C2431)
      : Colors.white;
  Color get text =>
      context.watch<AppState>().isDarkMode ? Colors.white : Colors.black87;
  Color get dim =>
      context.watch<AppState>().isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => context.watch<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;
    return _notifications.where((n) => n['type'] == _selectedFilter).toList();
  }

  int get _unreadCount =>
      _notifications.where((n) => n['read'] == false).length;

  Future<void> _markAllAsRead() async {
    final driverId = _getDriverId();
    setState(() {
      for (var n in _notifications) {
        n['read'] = true;
      }
    });

    if (driverId.isNotEmpty) {
      await DeliveryService.markAllNotificationsRead(driverId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('تم تحديد الكل كمقروء', 'All marked as read')),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _markSingleAsRead(Map<String, dynamic> notification) async {
    if (notification['read'] == true) return;

    setState(() {
      notification['read'] = true;
    });

    final notificationId = notification['id']?.toString();
    if (notificationId != null) {
      await DeliveryService.markNotificationRead(notificationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppState>().isArabic;
    final isDarkMode = context.watch<AppState>().isDarkMode;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // ── Custom Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('الإشعارات', 'Notifications'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (_unreadCount > 0)
                    TextButton(
                      onPressed: _markAllAsRead,
                      child: Text(
                        t('تحديد الكل كمقروء', 'Mark all as read'),
                        style: GoogleFonts.cairo(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Filter Chips ─────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', t('الكل', 'All')),
                  const SizedBox(width: 8),
                  _filterChip('order', t('الطلبات', 'Orders')),
                  const SizedBox(width: 8),
                  _filterChip('system', t('النظام', 'System')),
                  const SizedBox(width: 8),
                  _filterChip('payout', t('السحب', 'Payout')),
                  const SizedBox(width: 8),
                  _filterChip('promotion', t('العروض', 'Promotions')),
                ],
              ),
            ),
            // ── Notification List ──────────────────────────────────
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _hasError
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetchNotifications,
                          color: accent,
                          child: _filteredNotifications.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _filteredNotifications.length,
                                  itemBuilder: (context, index) {
                                    final notification =
                                        _filteredNotifications[index];
                                    return _NotificationCard(
                                      notification: notification,
                                      isArabic: isArabic,
                                      isDarkMode: isDarkMode,
                                      onTap: () {
                                        _markSingleAsRead(notification);
                                        if (notification['orderId'] != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DeliveryOrderDetailScreen(
                                                orderId: notification['orderId']
                                                    .toString(),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : text,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: dim.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                t('لا توجد إشعارات', 'No notifications'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('ستظهر الإشعارات هنا', 'Notifications will appear here'),
                style: GoogleFonts.cairo(color: dim, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            t('فشل في تحميل الإشعارات', 'Failed to load notifications'),
            style: GoogleFonts.cairo(color: text, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchNotifications,
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: Text(
              t('إعادة المحاولة', 'Retry'),
              style: GoogleFonts.cairo(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Card ─────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isArabic,
    required this.isDarkMode,
    required this.onTap,
  });

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white70 : Colors.black54;
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);

  IconData _getIcon(dynamic iconData) {
    if (iconData is IconData) return iconData;
    if (iconData is String) {
      switch (iconData) {
        case 'inbox':
          return Icons.inbox;
        case 'system_update':
          return Icons.system_update;
        case 'cancel':
          return Icons.cancel;
        case 'attach_money':
          return Icons.attach_money;
        case 'celebration':
          return Icons.celebration;
        default:
          return Icons.notifications;
      }
    }
    return Icons.notifications;
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue is Color) return colorValue;
    if (colorValue is String && colorValue.isNotEmpty) {
      try {
        final hex = colorValue.replaceFirst('#', '');
        return Color(int.parse('0xFF$hex'));
      } catch (_) {}
    }
    return accent;
  }

  String _getTitle(Map<String, dynamic> notification) {
    if (isArabic) {
      return notification['titleAr'] ??
          notification['title'] ??
          notification['titleEn'] ??
          '';
    }
    return notification['titleEn'] ??
        notification['title'] ??
        notification['titleAr'] ??
        '';
  }

  String _getBody(Map<String, dynamic> notification) {
    if (isArabic) {
      return notification['bodyAr'] ??
          notification['body'] ??
          notification['bodyEn'] ??
          '';
    }
    return notification['bodyEn'] ??
        notification['body'] ??
        notification['bodyAr'] ??
        '';
  }

  String _getTimestamp(Map<String, dynamic> notification) {
    // Use the existing timestamp field or fallback to createdAt
    return notification['timestamp'] ?? notification['createdAt'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final title = _getTitle(notification);
    final body = _getBody(notification);
    final color = _parseColor(notification['color']);
    final isRead = notification['read'] == true;
    final icon = _getIcon(notification['icon']);
    final timestamp = _getTimestamp(notification);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? surface : accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? border : accent.withValues(alpha: 0.2),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
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
                          title,
                          style: GoogleFonts.cairo(
                            color: text,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.cairo(color: dim, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (timestamp.isNotEmpty)
                    Text(
                      timestamp,
                      style: GoogleFonts.cairo(
                        color: dim.withValues(alpha: 0.6),
                        fontSize: 11,
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
