import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/dispute_service.dart';

class CraftsmanReviewCustomerScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String customerName;
  final String orderId;

  const CraftsmanReviewCustomerScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.customerName,
    required this.orderId,
  });

  @override
  State<CraftsmanReviewCustomerScreen> createState() => _CraftsmanReviewCustomerScreenState();
}

class _CraftsmanReviewCustomerScreenState extends State<CraftsmanReviewCustomerScreen> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى اختيار التقييم بالنجوم', 'Please select a star rating')),
          backgroundColor: accent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4A017)),
      ),
    );

    try {
      final response = await ApiService.post(
        '/reviews/customer',
        body: {
          'orderId': widget.orderId,
          'rating': _rating,
          'commentAr': widget.isArabic ? _commentController.text : '',
          'commentEn': widget.isArabic ? '' : _commentController.text,
        },
      );

      dynamic body = <String, dynamic>{};
      if (response.body.isNotEmpty) {
        try {
          body = jsonDecode(response.body);
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.pop(context); // loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, _rating); // return rating to orders screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('تم تقييم الزبون بنجاح!', 'Customer rated successfully!')),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      if (response.statusCode == 409) {
        final existing = body is Map ? body['review'] : null;
        final existingRating = existing is Map ? existing['rating'] : null;
        Navigator.pop(context, existingRating ?? _rating);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('تم تقييم هذا الزبون مسبقًا', 'Customer already rated for this order')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final message = body is Map
          ? (body['error'] ?? body['message'] ?? 'Failed to submit review').toString()
          : 'Failed to submit review';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تعذر إرسال التقييم', 'Could not submit review')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Report Issue Dialog ───────────────────────────────────────────────────────
  void _showReportDialog() {
    String _selectedCategory = 'other';
    final _descController = TextEditingController();
    bool _submitting = false;

    final categories = [
      ['customer_unresponsive', t('العميل لا يرد', 'Customer Unresponsive')],
      ['quality_issue',         t('سلوك غير لائق', 'Inappropriate Behaviour')],
      ['other',                 t('أخرى', 'Other')],
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            t('إبلاغ عن مشكلة', 'Report an Issue'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('نوع المشكلة', 'Issue Category'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 13)),
                const SizedBox(height: 8),
                ...categories.map((cat) => RadioListTile<String>(
                  value: cat[0],
                  groupValue: _selectedCategory,
                  onChanged: (v) => setDialogState(() => _selectedCategory = v!),
                  title: Text(cat[1], style: GoogleFonts.cairo(color: text, fontSize: 14)),
                  activeColor: accent,
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  style: TextStyle(color: text),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: t('صف المشكلة بالتفصيل...', 'Describe the issue in detail...'),
                    hintStyle: TextStyle(color: dim),
                    filled: true,
                    fillColor: bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _submitting ? null : () async {
                if (_descController.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t('يرجى إدخال وصف بأكثر من 10 أحرف', 'Please enter at least 10 characters')),
                    backgroundColor: Colors.orange,
                  ));
                  return;
                }
                setDialogState(() => _submitting = true);
                try {
                  await DisputeService.submitDispute(
                    orderId: widget.orderId,
                    issueCategory: _selectedCategory,
                    description: _descController.text.trim(),
                    requestedAction: 'none',
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('تم إرسال البلاغ للإدارة بنجاح', 'Report sent to admin successfully')),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  setDialogState(() => _submitting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('فشل الإرسال: $e', 'Submit failed: $e')),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                }
              },
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(t('إرسال البلاغ', 'Submit Report'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

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
            icon: Icon(widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('تقييم الزبون', 'Rate Customer'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: accent.withValues(alpha: 0.1),
                child: Icon(Icons.person, size: 40, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                t('كيف كانت تجربتك مع الزبون؟', 'How was your experience with the customer?'),
                style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.customerName,
                style: GoogleFonts.cairo(color: dim, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: accent,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _commentController,
                style: TextStyle(color: text),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t('أضف تعليقاً (اختياري)', 'Add a comment (Optional)'),
                  hintStyle: TextStyle(color: dim),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    t('إرسال التقييم', 'Submit Review'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Report Issue Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _showReportDialog,
                  icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 18),
                  label: Text(
                    t('إبلاغ عن مشكلة', 'Report an Issue'),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
