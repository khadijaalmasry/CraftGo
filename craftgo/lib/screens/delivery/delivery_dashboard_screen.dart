import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import 'delivery_vehicle_screen.dart';
import 'delivery_order_detail_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const DeliveryDashboardScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _error = '';

  // Dashboard data
  bool _isOnline = true;
  bool _isSuspended = false;
  double _rating = 4.9;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _vehicle = {};
  bool _hasActiveOrder = false;
  Map<String, dynamic>? _activeOrder;

  // Available orders
  List<Map<String, dynamic>> _availableOrders = [];

  // ── Theme helpers ─────────────────────────────────────────────────
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);
  Color get accentDark => const Color(0xFFB8860B);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // ── Data loading ────────────────────────────────────────────────────
  Future<void> _loadDashboardData() async {
    final appState = context.read<AppState>();
    final driverId = appState.userId;

    if (driverId == null || driverId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'User not logged in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Fetch dashboard data
      final dashboard = await DeliveryService.getDashboard(driverId);
      if (dashboard != null) {
        setState(() {
          _isOnline = dashboard['isOnline'] ?? true;
          _isSuspended = dashboard['isSuspended'] ?? false;
          _rating = (dashboard['rating'] as num?)?.toDouble() ?? 4.9;
          _stats = dashboard['stats'] ?? {};
          _vehicle = dashboard['vehicle'] ?? {};
          _hasActiveOrder = dashboard['hasActiveOrder'] ?? false;
          _activeOrder = dashboard['activeOrder'];
        });
      }

      // Fetch available orders
      final available = await DeliveryService.getAvailableOrders();
      setState(() {
        _availableOrders = available.map<Map<String, dynamic>>((order) {
          final product = order['product'] as Map<String, dynamic>?;
          final customer = order['customer'] as Map<String, dynamic>?;
          final craftsman = order['craftsman'] as Map<String, dynamic>?;

          final productNameAr = product?['titleAr']?.toString() ??
              order['productName']?.toString() ??
              '';
          final productNameEn = product?['titleEn']?.toString() ??
              order['productNameEn']?.toString() ??
              productNameAr;

          final customerName = customer?['name']?.toString() ??
              order['customerName']?.toString() ??
              '';
          final customerPhone = customer?['phone']?.toString() ??
              order['customerPhone']?.toString() ??
              '';

          final pickupPhone = craftsman?['phone']?.toString() ??
              order['pickupPhone']?.toString() ??
              '';

          return {
            'id': order['id']?.toString() ?? '',
            'orderCode': order['orderCode'] ?? 'DEL-XXXX',
            'productName': productNameAr,
            'productNameEn': productNameEn,
            'pickupAddress': order['pickupAddress'] ?? '',
            'pickupAddressEn': order['pickupAddress'] ?? '',
            'dropoffAddress': order['dropoffAddress'] ?? '',
            'dropoffAddressEn': order['dropoffAddress'] ?? '',
            'postedAt': order['postedAt'] != null
                ? _formatDateTime(order['postedAt'])
                : order['createdAt'] != null
                    ? _formatDateTime(order['createdAt'])
                    : '',
            'dueAt':
                order['dueAt'] != null ? _formatDateTime(order['dueAt']) : '',
            'distanceKm': (order['distanceKm'] as num?)?.toDouble() ?? 0,
            'earningAmount': (order['earningAmount'] as num?)?.toDouble() ?? 0,
            'weightKg': (order['weightKg'] as num?)?.toDouble() ?? 0,
            'isFragile': order['isFragile'] == true || order['isFragile'] == 1,
            'customerName': customerName,
            'customerNameEn': customerName,
            'customerPhone': customerPhone,
            'pickupPhone': pickupPhone,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDateTime(dynamic input) {
    if (input == null) return '';
    try {
      final dt = DateTime.parse(input.toString());
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$minute';
    } catch (_) {
      return input.toString();
    }
  }

  void _triggerDriverSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Row(
          children: [
            const Icon(Icons.crisis_alert, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              t('نداء استغاثة طارئ SOS', 'Emergency SOS Alert'),
              style: GoogleFonts.cairo(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          t(
            'هل أنت متأكد من إرسال نداء استغاثة طارئ للإدارة بخصوص موقعك الحالي؟',
            'Are you sure you want to send an emergency SOS alert to admin with your current location?',
          ),
          style: GoogleFonts.cairo(color: text, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final appState = context.read<AppState>();
              final driverId = appState.userId ?? '1';
              await DeliveryService.triggerSOS(
                driverId: driverId,
                location: 'شارع النزهة، رام الله (موقع المندوب)',
                notes: 'نداء طارئ محول مباشرة من التطبيق',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('تم إرسال نداء الاستغاثة بنجاح للإدارة',
                      'SOS alert sent successfully to admin')),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t('إرسال الاستغاثة', 'Send SOS'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final userName = appState.userName ?? t('مندوب', 'Driver');
    final isAr = widget.isArabic;
    final isDark = widget.isDarkMode;

    final totalCompleted = _stats['totalCompleted'] ?? 0;
    final todayTasks = _stats['todayTasks'] ?? 0;
    final todayEarnings = (_stats['todayEarnings'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        t('حدث خطأ', 'Something went wrong'),
                        style: GoogleFonts.cairo(color: text, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error,
                        style: GoogleFonts.cairo(color: dim, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(t('إعادة المحاولة', 'Retry')),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSuspended) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.block,
                                  color: Colors.red, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('تم إيقاف حسابك مؤقتاً',
                                          'Account Suspended'),
                                      style: GoogleFonts.cairo(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      t(
                                        'يرجى التواصل مع إدارة العمليات لمراجعة وتفعيل الحساب.',
                                        'Please contact operations admin to review and reactivate your account.',
                                      ),
                                      style: GoogleFonts.cairo(
                                          color: text, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Stats Cards ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              icon: Icons.check_circle_outline_rounded,
                              value: '$totalCompleted',
                              label: t('مكتمل', 'Completed'),
                              color: Colors.greenAccent.shade400,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              icon: Icons.today_rounded,
                              value: '$todayTasks',
                              label: t('مهام اليوم', "Today's Tasks"),
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              icon: Icons.attach_money_rounded,
                              value: '₪${todayEarnings.toStringAsFixed(0)}',
                              label: t('أرباح اليوم', "Today's Earnings"),
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Car Card & SOS ───────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DeliveryVehicleScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.directions_car_rounded,
                                        color: accent,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t('مركبتي', 'My Vehicle'),
                                            style: GoogleFonts.cairo(
                                              color: text,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${_vehicle['make'] ?? ''} ${_vehicle['model'] ?? ''} ${_vehicle['year'] ?? ''}',
                                            style: GoogleFonts.cairo(
                                              color: dim,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _vehicle['licensePlate'] ?? '',
                                            style: GoogleFonts.cairo(
                                              color: dim,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isAr
                                          ? Icons.arrow_back_ios
                                          : Icons.arrow_forward_ios,
                                      color: dim,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // SOS Button
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: ElevatedButton(
                              onPressed: () => _callEmergency(context, isAr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                elevation: 4,
                                shadowColor:
                                    Colors.redAccent.withValues(alpha: 0.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone, size: 28),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SOS',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Active Order Banner ──────────────────────────
                      if (_hasActiveOrder) _buildActiveOrderBanner(),
                      const SizedBox(height: 20),

                      // ── Available Orders Feed ──────────────────────
                      Text(
                        t('الطلبات المتاحة', 'Available Orders'),
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_availableOrders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Center(
                            child: Text(
                              t('لا توجد طلبات متاحة حالياً',
                                  'No orders available right now'),
                              style:
                                  GoogleFonts.cairo(color: dim, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ..._availableOrders.map((order) => _AvailableOrderCard(
                              order: order,
                              isArabic: isAr,
                              isDark: isDark,
                              onAccept: () => _showOrderDetailsSheet(
                                  context, order, isAr, isDark),
                            )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ─── Stats Cards ──────────────────────────────────────────────────────
  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _callEmergency(BuildContext context, bool isAr) async {
    const emergencyNumber = '112';
    final Uri phoneUri = Uri(scheme: 'tel', path: emergencyNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showManualCallDialog(context, isAr);
      }
    } catch (_) {
      _showManualCallDialog(context, isAr);
    }
  }

  void _showManualCallDialog(BuildContext context, bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          t('رقم الطوارئ', 'Emergency Number'),
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isAr
              ? 'يرجى الاتصال على الرقم 112 يدوياً'
              : 'Please call 112 manually.',
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t('موافق', 'OK'),
              style: TextStyle(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;

    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $cleanPhone')),
        );
      }
    }
  }

  // ─── Active Order Banner ──────────────────────────────────────────
  Widget _buildActiveOrderBanner() {
    final orderCode = _activeOrder?['orderCode'] ?? '';
    final productName = widget.isArabic
        ? (_activeOrder?['productName'] ?? '')
        : (_activeOrder?['productNameEn'] ?? _activeOrder?['productName'] ?? '');
    final customerPhone = _activeOrder?['customerPhone']?.toString() ??
        _activeOrder?['customer']?['phone']?.toString() ??
        '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.2),
            accentDark.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final orderId = _activeOrder?['id']?.toString() ?? '';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryOrderDetailScreen(
                  orderId: orderId.isNotEmpty ? orderId : null,
                  order: _activeOrder,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2,
                      color: Color(0xFFD4A017), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t('طلب قيد التوصيل', 'Order in Progress'),
                            style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (_activeOrder?['isBatch'] == true) ...[
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
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        productName.toString().isNotEmpty
                            ? '$orderCode • $productName'
                            : '$orderCode',
                        style: TextStyle(color: dim, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (customerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk,
                        color: Colors.green, size: 22),
                    tooltip: t('الاتصال بالعميل', 'Call Customer'),
                    onPressed: () => _makePhoneCall(customerPhone),
                  ),
                const Icon(Icons.arrow_forward_ios,
                    color: Color(0xFFD4A017), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Accept Order ──────────────────────────────────────────────────
  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    final appState = context.read<AppState>();
    final driverId = appState.userId;

    if (driverId == null || driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى تسجيل الدخول', 'Please login')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await DeliveryService.acceptOrder(
        orderId: order['id'],
        driverId: driverId,
      );

      if (result != null) {
        await _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(t('تم قبول الطلب بنجاح', 'Order accepted successfully')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('فشل قبول الطلب', 'Failed to accept order')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('حدث خطأ', 'An error occurred')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Order Details Sheet ──────────────────────────────────────────
  void _showOrderDetailsSheet(BuildContext context, Map<String, dynamic> order,
      bool isAr, bool isDark) {
    final bg = isDark ? const Color(0xFF141414) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black87;
    final accent = const Color(0xFFD4A017);

    final product = isAr ? order['productName'] : order['productNameEn'];
    final pickup = isAr ? order['pickupAddress'] : order['pickupAddressEn'];
    final dropoff = isAr ? order['dropoffAddress'] : order['dropoffAddressEn'];
    final posted = order['postedAt'] ?? '';
    final due = order['dueAt'] ?? '';
    final distance = (order['distanceKm'] as num?)?.toDouble() ?? 0;
    final earning = order['earningAmount'] ?? 0;
    final weight = (order['weightKg'] as num?)?.toDouble() ?? 0;
    final isFragile = order['isFragile'] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('تفاصيل الشحنة', 'Shipment Details'),
                    style: GoogleFonts.cairo(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₪$earning',
                      style: GoogleFonts.cairo(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Code
              Text(
                order['orderCode'] ?? order['id'] ?? '',
                style: GoogleFonts.cairo(
                    color: accent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Product
              _infoRow(
                icon: Icons.inventory_2_outlined,
                label: t('المنتج', 'Product'),
                value: product,
                textColor: textColor,
                subColor: subColor,
              ),
              const SizedBox(height: 8),

              // Weight & Fragile
              Row(
                children: [
                  Expanded(
                    child: _infoRow(
                      icon: Icons.scale_outlined,
                      label: t('الوزن', 'Weight'),
                      value: '${weight.toStringAsFixed(1)} kg',
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ),
                  if (isFragile)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t('قابل للكسر', 'Fragile'),
                        style: GoogleFonts.cairo(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Pickup
              _infoRow(
                icon: Icons.store_mall_directory_outlined,
                label: t('الاستلام', 'Pickup'),
                value: pickup,
                textColor: textColor,
                subColor: subColor,
                iconColor: Colors.blueAccent,
              ),
              const SizedBox(height: 4),
              // Dropoff
              _infoRow(
                icon: Icons.location_on_outlined,
                label: t('التسليم', 'Dropoff'),
                value: dropoff,
                textColor: textColor,
                subColor: subColor,
                iconColor: Colors.redAccent,
              ),
              const SizedBox(height: 12),

              // Timestamps
              Row(
                children: [
                  Expanded(
                    child: _infoRow(
                      icon: Icons.access_time,
                      label: t('نشر', 'Posted'),
                      value: posted,
                      textColor: textColor,
                      subColor: subColor,
                      iconColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoRow(
                      icon: Icons.alarm,
                      label: t('مطلوب', 'Due'),
                      value: due,
                      textColor: textColor,
                      subColor: subColor,
                      iconColor: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Distance
              Row(
                children: [
                  Icon(Icons.directions_car_outlined,
                      color: subColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${distance.toStringAsFixed(1)} ${t('كم', 'km')}',
                    style: GoogleFonts.cairo(color: subColor, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: subColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        t('تراجع', 'Cancel'),
                        style: GoogleFonts.cairo(
                            color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _acceptOrder(order);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        t('تأكيد الاستلام', 'Confirm Pickup'),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? subColor, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.cairo(color: subColor, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Available Order Card ──────────────────────────────────────────────

class _AvailableOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onAccept;

  const _AvailableOrderCard({
    required this.order,
    required this.isArabic,
    required this.isDark,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final cardBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
    final accent = const Color(0xFFD4A017);

    final isAr = isArabic;
    final pickup = order['pickupAddress'] as String? ?? '';
    final dropoff = order['dropoffAddress'] as String? ?? '';
    final distance = (order['distanceKm'] as num?)?.toDouble() ?? 0;
    final earning = order['earningAmount'] ?? 0;
    final product = isAr
        ? ((order['productName'] as String? ?? '').isNotEmpty
            ? order['productName'] as String
            : (order['productNameEn'] as String? ?? ''))
        : ((order['productNameEn'] as String? ?? '').isNotEmpty
            ? order['productNameEn'] as String
            : (order['productName'] as String? ?? ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order['orderCode'] ?? order['id'] ?? '',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₪$earning',
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: subColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  product,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.store_mall_directory_outlined,
                  color: Colors.blueAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickup,
                  style: TextStyle(color: textColor, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Container(
                width: 2, height: 12, color: subColor.withValues(alpha: 0.3)),
          ),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dropoff,
                  style: TextStyle(color: textColor, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car_outlined,
                      color: subColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} ${isAr ? 'كم' : 'km'}',
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 36),
                ),
                child: Text(
                  isAr ? 'قبول الطلب' : 'Accept',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
