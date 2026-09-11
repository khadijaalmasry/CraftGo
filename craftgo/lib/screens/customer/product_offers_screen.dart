import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/products_service.dart';
import '../../services/api_service.dart';

class ProductOffersScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const ProductOffersScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<ProductOffersScreen> createState() => _ProductOffersScreenState();
}

class _ProductOffersScreenState extends State<ProductOffersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = [];

  Timer? _paymentPollTimer;
  String? _pendingSessionId;
  bool _checkingPayment = false;
  int _paymentPollAttempts = 0;

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get gold => const Color(0xFFE2AA08);
  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    super.dispose();
  }

  void _startPaymentStatusPolling(String sessionId) {
    _paymentPollTimer?.cancel();
    _pendingSessionId = sessionId;
    _paymentPollAttempts = 0;

    // Check immediately, then keep checking while Stripe is open.
    _checkPaymentStatus();

    _paymentPollTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _checkPaymentStatus(),
    );
  }

  Future<void> _checkPaymentStatus() async {
    final sessionId = _pendingSessionId;
    if (sessionId == null || _checkingPayment) return;

    // Stop after about 4 minutes. Manual refresh will still work afterwards.
    _paymentPollAttempts++;
    if (_paymentPollAttempts > 120) {
      _paymentPollTimer?.cancel();
      _paymentPollTimer = null;
      return;
    }

    _checkingPayment = true;
    try {
      final response =
      await ApiService.get('/payments/products/status/$sessionId');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final body = jsonDecode(response.body);

        if (body is Map && body['paid'] == true) {
          _paymentPollTimer?.cancel();
          _paymentPollTimer = null;
          _pendingSessionId = null;

          await _load();

          if (mounted) {
            _message(
              t(
                'تم الدفع بنجاح والمبلغ محفوظ في الضمان ✅',
                'Payment successful — money is held in Escrow ✅',
              ),
            );
          }
        }
      }
    } catch (_) {
      // Stripe may still be open or the backend may still be processing.
      // Keep polling silently.
    } finally {
      _checkingPayment = false;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final values = await ProductsService.getMyCustomerOffers();
      if (mounted) {
        setState(() => _offers = values
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _customerRespond(Map<String, dynamic> offer, String action) async {
    try {
      await ProductsService.customerOfferResponse(offer['id'].toString(), action: action);
      await _load();
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  Future<void> _pay(Map<String, dynamic> offer) async {
    final controller = TextEditingController();
    final address = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('عنوان التوصيل', 'Delivery address'), style: TextStyle(color: text)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: text),
          decoration: InputDecoration(
            hintText: t('نابلس، الشارع، المبنى...', 'Nablus, street, building...'),
            hintStyle: TextStyle(color: dim),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(t('متابعة', 'Continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (address == null) return;

    try {
      final created = await ProductsService.createOrderFromOffer(
        offer['id'].toString(),
        deliveryAddress: address,
      );
      final order = Map<String, dynamic>.from(created['order'] as Map);
      final checkout =
      await ProductsService.startProductCheckout([order['id'].toString()]);

      final checkoutUrl = checkout['checkoutUrl']?.toString() ?? '';
      final sessionId = checkout['sessionId']?.toString() ?? '';

      if (checkoutUrl.isEmpty || sessionId.isEmpty) {
        throw Exception('Invalid Stripe Checkout response');
      }

      // Start watching this Stripe session before opening the new tab.
      // Once Stripe redirects to our success endpoint, the backend marks
      // the order as paid and changes the offer status to "paid".
      _startPaymentStatusPolling(sessionId);

      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!opened) {
        _paymentPollTimer?.cancel();
        _paymentPollTimer = null;
        _pendingSessionId = null;
        throw Exception('Could not open Stripe Checkout');
      }

      _message(
        t(
          'أكملي الدفع في Stripe ثم ارجعي إلى CraftGo',
          'Complete payment in Stripe, then return to CraftGo',
        ),
      );
    } catch (e) {
      _message(e.toString(), error: true);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Colors.redAccent : Colors.green,
    ));
  }

  String _status(String value) {
    const en = {
      'pending': 'Waiting for artisan',
      'countered': 'Counter-offer received',
      'accepted': 'Offer accepted',
      'rejected': 'Offer rejected',
      'paid': 'Paid — held in Escrow',
    };
    const ar = {
      'pending': 'بانتظار الحرفي',
      'countered': 'وصل عرض مضاد',
      'accepted': 'تم قبول العرض',
      'rejected': 'تم رفض العرض',
      'paid': 'مدفوع ومحفوظ في الضمان',
    };
    return (widget.isArabic ? ar : en)[value] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: text,
        title: Text(t('عروض أسعار المنتجات', 'Product Price Offers'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: gold))
          : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: Colors.redAccent)))
          : _offers.isEmpty
          ? Center(child: Text(t('لا توجد عروض أسعار بعد', 'No price offers yet'), style: TextStyle(color: dim)))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _offers.length,
          itemBuilder: (_, index) => _card(_offers[index]),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> offer) {
    final product = offer['product'] is Map
        ? Map<String, dynamic>.from(offer['product'] as Map)
        : <String, dynamic>{};
    final status = offer['status']?.toString() ?? 'pending';
    final offered = offer['offeredUnitPrice'] ?? 0;
    final counter = offer['counterUnitPrice'];
    final accepted = offer['acceptedUnitPrice'];
    final effective = accepted ?? counter ?? offered;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status == 'countered' ? gold : Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product['titleEn']?.toString() ?? t('منتج', 'Product'),
            style: GoogleFonts.cairo(color: text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_status(status), style: GoogleFonts.cairo(color: status == 'rejected' ? Colors.redAccent : gold)),
        const Divider(height: 24),
        _line(t('السعر الأصلي', 'List price'), '${offer['originalUnitPrice']} JOD'),
        _line(t('عرضك', 'Your offer'), '$offered JOD'),
        if (counter != null) _line(t('عرض الحرفي المضاد', 'Artisan counter-offer'), '$counter JOD'),
        _line(t('الكمية', 'Quantity'), '${offer['quantity'] ?? 1}'),
        if (status == 'countered') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _customerRespond(offer, 'reject'), child: Text(t('رفض', 'Reject')))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => _customerRespond(offer, 'accept'), child: Text(t('قبول $effective', 'Accept $effective JOD')))),
          ]),
        ],
        if (status == 'accepted') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pay(offer),
              icon: const Icon(Icons.lock_outline),
              label: Text(t('إنشاء الطلب والدفع', 'Create Order & Pay')),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.cairo(color: dim))),
      Text(value, style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
    ]),
  );
}
