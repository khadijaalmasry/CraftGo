import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'review_submission_screen.dart';
import '../delivery/create_delivery_screen.dart';
import 'chat_detail_screen.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../services/session_service.dart';
import '../../services/payment_service.dart';
import '../../services/delivery_service.dart';
import '../../services/custom_order_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../custom_order/custom_order_request.dart';
import '../custom_order/custom_order_provider.dart';
import '../hire_order/hire_order_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrderDetailScreen — تفاصيل الطلب (يدعم جميع الأنواع)
//
// Supported order types:
//   • Ready-Made: Standard product purchase
//   • Custom Order: Made-to-order with template fields + artisan response
//   • Hire/On-Site: Job with location, schedule, materials, tools
// ─────────────────────────────────────────────────────────────────────────────

class OrderDetailScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.order,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isSubmittingPayment = false;

  // ── Theme Colors ──────────────────────────────────────────────────────────
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);
  Color get gold => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  String get _displayOrderNumber {
    final id = widget.order['id']?.toString() ?? '';

    if (id.trim().isEmpty) {
      return 'Order #--------';
    }

    final shortId = id.replaceAll('-', '').toUpperCase();
    final displayId = shortId.length >= 8 ? shortId.substring(0, 8) : shortId;

    return widget.isArabic ? 'طلب #$displayId' : 'Order #$displayId';
  }

  String get _displayOrderDate {
    final explicitDate = widget.order['date'];
    if (explicitDate != null && explicitDate.toString().trim().isNotEmpty) {
      return explicitDate.toString();
    }

    final createdAt = widget.order['createdAt'];
    if (createdAt != null) {
      return _formatDate(_parseDateTime(createdAt));
    }

    return _formatDate(DateTime.now());
  }

  // ── Order Type Detection ──────────────────────────────────────────────────
  String get _orderType {
    final type = widget.order['type'] ?? '';
    if (type == 'custom') return 'custom';
    if (type == 'hire') return 'hire';
    return 'ready_made';
  }

  bool get isCustomOrder => _orderType == 'custom';
  bool get isHireOrder => _orderType == 'hire';
  bool get isReadyMade => _orderType == 'ready_made';

  // ── Status Helpers ────────────────────────────────────────────────────────
  String get _status => widget.order['status'] ?? 'pending';

  int get _currentStep {
    final status = _status;
    if (status == 'completed' || status == 'delivered') return 4;
    if (status == 'ready' || status == 'ready_for_delivery') return 3;
    if (status == 'in_progress' || status == 'accepted') return 2;
    if (status == 'pending_customer') return 1;
    return 0;
  }

  Color get _statusColor {
    final status = _status;
    final map = {
      'pending': Colors.orange,
      'pending_artisan': Colors.orange,
      'pending_customer': Colors.blue,
      'in_progress': gold,
      'accepted': Colors.teal,
      'completed': Colors.green,
      'delivered': Colors.green,
      'ready': Colors.purple,
      'cancelled': Colors.grey,
      'rejected': Colors.red,
    };
    return map[status] ?? Colors.grey;
  }

  String get _statusText {
    final status = _status;
    final map = {
      'pending': t('قيد الانتظار', 'Pending'),
      'pending_artisan': t('في انتظار الرد', 'Awaiting Response'),
      'pending_customer': t('بانتظار موافقتك', 'Awaiting Your Approval'),
      'in_progress': t('قيد التنفيذ', 'In Progress'),
      'accepted': t('مقبول', 'Accepted'),
      'completed': t('مكتمل', 'Completed'),
      'delivered': t('تم التسليم', 'Delivered'),
      'ready': t('جاهز للتسليم', 'Ready for Delivery'),
      'cancelled': t('ملغي', 'Cancelled'),
      'rejected': t('مرفوض', 'Rejected'),
    };
    return map[status] ?? status;
  }

  // ── Get Display Name ──────────────────────────────────────────────────────
  String get _displayName {
    if (isCustomOrder) {
      return widget.isArabic
          ? widget.order['nameAr'] ??
              widget.order['templateTitleAr'] ??
              'طلب مخصص'
          : widget.order['nameEn'] ??
              widget.order['templateTitleEn'] ??
              'Custom Order';
    } else if (isHireOrder) {
      return widget.isArabic
          ? widget.order['nameAr'] ?? 'عمل في الموقع'
          : widget.order['nameEn'] ?? 'On-Site Work';
    } else {
      return widget.isArabic
          ? widget.order['nameAr'] ?? 'منتج'
          : widget.order['nameEn'] ?? 'Product';
    }
  }

  // ── Get Artisan Name ──────────────────────────────────────────────────────
  // _artisanName removed as it was unused

  // ── Get Price ─────────────────────────────────────────────────────────────
  // _totalPrice removed as it was unused

  // ── Get Customer Fields (Custom Orders) ──────────────────────────────────
  Map<String, dynamic> get _filledFields {
    return widget.order['filledFields'] ?? {};
  }

  // ── Get Artisan Response ──────────────────────────────────────────────────
  Map<String, dynamic>? get _artisanResponse {
    final raw = widget.order['artisanResponse'];

    if (raw == null) return null;

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is ArtisanResponse) {
      return {
        'breakdown': raw.breakdown
            .map(
              (row) => {
                'labelAr': row.labelAr,
                'labelEn': row.labelEn,
                'amount': row.amount,
              },
            )
            .toList(),
        'tasks': raw.tasks,
        'deliveryDate': raw.deliveryDate.toIso8601String(),
        'notesAr': raw.notesAr,
        'notesEn': raw.notesEn,
        'total': raw.total,
      };
    }

    debugPrint(
      '[OrderDetailScreen] Unsupported artisanResponse type: ${raw.runtimeType}',
    );
    return null;
  }

  // ── Get Hire Schedule ─────────────────────────────────────────────────────
  List<dynamic> get _schedule {
    return widget.order['schedule'] ?? [];
  }

  // ── Get Materials (Hire Orders) ──────────────────────────────────────────
  List<dynamic> get _materials {
    return widget.order['materials'] ?? [];
  }

  // ── Get Tools (Hire Orders) ──────────────────────────────────────────────
  List<String> get _tools {
    return (widget.order['toolsRequired'] as List?)?.cast<String>() ?? [];
  }

  // ── UI ──────────────────────────────────────────────────────────────────
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
            icon: Icon(
                widget.isArabic
                    ? Icons.arrow_forward_ios
                    : Icons.arrow_back_ios,
                color: text,
                size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('تفاصيل الطلب', 'Order Details'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ────────────────────────────────────────────────
              _buildHeaderCard(),
              _buildDeliveryPinBadge(),
              const SizedBox(height: 24),

              // ── Timeline ──────────────────────────────────────────────────
              Text(
                t('حالة الطلب', 'Order Status'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 24),

              // ── Service Details ───────────────────────────────────────────
              Text(
                _orderType == 'hire'
                    ? t('تفاصيل العمل', 'Job Details')
                    : t('تفاصيل الخدمة', 'Service Details'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDetailsSection(),
              const SizedBox(height: 24),

              // ── Pricing ───────────────────────────────────────────────────
              Text(
                t('ملخص الدفع', 'Payment Summary'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPricing(),
              const SizedBox(height: 40),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomActions(),
      ),
    );
  }

  // ── Header Card ──────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCustomOrder
                  ? Icons.edit_outlined
                  : (isHireOrder
                      ? Icons.handshake_outlined
                      : Icons.shopping_bag_outlined),
              color: _statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCustomOrder ? _displayName : _displayOrderNumber,
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _displayOrderDate,
                  style: GoogleFonts.cairo(color: dim, fontSize: 13),
                ),
                // Order type badge
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _orderType == 'custom'
                        ? Colors.purple.withValues(alpha: 0.12)
                        : (_orderType == 'hire'
                            ? Colors.teal.withValues(alpha: 0.12)
                            : gold.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _orderType == 'custom'
                        ? t('طلب مخصص', 'Custom Order')
                        : (_orderType == 'hire'
                            ? t('عمل في الموقع', 'On-Site')
                            : t('منتج جاهز', 'Ready-Made')),
                    style: TextStyle(
                      color: _orderType == 'custom'
                          ? Colors.purple
                          : (_orderType == 'hire' ? Colors.teal : gold),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusText,
              style: GoogleFonts.cairo(
                  color: _statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPinBadge() {
    final pin = widget.order['deliveryPin'] ??
        widget.order['delivery']?['deliveryPin'] ??
        widget.order['DeliveryOrder']?['deliveryPin'];
    if (pin == null || pin.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code, color: gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('رمز الاستلام للتوصيل (PIN)', 'Delivery Verification PIN'),
                  style: GoogleFonts.cairo(
                      color: dim, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  pin.toString(),
                  style: GoogleFonts.cairo(
                    color: gold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  t('أعطِ هذا الرمز للسائق عند استلام طلبك',
                      'Give this code to the driver upon package arrival'),
                  style: TextStyle(color: dim, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: () =>
                        _handleCustomerConfirmDelivery(pin.toString()),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      t('تأكيد استلام الطلب', 'Confirm Receipt'),
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCustomerConfirmDelivery(String defaultPin) async {
    final orderId = widget.order['id']?.toString() ?? '';
    final deliveryId = widget.order['DeliveryOrder']?['id']?.toString() ??
        widget.order['delivery']?['id']?.toString() ??
        orderId;

    if (deliveryId.isEmpty) return;

    final pinCtrl = TextEditingController(text: defaultPin);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          t('تأكيد استلام الطلب', 'Confirm Order Receipt'),
          style: GoogleFonts.cairo(
              color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('يرجى التأكد من استلام المنتج وتأكيد كود التوصيل:',
                  'Confirm delivery with verification PIN code:'),
              style: TextStyle(color: dim, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(
                  color: text, fontWeight: FontWeight.bold, letterSpacing: 3),
              decoration: InputDecoration(
                labelText: t('رمز PIN للتأكيد', 'Verification PIN'),
                labelStyle: TextStyle(color: dim),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('تأكيد الاستلام ✅', 'Confirm Receipt ✅'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await DeliveryService.verifyDeliveryPinOrQR(
      orderId: deliveryId,
      pin: pinCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('✅ تم تأكيد الاستلام واكتمال الطلب بنجاح!',
              '✅ Delivery confirmed & order completed!')),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        widget.order['status'] = 'completed';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              res?['error'] ?? t('رمز التأكيد غير صحيح', 'Invalid PIN code')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Timeline ─────────────────────────────────────────────────────────────
  Widget _buildTimeline() {
    // Different timeline stages based on order type
    final List<Map<String, String>> steps;

    if (isHireOrder) {
      final proposalReceived = _status == 'pending_customer';
      steps = [
        {
          'ar': 'تم استلام الطلب',
          'en': 'Job Received',
          'time': _formatTime(_parseDateTime(widget.order['createdAt']))
        },
        {
          'ar': proposalReceived ? 'تم استلام عرض الحرفي' : 'تم قبول العرض',
          'en': proposalReceived ? 'Proposal Received' : 'Proposal Accepted',
          'time': '--:--',
        },
        {'ar': 'قيد التنفيذ في الموقع', 'en': 'On-Site Work', 'time': '--:--'},
        {'ar': 'تم الانتهاء من العمل', 'en': 'Work Completed', 'time': '--:--'},
      ];
    } else if (isCustomOrder) {
      steps = [
        {
          'ar': 'تم استلام الطلب',
          'en': 'Request Received',
          'time': _formatTime(_parseDateTime(widget.order['createdAt']))
        },
        {'ar': 'تم رد الحرفي', 'en': 'Artisan Responded', 'time': '--:--'},
        {'ar': 'قيد التنفيذ', 'en': 'In Progress', 'time': '--:--'},
        {'ar': 'جاهز للتسليم', 'en': 'Ready for Delivery', 'time': '--:--'},
        {'ar': 'تم التسليم', 'en': 'Delivered', 'time': '--:--'},
      ];
    } else {
      steps = [
        {
          'ar': 'تم استلام الطلب',
          'en': 'Order Received',
          'time': _formatTime(_parseDateTime(widget.order['createdAt']))
        },
        {'ar': 'تم قبول الطلب', 'en': 'Order Accepted', 'time': '--:--'},
        {'ar': 'قيد التنفيذ', 'en': 'In Progress', 'time': '--:--'},
        {'ar': 'جاهز للتسليم', 'en': 'Ready for Delivery', 'time': '--:--'},
        {'ar': 'تم التسليم', 'en': 'Delivered', 'time': '--:--'},
      ];
    }

    final maxStep =
        _currentStep > steps.length - 1 ? steps.length - 1 : _currentStep;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          final isDone = index <= maxStep;
          final isCurrent = index == maxStep;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Line
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? accent : Colors.transparent,
                      border:
                          Border.all(color: isDone ? accent : border, width: 2),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: isDone && !isCurrent ? accent : border,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(steps[index]['ar']!, steps[index]['en']!),
                        style: GoogleFonts.cairo(
                          color: isDone ? text : dim,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        steps[index]['time']!,
                        style: GoogleFonts.cairo(color: dim, fontSize: 12),
                      ),
                      if (!isLast) const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Details Section ──────────────────────────────────────────────────────
  Widget _buildDetailsSection() {
    if (isCustomOrder) {
      return _buildCustomOrderDetails();
    } else if (isHireOrder) {
      return _buildHireOrderDetails();
    } else {
      return _buildReadyMadeDetails();
    }
  }

  // ── Custom Order Details ──────────────────────────────────────────────────
  Widget _buildCustomOrderDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer's filled fields
          Text(
            t('متطلبات العميل', 'Customer Requirements'),
            style: TextStyle(
                color: dim, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._filledFields.entries.map((entry) {
            final key = entry.key;
            final value = entry.value.toString();
            if (value.isEmpty) return const SizedBox.shrink();
            // Try to get a nicer label
            final label = key.replaceAll('_', ' ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration:
                        BoxDecoration(color: gold, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isArabic ? label : _toEnglish(label),
                          style: TextStyle(color: dim, fontSize: 13),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Divider(color: border),
          const SizedBox(height: 16),

          // Artisan Response
          if (_artisanResponse != null) ...[
            Text(
              t('رد الحرفي', 'Artisan Response'),
              style: TextStyle(
                  color: dim, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Price breakdown
            if (_artisanResponse!['breakdown'] != null)
              ...(_artisanResponse!['breakdown'] as List).map((row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isArabic
                            ? row['labelAr'] ?? row['label']
                            : row['labelEn'] ?? row['label'],
                        style: TextStyle(color: dim, fontSize: 13),
                      ),
                      Text(
                        '${row['amount'].toStringAsFixed(0)} JOD',
                        style:
                            TextStyle(color: text, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            // Tasks
            if (_artisanResponse!['tasks'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('المهام', 'Tasks'),
                    style: TextStyle(
                        color: dim, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...(_artisanResponse!['tasks'] as List).map((task) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 14, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task,
                              style: TextStyle(color: text, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 8),
            if (_artisanResponse!['deliveryDate'] != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: dim),
                  const SizedBox(width: 8),
                  Text(
                    '${t('تاريخ التسليم:', 'Delivery:')} '
                    '${_formatDate(_parseDateTime(_artisanResponse!['deliveryDate']))}',
                    style: TextStyle(color: dim, fontSize: 13),
                  ),
                ],
              ),
            if (_artisanResponse!['notesAr'] != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.isArabic
                      ? _artisanResponse!['notesAr'] ?? ''
                      : _artisanResponse!['notesEn'] ?? '',
                  style: TextStyle(
                      color: dim, fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Hire Order Details ────────────────────────────────────────────────────
  Widget _buildHireOrderDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Description
          Text(
            t('وصف العمل', 'Job Description'),
            style: TextStyle(
                color: dim, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.order['jobDescription'] ?? '',
            style: TextStyle(color: text, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),

          // Location
          Row(
            children: [
              Icon(Icons.location_on, color: gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.order['location'] ?? '',
                  style: TextStyle(color: text, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dates
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: dim, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t('من:', 'From:'),
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.order['startDate'] != null
                          ? _formatDate(
                              _parseDateTime(widget.order['startDate']))
                          : '--',
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: dim, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t('إلى:', 'To:'),
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.order['endDate'] != null
                          ? _formatDate(_parseDateTime(widget.order['endDate']))
                          : '--',
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, color: dim, size: 14),
              const SizedBox(width: 6),
              Text(
                '${t('ساعات العمل اليومية:', 'Daily hours:')} ${widget.order['dailyHours'] ?? 8}',
                style: TextStyle(color: dim, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: border),
          const SizedBox(height: 16),

          // Materials
          if (_materials.isNotEmpty) ...[
            Text(
              t('المواد المطلوبة', 'Required Materials'),
              style: TextStyle(
                  color: dim, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ..._materials.map((m) {
              final name = m['name'] ?? '';
              final qty = m['quantity'] ?? 0;
              final unit = m['unit'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 6, color: gold), // fixed: removed const
                    const SizedBox(width: 8),
                    Text(
                      '$name ($qty ${unit.isNotEmpty ? unit : ''})',
                      style: TextStyle(color: text, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Tools
          if (_tools.isNotEmpty) ...[
            Text(
              t('الأدوات المطلوبة', 'Required Tools'),
              style: TextStyle(
                  color: dim, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tools
                  .map((tool) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: gold.withValues(alpha: 0.2)),
                        ),
                        child: Text(tool,
                            style: TextStyle(color: text, fontSize: 12)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Artisan Response (Schedule)
          if (_schedule.isNotEmpty) ...[
            Divider(color: border),
            const SizedBox(height: 12),
            Text(
              t('جدول العمل المقترح', 'Proposed Work Schedule'),
              style: TextStyle(
                  color: dim, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildHireSchedule(),
          ],

          if ((_artisanResponse?[widget.isArabic ? 'notesAr' : 'notesEn'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: border),
            const SizedBox(height: 12),
            Text(
              t('ملاحظات الحرفي', 'Artisan Notes'),
              style: TextStyle(
                color: dim,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withValues(alpha: 0.20)),
              ),
              child: Text(
                (_artisanResponse?[widget.isArabic ? 'notesAr' : 'notesEn'] ??
                        '')
                    .toString(),
                style: TextStyle(color: text, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHireSchedule() {
    final days = _schedule
        .whereType<Map>()
        .map((day) => Map<String, dynamic>.from(day))
        .toList();

    if (days.isEmpty) return const SizedBox.shrink();

    List<String> tasksOf(Map<String, dynamic> day) =>
        (day['tasks'] as List? ?? const [])
            .map((task) => task.toString())
            .toList();

    final firstTasks = tasksOf(days.first);
    final firstHours = (days.first['hours'] as num?)?.toInt() ?? 0;
    final uniform = days.every((day) {
      final tasks = tasksOf(day);
      final hours = (day['hours'] as num?)?.toInt() ?? 0;
      return hours == firstHours &&
          tasks.join('\u0000') == firstTasks.join('\u0000');
    });

    if (uniform) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('خطة العمل العامة', 'General Work Plan'),
                  style: TextStyle(color: text, fontWeight: FontWeight.bold),
                ),
                Text(
                  t('${days.length} أيام • $firstHours ساعة/يوم',
                      '${days.length} days • $firstHours hours/day'),
                  style: TextStyle(color: dim, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ...firstTasks.map(_buildScheduleTask),
          ],
        ),
      );
    }

    return Column(
      children: days.map((day) {
        final dayNum = day['day'] ?? 0;
        final tasks = tasksOf(day);
        final hours = day['hours'] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${t('اليوم', 'Day')} $dayNum',
                    style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$hours ${t('ساعة', 'hours')}',
                    style: TextStyle(color: dim, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ...tasks.map(_buildScheduleTask),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleTask(String task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 12,
            color: Color(0xFF4CAF50),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(task, style: TextStyle(color: dim, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Ready-Made Price Helpers ─────────────────────────────────────────────
  double _number(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double get _readyMadeUnitPrice {
    // For negotiated Product Offers, totalAmount is the authoritative amount
    // charged by Stripe. For normal orders, fall back to unitPrice/price.
    final quantity = _number(widget.order['quantity'], 1);
    final totalAmount = _number(widget.order['totalAmount']);

    if (totalAmount > 0 && quantity > 0) {
      return totalAmount / quantity;
    }

    return _number(
      widget.order['unitPrice'],
      _number(widget.order['price']),
    );
  }

  double get _readyMadeSubtotal {
    final quantity = _number(widget.order['quantity'], 1);
    final totalAmount = _number(widget.order['totalAmount']);

    if (totalAmount > 0) return totalAmount;
    return _readyMadeUnitPrice * quantity;
  }

  String _money(double value) =>
      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} JOD';

  // ── Ready-Made Details ────────────────────────────────────────────────────
  Widget _buildReadyMadeDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildReadyMadeProductImage(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      widget.order['category'] ?? '',
                      style: GoogleFonts.cairo(color: dim, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: border),
          const SizedBox(height: 16),

          // Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('الكمية', 'Quantity'),
                  style: TextStyle(color: dim, fontSize: 14)),
              Text(
                '${widget.order['quantity'] ?? 1}',
                style: TextStyle(
                    color: text, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('السعر للوحدة', 'Unit Price'),
                  style: TextStyle(color: dim, fontSize: 14)),
              Text(
                _money(_readyMadeUnitPrice),
                style: TextStyle(
                    color: text, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: border),
          const SizedBox(height: 16),

          // Shipping Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_shipping_outlined, color: dim, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('معلومات الشحن', 'Shipping Info'),
                        style: TextStyle(color: dim, fontSize: 13)),
                    Text(
                      t('نابلس، فلسطين', 'Nablus, Palestine'),
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_outlined, color: dim, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('وقت التوصيل المتوقع', 'Estimated Delivery'),
                        style: TextStyle(color: dim, fontSize: 13)),
                    Text(
                      t('٣-٥ أيام عمل', '3-5 business days'),
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyMadeProductImage() {
    String? imageUrl;

    // Normalized order shape used by My Orders.
    final directImage = widget.order['imageUrl']?.toString().trim();
    if (directImage != null &&
        directImage.isNotEmpty &&
        directImage != 'null') {
      imageUrl = directImage;
    }

    // Also support the backend response shape: items[0].imageUrl.
    if (imageUrl == null) {
      final items = widget.order['items'];
      if (items is List && items.isNotEmpty && items.first is Map) {
        final firstItem = Map<String, dynamic>.from(items.first as Map);
        final nestedImage = firstItem['imageUrl']?.toString().trim();
        if (nestedImage != null &&
            nestedImage.isNotEmpty &&
            nestedImage != 'null') {
          imageUrl = nestedImage;
        }
      }
    }

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.inventory_2_outlined,
          color: accent,
        ),
      );
    }

    return Icon(
      widget.order['icon'] is IconData
          ? widget.order['icon'] as IconData
          : Icons.inventory_2_outlined,
      color: accent,
    );
  }

  // ── Pricing ───────────────────────────────────────────────────────────────
  Widget _buildPricing() {
    double subtotal = 0;
    double delivery = 0;
    double total = 0;
    double hireDailyRate = 0;
    double hireMaterialCost = 0;
    int hireDays = 0;

    if (isCustomOrder && _artisanResponse != null) {
      final breakdown = _artisanResponse!['breakdown'] as List? ?? [];
      for (final row in breakdown) {
        subtotal += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      total = subtotal;
    } else if (isHireOrder && _artisanResponse != null) {
      hireDailyRate = (_artisanResponse!['dailyRate'] as num?)?.toDouble() ?? 0;
      hireMaterialCost =
          (_artisanResponse!['materialCost'] as num?)?.toDouble() ?? 0;
      final schedule = _artisanResponse!['schedule'] as List? ?? [];
      hireDays = schedule.length;
      subtotal = hireDailyRate * hireDays;
      total = subtotal + hireMaterialCost;
    } else {
      // Ready-made orders use the amount actually stored/charged for the order.
      // Negotiated Product Offers store the agreed amount in totalAmount.
      subtotal = _readyMadeSubtotal;

      // Do not invent a fixed delivery fee here. Only display a delivery charge
      // when the order itself contains one.
      delivery = _number(
        widget.order['deliveryFee'],
        _number(widget.order['shippingFee']),
      );

      total = subtotal + delivery;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          if (isHireOrder && _artisanResponse != null) ...[
            _buildPriceRow(
              t('السعر اليومي × $hireDays أيام', 'Daily rate × $hireDays days'),
              '${hireDailyRate.toStringAsFixed(0)} × $hireDays = ${subtotal.toStringAsFixed(0)} JOD',
            ),
            const SizedBox(height: 12),
            _buildPriceRow(
              t('تكلفة المواد', 'Material cost'),
              '${hireMaterialCost.toStringAsFixed(0)} JOD',
            ),
          ] else
            _buildPriceRow(t('المجموع الفرعي', 'Subtotal'), _money(subtotal)),
          const SizedBox(height: 12),
          if (!isCustomOrder && !isHireOrder && delivery > 0) ...[
            _buildPriceRow(t('التوصيل', 'Delivery'), _money(delivery)),
            const SizedBox(height: 12),
          ],
          Divider(color: border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('الإجمالي', 'Total'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _money(total),
                style: GoogleFonts.cairo(
                    color: const Color(0xFF4CAF50),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          // Escrow badge
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: gold, size: 14),
                const SizedBox(width: 6),
                Text(
                  t('المبلغ محمي بنظام الضمان (Escrow)',
                      'Amount protected by Escrow'),
                  style: TextStyle(
                      color: gold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(color: dim, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Text(amount,
            style: GoogleFonts.cairo(
                color: text, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Real Chat ─────────────────────────────────────────────────────────────
  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final result = value.toString().trim();
      if (result.isNotEmpty && result.toLowerCase() != 'null') {
        return result;
      }
    }
    return '';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> get _firstOrderItem {
    final items = widget.order['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      return Map<String, dynamic>.from(items.first as Map);
    }
    return <String, dynamic>{};
  }

  String get _chatCraftsmanId {
    final item = _firstOrderItem;
    final craftsman = _asMap(widget.order['Craftsman']);
    final artisan = _asMap(widget.order['Artisan']);
    final itemCraftsman = _asMap(item['Craftsman']);
    final itemArtisan = _asMap(item['Artisan']);

    return _firstNonEmpty([
      widget.order['craftsmanId'],
      widget.order['artisanId'],
      craftsman['id'],
      artisan['id'],
      item['craftsmanId'],
      item['artisanId'],
      itemCraftsman['id'],
      itemArtisan['id'],
    ]);
  }

  String get _chatArtisanName {
    final item = _firstOrderItem;
    final craftsman = _asMap(widget.order['Craftsman']);
    final artisan = _asMap(widget.order['Artisan']);
    final itemCraftsman = _asMap(item['Craftsman']);
    final itemArtisan = _asMap(item['Artisan']);

    return _firstNonEmpty([
      widget.order['artisan'],
      widget.order['artisanName'],
      widget.order['craftsmanName'],
      craftsman['name'],
      artisan['name'],
      item['artisanName'],
      item['craftsmanName'],
      itemCraftsman['name'],
      itemArtisan['name'],
      t('الحرفي', 'Artisan'),
    ]);
  }

  String get _chatArtisanCraft {
    final item = _firstOrderItem;
    final craftsman = _asMap(widget.order['Craftsman']);
    final artisan = _asMap(widget.order['Artisan']);

    return _firstNonEmpty([
      widget.isArabic ? craftsman['craftAr'] : craftsman['craftEn'],
      craftsman['craft'],
      widget.isArabic ? artisan['craftAr'] : artisan['craftEn'],
      artisan['craft'],
      item['craft'],
      widget.order['craft'],
      widget.order['category'],
    ]);
  }

  String? get _chatArtisanAvatar {
    final item = _firstOrderItem;
    final craftsman = _asMap(widget.order['Craftsman']);
    final artisan = _asMap(widget.order['Artisan']);

    final value = _firstNonEmpty([
      craftsman['image'],
      craftsman['profileImage'],
      craftsman['imageUrl'],
      artisan['image'],
      artisan['profileImage'],
      artisan['imageUrl'],
      item['artisanImage'],
      widget.order['artisanImage'],
    ]);

    return value.isEmpty ? null : value;
  }

  String get _chatOrderPrice {
    final raw = widget.order['totalAmount'] ??
        widget.order['price'] ??
        _firstOrderItem['totalAmount'] ??
        _firstOrderItem['price'] ??
        0;

    final number =
        raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (number == null) return '';

    return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 2)} JOD';
  }

  Future<void> _openArtisanChat() async {
    final craftsmanId = _chatCraftsmanId;
    final orderId = widget.order['id']?.toString().trim() ?? '';

    if (craftsmanId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذر تحديد الحرفي المرتبط بهذا الطلب',
              'Could not identify the artisan for this order',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      // ✅ Updated: use otherUserId + otherUserRole
      final chat = await ChatService.createOrGetChat(
        otherUserId: craftsmanId,
        otherUserRole:
            'craftsman', // or 'artisan' depending on your role naming
        orderId: orderId.isEmpty ? null : orderId,
      );

      if (!mounted) return;

      if (chat == null || chat['id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('تعذر فتح المحادثة', 'Could not open chat')),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final currentUserId = await SessionService.getUserId() ?? '';
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            isArabic: widget.isArabic,
            isDarkMode: widget.isDarkMode,
            chatId: chat['id'].toString(),
            currentUserId: currentUserId,
            otherUserId: craftsmanId,
            name: _chatArtisanName,
            craft: _chatArtisanCraft,
            online: false,
            orderTitle: _displayName,
            orderStatus: _status,
            orderPrice: _chatOrderPrice,
            avatarUrl: _chatArtisanAvatar,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[OrderDetailScreen] Open artisan chat error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'حدث خطأ أثناء فتح المحادثة',
              'Failed to open chat',
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Bottom Actions ────────────────────────────────────────────────────────
  Future<void> _openHireProgress() async {
    final requestId = widget.order['id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    try {
      final customerId = await SessionService.getUserId() ?? '';
      if (!mounted) return;

      final provider = context.read<HireOrderProvider>();
      if (customerId.isNotEmpty) {
        await provider.loadForCustomer(customerId);
      }
      if (!mounted) return;

      final request = provider.findRequest(requestId);
      if (request == null) {
        throw Exception(
            t('تعذر تحميل تقدم الطلب', 'Could not load order progress'));
      }

      final percent = request.progressPercent.clamp(0, 100);
      final waitingForConfirmation = percent >= 100;
      final total = request.artisanResponse?.totalPrice ?? 0;
      final adminCommission = total * 0.10;
      final artisanAmount = total - adminCommission;

      String stageLabel() {
        switch (request.progressStage) {
          case 'awaiting_customer_confirmation':
            return t('بانتظار تأكيد استلامك',
                'Awaiting your completion confirmation');
          case 'finalizing':
            return t('اللمسات الأخيرة', 'Finalizing work');
          case 'work_in_progress':
            return t('العمل قيد التنفيذ', 'Work in progress');
          case 'materials_preparation':
            return t('تجهيز المواد', 'Preparing materials');
          default:
            return t('بدأ الحرفي العمل', 'Work started');
        }
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            waitingForConfirmation
                ? t('تأكيد اكتمال العمل', 'Confirm Work Completion')
                : t('تقدم العمل', 'Work Progress'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stageLabel(),
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 9,
                        backgroundColor: gold.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$percent%',
                      style:
                          TextStyle(color: gold, fontWeight: FontWeight.bold)),
                ],
              ),
              if (waitingForConfirmation) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t(
                      'أكدّي فقط إذا استلمتِ العمل وأصبح مكتملًا. بعد التأكيد سيتم تحرير ${artisanAmount.toStringAsFixed(2)} JOD للحرفي وتثبيت ${adminCommission.toStringAsFixed(2)} JOD كعمولة للمنصة.',
                      'Confirm only after receiving the completed work. This releases ${artisanAmount.toStringAsFixed(2)} JOD to the artisan and records ${adminCommission.toStringAsFixed(2)} JOD as the platform commission.',
                    ),
                    style: TextStyle(color: dim, fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('إغلاق', 'Close'), style: TextStyle(color: dim)),
            ),
            if (waitingForConfirmation)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  try {
                    await provider.customerConfirmCompletion(requestId);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (!mounted) return;

                    setState(() => widget.order['status'] = 'completed');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text(t(
                          'تم تأكيد الإنجاز وتحرير مبلغ الضمان للحرفي ✅',
                          'Completion confirmed and Escrow released ✅',
                        )),
                      ),
                    );
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red,
                        content: Text(error.toString()),
                      ),
                    );
                  }
                },
                child: Text(
                  t('تأكيد الاستلام', 'Confirm Completion'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(error.toString()),
        ),
      );
    }
  }

  Widget _buildBottomActions() {
    final isCompleted = _status == 'completed' || _status == 'delivered';
    final isPendingArtisan = _status == 'pending_artisan';
    final isPendingCustomer = _status == 'pending_customer';
    final isInProgress = _status == 'in_progress' || _status == 'accepted';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          if (isPendingArtisan || isPendingCustomer) ...[
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showCancelDialog(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  t('إلغاء الطلب', 'Cancel Order'),
                  style: GoogleFonts.cairo(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isPendingCustomer)
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _showAcceptDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    t('موافقة ودفع', 'Accept & Pay'),
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ] else if (isInProgress) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _openArtisanChat,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  t('مراسلة الحرفي', 'Message Artisan'),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isHireOrder ? _openHireProgress : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  t('تتبع التقدم', 'Track Progress'),
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else if (isCompleted) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openArtisanChat,
                icon:
                    const Icon(Icons.chat_bubble_outline, color: Colors.black),
                label: Text(
                  t('مراسلة الحرفي', 'Contact Artisan'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ] else ...[
            // Default fallback
            Expanded(
              child: ElevatedButton(
                onPressed: _openArtisanChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  t('اتصل بالحرفي', 'Contact Artisan'),
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('إلغاء الطلب', 'Cancel Order'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟',
              'Are you sure you want to cancel this order?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              if (isReadyMade) {
                try {
                  final orderId = widget.order['id'];
                  final response = await ApiService.patch(
                      '/orders/$orderId/status',
                      body: {'status': 'cancelled'});
                  if (response.statusCode == 200) {
                    if (mounted) {
                      setState(() => widget.order['status'] = 'cancelled');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(t('تم إلغاء الطلب', 'Order cancelled')),
                            backgroundColor: Colors.red),
                      );
                    }
                  } else {
                    throw Exception('Failed to cancel');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(t('حدث خطأ', 'An error occurred')),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              } else if (isCustomOrder) {
                final requestId = widget.order['id']?.toString() ?? '';

                if (requestId.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          'تعذر تحديد الطلب',
                          'Could not identify the order',
                        ),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                try {
                  final provider = context.read<CustomOrderProvider>();

                  await provider.customerCancel(requestId);

                  if (!mounted) return;

                  if (provider.error != null) {
                    throw Exception(provider.error);
                  }

                  setState(() {
                    widget.order['status'] = 'cancelled';
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          '✅ تم إلغاء الطلب',
                          '✅ Order cancelled',
                        ),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );

                  Navigator.pop(context, true);
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          'فشل إلغاء الطلب: $e',
                          'Failed to cancel order: $e',
                        ),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } else if (isHireOrder) {
                final requestId = widget.order['id']?.toString() ?? '';
                if (requestId.isEmpty) return;

                try {
                  await context
                      .read<HireOrderProvider>()
                      .customerReject(requestId);

                  if (!mounted) return;
                  setState(() => widget.order['status'] = 'cancelled');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('✅ تم إلغاء الطلب', '✅ Order cancelled')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t(
                          'فشل إلغاء الطلب: $e', 'Failed to cancel order: $e')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t('تم إلغاء الطلب', 'Order cancelled'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(t('نعم، إلغاء', 'Yes, Cancel'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog() {
    if (_isSubmittingPayment) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('تأكيد الطلب', 'Confirm Order'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('سيتم تحويل المبلغ إلى نظام الضمان (Escrow) لحماية الطرفين.',
              'The amount will be transferred to Escrow to protect both parties.'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSubmittingPayment
                ? null
                : () async {
                    Navigator.pop(ctx);
                    if (_isSubmittingPayment) return;
                    setState(() => _isSubmittingPayment = true);

                    if (isReadyMade) {
                      final orderId = widget.order['id']?.toString() ?? '';
                      final addressCtrl = TextEditingController(
                          text: widget.order['shippingAddress'] ?? '');
                      final phoneCtrl = TextEditingController(
                          text: widget.order['customerPhone'] ?? '');

                      final inputDetails =
                          await showDialog<Map<String, String>>(
                        context: context,
                        builder: (actx) => AlertDialog(
                          backgroundColor: surface,
                          title: Text(
                            t('بيانات التوصيل والدفع',
                                'Delivery Details & Payment'),
                            style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('أدخل عنوان التوصيل ورقم الهاتف لإكمال الدفع:',
                                    'Enter delivery address & phone number to proceed with payment:'),
                                style: TextStyle(color: dim, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: addressCtrl,
                                style: TextStyle(color: text),
                                decoration: InputDecoration(
                                  labelText:
                                      t('عنوان التوصيل', 'Delivery Address'),
                                  labelStyle: TextStyle(color: dim),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: text),
                                decoration: InputDecoration(
                                  labelText:
                                      t('رقم الهاتف', 'Customer Phone Number'),
                                  labelStyle: TextStyle(color: dim),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(actx, null),
                              child: Text(t('إلغاء', 'Cancel'),
                                  style: TextStyle(color: dim)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: gold),
                              onPressed: () {
                                if (addressCtrl.text.trim().isEmpty ||
                                    phoneCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(actx).showSnackBar(
                                    SnackBar(
                                      content: Text(t('يرجى ملء كافة الحقول',
                                          'Please fill in all fields')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(actx, {
                                  'address': addressCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                });
                              },
                              child: Text(t('متابعة للدفع', 'Proceed to Pay'),
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (inputDetails == null) {
                        setState(() => _isSubmittingPayment = false);
                        return;
                      }

                      try {
                        final res = await ApiService.post(
                            '/payments/products/checkout',
                            body: {
                              'orderIds': [orderId],
                              'deliveryAddress': inputDetails['address'],
                              'customerPhone': inputDetails['phone'],
                            });

                        if (res.statusCode == 200 || res.statusCode == 201) {
                          final data = jsonDecode(res.body);
                          final checkoutUrl =
                              data['checkoutUrl'] ?? data['url'];
                          if (checkoutUrl != null) {
                            await PaymentService.launchStripeWebCheckout(
                              checkoutUrl: checkoutUrl,
                              darkMode: widget.isDarkMode,
                            );
                            if (mounted) {
                              setState(() {
                                _isSubmittingPayment = false;
                                widget.order['status'] = 'in_progress';
                                widget.order['shippingAddress'] =
                                    inputDetails['address'];
                                widget.order['customerPhone'] =
                                    inputDetails['phone'];
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t(
                                      'تم تحويل الطلب قيد التنفيذ والمبلغ في الضمان',
                                      'Order is now in progress and payment is in Escrow')),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            return;
                          }
                        }
                        throw Exception(t('فشل إنشاء جلسة الدفع',
                            'Failed to create checkout session'));
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isSubmittingPayment = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(t('فشل الدفع: $e', 'Payment failed: $e')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

                    if (isCustomOrder) {
                      final requestId = widget.order['id']?.toString() ?? '';
                      if (requestId.isEmpty) {
                        setState(() => _isSubmittingPayment = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('تعذر تحديد الطلب',
                                'Could not identify the order')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      // Show address/phone input dialog
                      final addressCtrl = TextEditingController();
                      final phoneCtrl = TextEditingController();
                      final inputDetails =
                          await showDialog<Map<String, String>>(
                        context: context,
                        builder: (actx) => AlertDialog(
                          backgroundColor: surface,
                          title: Text(
                            t('بيانات التوصيل والدفع',
                                'Delivery Details & Payment'),
                            style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('أدخل عنوان التوصيل ورقم الهاتف لإكمال الدفع:',
                                    'Enter delivery address & phone number to proceed with payment:'),
                                style: TextStyle(color: dim, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: addressCtrl,
                                style: TextStyle(color: text),
                                decoration: InputDecoration(
                                  labelText:
                                      t('عنوان التوصيل', 'Delivery Address'),
                                  labelStyle: TextStyle(color: dim),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: text),
                                decoration: InputDecoration(
                                  labelText:
                                      t('رقم الهاتف', 'Customer Phone Number'),
                                  labelStyle: TextStyle(color: dim),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(actx, null),
                              child: Text(t('إلغاء', 'Cancel'),
                                  style: TextStyle(color: dim)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: gold),
                              onPressed: () {
                                if (addressCtrl.text.trim().isEmpty ||
                                    phoneCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(actx).showSnackBar(
                                    SnackBar(
                                      content: Text(t('يرجى ملء كافة الحقول',
                                          'Please fill in all fields')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(actx, {
                                  'address': addressCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                });
                              },
                              child: Text(t('متابعة للدفع', 'Proceed to Pay'),
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (inputDetails == null) {
                        setState(() => _isSubmittingPayment = false);
                        return;
                      }

                      // Save the delivery info to the custom order before paying
                      try {
                        final updateOk =
                            await CustomOrderService.updateDeliveryInfo(
                          requestId: requestId,
                          deliveryAddress: inputDetails['address']!,
                          customerPhone: inputDetails['phone']!,
                        );
                        if (!updateOk)
                          throw Exception('Failed to save delivery info');
                      } catch (e) {
                        setState(() => _isSubmittingPayment = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('فشل حفظ معلومات التوصيل',
                                'Failed to save delivery info')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      // Now proceed with payment
                      try {
                        final provider = context.read<CustomOrderProvider>();
                        await provider.acceptAndPay(
                          requestId: requestId,
                          darkMode: widget.isDarkMode,
                        );
                        if (!mounted) return;
                        setState(() {
                          _isSubmittingPayment = false;
                          widget.order['status'] = 'in_progress';
                          widget.order['deliveryAddress'] =
                              inputDetails['address'];
                          widget.order['customerPhone'] = inputDetails['phone'];
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('تم الدفع وتحويل المبلغ للضمان',
                                'Payment successful, amount in Escrow')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isSubmittingPayment = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('فشل قبول العرض: $e',
                                'Failed to accept proposal: $e')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

                    setState(() => _isSubmittingPayment = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t(
                            '✅ تم تأكيد الطلب وإرسال المبلغ للضمان',
                            '✅ Order confirmed and amount sent to Escrow',
                          ),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
            child: Text(t('تأكيد', 'Confirm'),
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }

    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _toEnglish(String arText) {
    // Simple transliteration map for common Arabic field names
    final map = {
      'نوع القطعة': 'Piece Type',
      'نوع الخشب': 'Wood Type',
      'الأبعاد ط ع ار': 'Dimensions',
      'هل تريد نقشاً': 'Add engraving',
      'نص النقش اختياري': 'Engraving text',
      'صور مرجعية': 'Reference images',
      'ملاحظات إضافية': 'Additional notes',
      'المقاس': 'Size',
      'اللون الرئيسي': 'Primary color',
      'نمط التطريز': 'Embroidery pattern',
      'ملاحظات': 'Notes',
    };
    return map[arText] ?? arText.replaceAll('_', ' ');
  }
}
