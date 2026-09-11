import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrderConfirmationScreen — تأكيد الطلب
//
// يستقبل قائمة طلبات حقيقية من الباك إند (orders).
// يعرض رقم الطلب إذا كان طلباً واحداً، أو عدد الطلبات وأرقامها إذا كانت متعددة.
// لا يستخدم DateTime لتوليد رقم الطلب أبداً.
// ─────────────────────────────────────────────────────────────────────────────

class OrderConfirmationScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDarkMode;

  /// قائمة الطلبات الحقيقية القادمة من الباك إند
  final List<Map<String, dynamic>> orders;

  const OrderConfirmationScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.orders,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  bool get _isSingleOrder => orders.length == 1;

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white60 : Colors.black54;
    final accent = const Color(0xFFD4A017);
    final green = const Color(0xFF4CAF50);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: text),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ── Success Icon ───────────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.check_circle, color: green, size: 80),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ──────────────────────────────────────────────────────
              Text(
                t('تم استلام طلبك بنجاح! ✅', 'Order Received Successfully! ✅'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSingleOrder
                    ? t('تم إنشاء طلب واحد', '1 order was placed')
                    : t(
                        'تم إنشاء ${orders.length} طلبات بنجاح',
                        '${orders.length} orders were placed successfully',
                      ),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: dim, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // ── Order ID(s) ────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isSingleOrder
                              ? t('رقم الطلب', 'Order Number')
                              : t('أرقام الطلبات', 'Order Numbers'),
                          style: GoogleFonts.cairo(
                            color: dim,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...orders.map((order) {
                      final id = order['id']?.toString() ?? '—';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            id,
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Info message ───────────────────────────────────────────────
              Text(
                t(
                  'عادةً ما يقوم الحرفي بالرد خلال ٢٤-٤٨ ساعة.\nسنقوم بإعلامك فور تحديث حالة الطلب.',
                  'The craftsman usually responds within 24-48 hours.\nWe will notify you when the order status updates.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: dim, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 36),

              // ── View My Orders Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: const Icon(Icons.list_alt_rounded, color: Colors.black),
                  label: Text(
                    t('متابعة طلباتي', 'View My Orders'),
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Back to Home Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: dim.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    t('العودة للرئيسية', 'Back to Home'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
