import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import '../../services/ai_service.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? order;

  const DeliveryOrderDetailScreen({
    super.key,
    this.orderId,
    this.order,
  });

  @override
  State<DeliveryOrderDetailScreen> createState() =>
      _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _aiEstimation;
  bool _isLoading = false;
  bool _isEstimatingAi = false;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _orderData = widget.order;
    } else if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _fetchOrderDetail();
    }
  }

  Map<String, dynamic>? _asMap(dynamic item) {
    if (item is Map) {
      return Map<String, dynamic>.from(item);
    } else if (item is List && item.isNotEmpty && item.first is Map) {
      return Map<String, dynamic>.from(item.first);
    }
    return null;
  }

  Future<void> _fetchOrderDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await DeliveryService.getOrderById(widget.orderId!);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _orderData = data;
        } else {
          _errorMessage = 'Order not found or failed to load.';
        }
      });
    }
  }

  Future<void> _fetchAiEstimation() async {
    if (_orderData == null) return;

    setState(() => _isEstimatingAi = true);

    try {
      final estimation = await AiService.estimateDeliveryInfo(
        pickupAddress: _orderData!['pickupAddress'] ?? '',
        dropoffAddress: _orderData!['dropoffAddress'] ?? '',
        distanceKm: num.tryParse(_orderData!['distanceKm']?.toString() ?? '0')
                ?.toDouble() ??
            1.0,
        weightKg: num.tryParse(_orderData!['weightKg']?.toString() ?? '0')
                ?.toDouble() ??
            1.0,
        isFragile: _orderData!['isFragile'] == true,
        productName: _orderData!['productName'] ?? '',
      );

      if (mounted) {
        setState(() {
          _aiEstimation = estimation;
          _isEstimatingAi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isEstimatingAi = false);
    }
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

  void _showManualPhoneCallDialog(BuildContext context, bool isAr) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'الاتصال بالعميل' : 'Call Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'أدخل رقم هاتف العميل للاتصال بها/به:'
                  : 'Enter customer phone number to dial:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '05xxxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final p = phoneController.text.trim();
              Navigator.pop(ctx);
              if (p.isNotEmpty) {
                _makePhoneCall(p);
              }
            },
            icon: const Icon(Icons.phone, color: Colors.white, size: 18),
            label: Text(isAr ? 'اتصال' : 'Call',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPinVerificationDialog(BuildContext context, bool isAr) {
    final pinController = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title:
              Text(isAr ? 'تأكيد الرمز السرّي' : 'Enter Customer Delivery PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr
                    ? 'يرجى إدخال رمز التأكيد التابع للعميل لتسليم الشحنة:'
                    : 'Ask customer for their 4-digit order confirmation PIN:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: pinError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A017)),
              onPressed: () {
                final enteredPin = pinController.text.trim();
                if (enteredPin.length < 4) {
                  setModalState(() {
                    pinError = isAr ? 'يرجى إدخال 4 أرقام' : 'Enter 4 digits';
                  });
                  return;
                }

                Navigator.pop(ctx);
                _handleConfirmDeliveryWithPin(enteredPin);
              },
              child: Text(
                isAr ? 'تأكيد التسليم' : 'Verify & Complete',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, bool isAr) {
    String selectedReasonKey = 'customer_unreachable';
    final notesController = TextEditingController();

    final Map<String, Map<String, String>> reasonsMap = {
      'customer_unreachable': {
        'ar': 'العميل لا يجيب / يتعذر الوصول إليه',
        'en': 'Customer unreachable / No response'
      },
      'incorrect_address': {
        'ar': 'عنوان التسليم غير صحيح',
        'en': 'Incorrect delivery address'
      },
      'item_damaged': {
        'ar': 'الشحنة متضررة أو تالفة',
        'en': 'Item damaged or broken'
      },
      'vehicle_issue': {
        'ar': 'عطل في مركبة التوصيل',
        'en': 'Vehicle breakdown or emergency'
      },
      'other': {'ar': 'سبب آخر', 'en': 'Other reason'}
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title:
              Text(isAr ? 'إلغاء / الإبلاغ عن مشكلة' : 'Cancel / Report Issue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? 'اختر سبب إلغاء الطلب:'
                      : 'Select reason for cancellation:',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReasonKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: reasonsMap.entries.map((entry) {
                    final label =
                        isAr ? entry.value['ar']! : entry.value['en']!;
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedReasonKey = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isAr
                        ? 'ملاحظات إضافية (اختياري)...'
                        : 'Additional details (optional)...',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'رجوع' : 'Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final reasonLabel = isAr
                    ? reasonsMap[selectedReasonKey]!['ar']!
                    : reasonsMap[selectedReasonKey]!['en']!;
                final notes = notesController.text.trim();
                final fullNotes =
                    notes.isNotEmpty ? '$reasonLabel - $notes' : reasonLabel;

                Navigator.pop(ctx);
                _handleCancelOrder(
                  issueType: selectedReasonKey,
                  notes: fullNotes,
                );
              },
              child: Text(
                isAr ? 'تأكيد الإلغاء' : 'Confirm Cancel',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelOrder({
    required String issueType,
    required String notes,
  }) async {
    final orderId = _orderData?['id']?.toString() ?? widget.orderId;
    if (orderId == null || orderId.isEmpty) return;

    setState(() => _isUpdating = true);

    final result = await DeliveryService.reportDeliveryIssue(
      orderId: orderId,
      status: 'cancelled',
      issueType: issueType,
      notes: notes,
    );

    if (!mounted) return;

    setState(() => _isUpdating = false);
    final isAr = context.read<AppState>().isArabic;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr
              ? 'تم إلغاء الطلب وتسجيل السبب بنجاح'
              : 'Order cancelled successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr
              ? 'فشل إلغاء الطلب، يرجى المحاولة لاحقاً'
              : 'Failed to cancel order, please try again'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleConfirmDeliveryWithPin(String pin) async {
    final orderId = _orderData?['id']?.toString() ?? widget.orderId;
    if (orderId == null || orderId.isEmpty) return;

    setState(() => _isUpdating = true);

    final result = await DeliveryService.verifyDeliveryPinOrQR(
      orderId: orderId,
      pin: pin,
    );

    if (!mounted) return;

    setState(() => _isUpdating = false);
    final isAr = context.read<AppState>().isArabic;

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr
              ? '✅ تم تأكيد التوصيل وتحرير المبلغ بنجاح!'
              : '✅ Delivery verified & escrow released successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final errorMsg = result?['error'] ??
          (isAr ? 'رمز التأكيد غير صحيح' : 'Invalid PIN code');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAr = appState.isArabic;
    final isDark = appState.isDarkMode;

    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F6F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final dim = isDark ? Colors.white70 : Colors.black54;
    final cardBg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final cardBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
    final accent = const Color(0xFFD4A017);

    final currentOrderId = _orderData?['orderCode'] ??
        _orderData?['id']?.toString() ??
        widget.orderId ??
        '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFFD4A017), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${isAr ? 'تفاصيل الطلب' : 'Order Details'} $currentOrderId',
          style: TextStyle(
              color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body:
          _buildBody(isAr, isDark, textColor, dim, cardBg, cardBorder, accent),
    );
  }

  Widget _buildBody(
    bool isAr,
    bool isDark,
    Color textColor,
    Color dim,
    Color cardBg,
    Color cardBorder,
    Color accent,
  ) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    if (_errorMessage != null || _orderData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
                _errorMessage ??
                    (isAr ? 'لم يتم العثور على الطلب' : 'Order not found'),
                style: TextStyle(color: textColor, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrderDetail,
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                  style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    final order = _orderData!;
    final status = order['status']?.toString() ?? 'active';
    final isActive = status == 'active';
    final isCancelled = status == 'cancelled' ||
        status == 'undelivered' ||
        status == 'returned';
    final isFragile = order['isFragile'] == true;

    final cancelReason = order['cancelReason'] ??
        order['cancellationReason'] ??
        order['issueNotes'] ??
        order['issueType'] ??
        order['notes'];

    // Associated Models
    final customerMap = _asMap(order['customer']);
    final craftsmanMap = _asMap(order['craftsman']);
    final productMap = _asMap(order['product']);

    // User details with DB association fallback
    final customerName = customerMap?['name']?.toString() ??
        (isAr ? order['customerName'] : order['customerNameEn'])?.toString() ??
        order['customerName']?.toString() ??
        (isAr ? 'عميل كرافت جو' : 'CraftGo Customer');

    final customerPhone = customerMap?['phone']?.toString() ??
        order['customerPhone']?.toString() ??
        '';

    final craftsmanName = craftsmanMap?['name']?.toString() ??
        (isAr ? 'حرفي كرافت جو' : 'CraftGo Artisan');

    final craftsmanPhone = craftsmanMap?['phone']?.toString() ??
        order['pickupPhone']?.toString() ??
        '';

    // Addresses with locale fallback
    final pickup = isAr
        ? (order['pickupAddress'] ?? order['pickupAddressEn'])
        : (order['pickupAddressEn'] ?? order['pickupAddress']);

    final dropoff = isAr
        ? (order['dropoffAddress'] ?? order['dropoffAddressEn'])
        : (order['dropoffAddressEn'] ?? order['dropoffAddress']);

    // Item specifications
    final productTitle = isAr
        ? (productMap?['titleAr'] ?? order['productName'])
        : (productMap?['titleEn'] ??
            order['productNameEn'] ??
            order['productName']);

    final weight =
        num.tryParse(order['weightKg']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final distance =
        num.tryParse(order['distanceKm']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final earnings =
        num.tryParse(order['earningAmount']?.toString() ?? '0')?.toDouble() ??
            0.0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Cancel Reason banner if order was cancelled
                if (isCancelled) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel_outlined,
                            color: Colors.red, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'سبب الإلغاء:' : 'Cancellation Reason:',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cancelReason?.toString() ??
                                    (isAr
                                        ? 'لم يتم تحديد سبب الإلغاء'
                                        : 'No specific reason provided'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: order['id']?.toString() ?? '',
                      version: QrVersions.auto,
                      size: 150.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Badges
                Row(
                  children: [
                    if (order['isBatch'] == true || (order['totalItemsCount'] as int? ?? 0) > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          isAr
                              ? '📦 شحنة مجمعة (${order['totalItemsCount'] ?? 2} طلبات)'
                              : '📦 Batch Delivery (${order['totalItemsCount'] ?? 2} Items)',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    if (isFragile)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(isAr ? '⚠️ قابل للكسر' : '⚠️ Fragile',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${isAr ? "الوزن" : "Weight"}: ${weight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Item Specifications Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'مواصفات الشحنة' : 'Package Specs',
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                          icon: Icons.inventory_2_outlined,
                          label: isAr ? 'المنتج' : 'Product',
                          value: productTitle?.toString() ?? 'N/A',
                          textColor: textColor,
                          dim: dim),
                      const SizedBox(height: 8),
                      _infoRow(
                          icon: Icons.straighten,
                          label: isAr ? 'المسافة' : 'Distance',
                          value: '$distance km',
                          textColor: textColor,
                          dim: dim),
                      const SizedBox(height: 8),
                      _infoRow(
                          icon: Icons.attach_money,
                          label: isAr ? 'الأرباح' : 'Earnings',
                          value: '₪${earnings.toStringAsFixed(2)}',
                          textColor: textColor,
                          dim: dim,
                          iconColor: Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // AI Estimation Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: accent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isAr
                                    ? 'تقدير وقت التوصيل (AI)'
                                    : 'AI Delivery Estimate',
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                          if (_aiEstimation == null)
                            TextButton(
                              onPressed:
                                  _isEstimatingAi ? null : _fetchAiEstimation,
                              child: _isEstimatingAi
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(isAr ? 'احسب الآن' : 'Calculate'),
                            ),
                        ],
                      ),
                      if (_aiEstimation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${isAr ? "الوقت المتوقع" : "ETA"}: ${_aiEstimation!['estimatedMinutes']} ${isAr ? "دقيقة" : "mins"}',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? (_aiEstimation!['handlingNotesAr'] ?? '')
                              : (_aiEstimation!['handlingNotesEn'] ?? ''),
                          style: TextStyle(color: dim, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Craftsman Section
                _infoRow(
                  icon: Icons.storefront,
                  label: isAr ? 'الحرفي' : 'Craftsman',
                  value: '$craftsmanName',
                  textColor: textColor,
                  dim: dim,
                  iconColor: Colors.amber,
                  phoneCall: craftsmanPhone.isNotEmpty
                      ? () => _makePhoneCall(craftsmanPhone)
                      : null,
                ),
                const SizedBox(height: 8),
                _infoRow(
                    icon: Icons.location_on_outlined,
                    label: isAr ? 'الاستلام' : 'Pickup',
                    value: pickup?.toString() ?? '',
                    textColor: textColor,
                    dim: dim,
                    iconColor: Colors.blueAccent),
                if (craftsmanPhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(craftsmanPhone),
                      icon: const Icon(Icons.phone_outlined,
                          color: Colors.amber, size: 18),
                      label: Text(
                        isAr
                            ? 'الاتصال بالحرفي ($craftsmanPhone)'
                            : 'Call Craftsman ($craftsmanPhone)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),

                // Customer Section
                _infoRow(
                  icon: Icons.person_outline,
                  label: isAr ? 'العميل' : 'Customer',
                  value: '$customerName',
                  textColor: textColor,
                  dim: dim,
                  phoneCall: () {
                    if (customerPhone.isNotEmpty) {
                      _makePhoneCall(customerPhone);
                    } else {
                      _showManualPhoneCallDialog(context, isAr);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _infoRow(
                    icon: Icons.location_on,
                    label: isAr ? 'التسليم' : 'Dropoff',
                    value: dropoff?.toString() ?? '',
                    textColor: textColor,
                    dim: dim,
                    iconColor: Colors.redAccent),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: customerPhone.isNotEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(customerPhone),
                          icon: const Icon(Icons.phone_in_talk_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                            isAr
                                ? 'الاتصال بالعميل ($customerPhone)'
                                : 'Call Customer ($customerPhone)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () =>
                              _showManualPhoneCallDialog(context, isAr),
                          icon: Icon(Icons.phone_in_talk_rounded,
                              color: Colors.green.shade400, size: 18),
                          label: Text(
                            isAr ? 'الاتصال بالعميل' : 'Call Customer',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade400,
                                fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.green.shade600),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        // Action panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: cardBorder))),
          child: _isUpdating
              ? const SizedBox(
                  height: 52,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFD4A017))))
              : isActive
                  ? Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showCancelOrderDialog(context, isAr),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isAr ? 'إلغاء الطلب' : 'Cancel Order',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showPinVerificationDialog(context, isAr),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.black),
                              label: Text(
                                isAr
                                    ? 'تأكيد التوصيل (PIN)'
                                    : 'Confirm Delivery (PIN)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(isAr ? 'رجوع' : 'Back',
                            style: TextStyle(
                                color: dim, fontWeight: FontWeight.bold)),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color dim,
    Color? iconColor,
    VoidCallback? phoneCall,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor ?? dim, size: 20),
        const SizedBox(width: 10),
        SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: dim, fontSize: 13))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500))),
        if (phoneCall != null)
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.green, size: 22),
            onPressed: phoneCall,
            tooltip: 'Call',
          ),
      ],
    );
  }
}
