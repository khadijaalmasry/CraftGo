import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_state.dart';
import 'delivery_order_detail_screen.dart';
import '../../services/delivery_service.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final driverId = appState.userId ?? '1';

    try {
      final rawOrders = await DeliveryService.getDriverOrders(driverId);
      final List<Map<String, dynamic>> formatted = rawOrders.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);

        final product = map['product'] as Map<String, dynamic>?;
        final customer = map['customer'] as Map<String, dynamic>?;
        final craftsman = map['craftsman'] as Map<String, dynamic>?;

        final productNameAr = product?['titleAr']?.toString() ??
            map['productName']?.toString() ??
            '';
        final productNameEn = product?['titleEn']?.toString() ??
            map['productNameEn']?.toString() ??
            productNameAr;
        final customerName = customer?['name']?.toString() ??
            map['customerName']?.toString() ??
            '';
        final customerPhone = customer?['phone']?.toString() ??
            map['customerPhone']?.toString() ??
            '';
        final pickupPhone = craftsman?['phone']?.toString() ??
            map['pickupPhone']?.toString() ??
            '';

        final rawStatus = map['status']?.toString() ?? 'active';
        final String normStatus;
        if (rawStatus == 'active' || rawStatus == 'in_progress') {
          normStatus = 'active';
        } else if (rawStatus == 'delivered' || rawStatus == 'completed') {
          normStatus = 'completed';
        } else if (rawStatus == 'cancelled' ||
            rawStatus == 'undelivered' ||
            rawStatus == 'returned') {
          normStatus = 'cancelled';
        } else if (rawStatus == 'available') {
          normStatus = 'upcoming';
        } else {
          normStatus = rawStatus;
        }

        return {
          'id': map['orderCode'] ?? map['id']?.toString() ?? 'DEL-0000',
          'rawId': map['id']?.toString(),
          'status': normStatus,
          'rawStatus': rawStatus,
          'rawOrder': map,
          'pickup': map['pickupAddress'] ?? '',
          'dropoff': map['dropoffAddress'] ?? '',
          'posted': _formatDate(map['postedAt'] ?? map['createdAt']),
          'due': _formatDate(map['dueAt']),
          'earnings': (map['earningAmount'] as num?)?.toDouble() ?? 0.0,
          'distance': (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
          'rating': map['rating'] != null
              ? double.tryParse(map['rating'].toString())
              : null,
          'customer': customerName,
          'customerEn': customerName,
          'deliveredAt': map['deliveredAt'] != null
              ? _formatDate(map['deliveredAt'])
              : null,
          'reason':
              map['cancelReason'] ?? map['issueNotes'] ?? map['issueType'],
          'productName': productNameAr,
          'productNameEn': productNameEn,
          'weightKg': map['weightKg'],
          'isFragile': map['isFragile'] == true || map['isFragile'] == 1,
          'customerPhone': customerPhone,
          'pickupPhone': pickupPhone,
        };
      }).toList();

      setState(() {
        _orders = formatted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    if (dateVal is String) {
      if (dateVal.contains('T')) {
        final parsed = DateTime.tryParse(dateVal);
        if (parsed != null) {
          final yr = parsed.year;
          final mo = parsed.month.toString().padLeft(2, '0');
          final dy = parsed.day.toString().padLeft(2, '0');
          final hr = parsed.hour.toString().padLeft(2, '0');
          final mi = parsed.minute.toString().padLeft(2, '0');
          return '$yr-$mo-$dy $hr:$mi';
        }
      }
      return dateVal;
    }
    return dateVal.toString();
  }

  List<Map<String, dynamic>> _filterOrders(String status) {
    final filtered = _orders.where((o) => o['status'] == status).toList();
    if (status == 'upcoming') {
      filtered.sort((a, b) {
        final da = a['due'] as String? ?? '';
        final db = b['due'] as String? ?? '';
        return da.compareTo(db);
      });
    } else if (status == 'completed') {
      filtered.sort((a, b) {
        final da = a['deliveredAt'] as String? ?? a['posted'] as String? ?? '';
        final db = b['deliveredAt'] as String? ?? b['posted'] as String? ?? '';
        return db.compareTo(da);
      });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppState>().isArabic;
    final isDarkMode = context.watch<AppState>().isDarkMode;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    color: accent,
                    child: Column(
                      children: [
                        // Tab Bar (without AppBar)
                        Container(
                          color: bg,
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: accent,
                            indicatorWeight: 3,
                            labelColor: accent,
                            unselectedLabelColor: dim,
                            labelStyle: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: GoogleFonts.cairo(
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: t('نشط', 'Active')),
                              Tab(text: t('قادم', 'Upcoming')),
                              Tab(text: t('مكتمل', 'Completed')),
                              Tab(text: t('ملغي', 'Cancelled')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOrderList('active', isArabic, isDarkMode),
                              _buildOrderList('upcoming', isArabic, isDarkMode),
                              _buildOrderList(
                                  'completed', isArabic, isDarkMode),
                              _buildOrderList(
                                  'cancelled', isArabic, isDarkMode),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildOrderList(String status, bool isArabic, bool isDarkMode) {
    final orders = _filterOrders(status);
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    final isReadOnly = isCompleted || isCancelled;

    if (orders.isEmpty) {
      return _buildEmptyState(isArabic);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isUpcoming = status == 'upcoming';
        return _OrderCard(
          order: order,
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          isReadOnly: isReadOnly,
          isUpcoming: isUpcoming,
          onTap: () {
            final rawOrder = order['rawOrder'] as Map<String, dynamic>?;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryOrderDetailScreen(
                  orderId:
                      rawOrder != null ? null : (order['rawId'] ?? order['id']),
                  order: rawOrder,
                ),
              ),
            ).then((_) => _fetchOrders());
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isArabic) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: dim.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              t('لا توجد طلبات', 'No orders'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('ستظهر الطلبات هنا', 'Orders will appear here'),
              style: GoogleFonts.cairo(color: dim, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            t('فشل في تحميل الطلبات', 'Failed to load orders'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              t('إعادة المحاولة', 'Retry'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _OrderCard remains unchanged ─────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isArabic;
  final bool isDarkMode;
  final bool isReadOnly;
  final bool isUpcoming;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isArabic,
    required this.isDarkMode,
    required this.isReadOnly,
    this.isUpcoming = false,
    required this.onTap,
  });

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white70 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isCompleted = order['status'] == 'completed';
    final isCancelled = order['status'] == 'cancelled';
    final hasRating = order['rating'] != null;
    final deliveredAt = order['deliveredAt'] as String?;

    final pickup = (order['pickup'] as String? ?? '').isNotEmpty
        ? (order['pickup'] as String)
        : (order['pickupEn'] as String? ?? '');
    final dropoff = (order['dropoff'] as String? ?? '').isNotEmpty
        ? (order['dropoff'] as String)
        : (order['dropoffEn'] as String? ?? '');
    final customer = (order['customer'] as String? ?? '').isNotEmpty
        ? (order['customer'] as String)
        : (order['customerEn'] as String? ?? '');
    final productName = isArabic
        ? ((order['productName'] as String? ?? '').isNotEmpty
            ? order['productName'] as String
            : (order['productNameEn'] as String? ?? ''))
        : ((order['productNameEn'] as String? ?? '').isNotEmpty
            ? order['productNameEn'] as String
            : (order['productName'] as String? ?? ''));

    final statusColor = isCompleted
        ? Colors.green
        : isCancelled
            ? Colors.red
            : accent;

    final dueDisplay = isUpcoming ? _formatDue(order['due'], isArabic) : null;

    final customerPhone = order['customerPhone']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          order['id'],
                          style: GoogleFonts.cairo(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((order['rawOrder']?['isBatch'] == true) ||
                          ((order['rawOrder']?['totalItemsCount'] as int? ?? 0) > 1)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t('شحنة مجمعة', 'Batch'),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted && hasRating) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        order['rating'].toString(),
                        style: GoogleFonts.cairo(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (isCompleted && !hasRating)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t('قيد التقييم', 'Pending review'),
                          style: GoogleFonts.cairo(
                            color: dim,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    if (isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t('ملغي', 'Cancelled'),
                          style: GoogleFonts.cairo(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isCompleted && deliveredAt != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              t('تم التوصيل', 'Delivered'),
                              style: GoogleFonts.cairo(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Product name ─────────────────────────────────────────
            if (productName.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 13, color: dim),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      productName,
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // ── Status + Timestamp ──────────────────────────────────
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted
                      ? t('مكتمل', 'Completed')
                      : isCancelled
                          ? t('ملغي', 'Cancelled')
                          : t('قيد التنفيذ', 'In Progress'),
                  style: GoogleFonts.cairo(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  order['posted'],
                  style: GoogleFonts.cairo(
                    color: dim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Due time (prominent for upcoming) ──────────────────
            if (isUpcoming && dueDisplay != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.alarm, color: Color(0xFFD4A017), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dueDisplay,
                        style: GoogleFonts.cairo(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Pickup ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle, color: Colors.green, size: 8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickup,
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // ── Dropoff ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              child: Container(
                width: 2,
                height: 12,
                color: dim.withValues(alpha: 0.3),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle, color: Colors.red, size: 8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropoff,
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Footer ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: dim, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      customer,
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 12,
                      ),
                    ),
                    if (customerPhone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          final clean = customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                          if (clean.isNotEmpty) {
                            final uri = Uri(scheme: 'tel', path: clean);
                            try {
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            } catch (_) {}
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone, color: Colors.green, size: 14),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: dim, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${order['distance']} ${t('كم', 'km')}',
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₪${(order['earnings'] as double).toStringAsFixed(0)}',
                        style: GoogleFonts.cairo(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Cancelled reason ──────────────────────────────────
            if (isCancelled &&
                (order['reason'] != null || order['reasonEn'] != null)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  isArabic
                      ? (order['reason'] ?? order['reasonEn'] ?? '')
                      : (order['reasonEn'] ?? order['reason'] ?? ''),
                  style: GoogleFonts.cairo(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDue(String due, bool isArabic) {
    try {
      final parts = due.split(' ');
      if (parts.length == 2) {
        final date = parts[0];
        final time = parts[1];
        final dateObj = DateTime.parse(date);
        final weekdays = isArabic
            ? [
                'الأحد',
                'الإثنين',
                'الثلاثاء',
                'الأربعاء',
                'الخميس',
                'الجمعة',
                'السبت'
              ]
            : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final weekday = weekdays[dateObj.weekday % 7];
        if (isArabic) {
          return 'موعد التسليم: $weekday، $date $time';
        } else {
          return 'Due: $weekday, $date at $time';
        }
      }
      return isArabic ? 'الموعد: $due' : 'Due: $due';
    } catch (_) {
      return isArabic ? 'الموعد: $due' : 'Due: $due';
    }
  }
}
