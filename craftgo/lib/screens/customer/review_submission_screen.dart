import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/dispute_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReviewSubmissionScreen — تقديم تقييم
// ─────────────────────────────────────────────────────────────────────────────

class ReviewSubmissionScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic> order;

  const ReviewSubmissionScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.order,
  });

  @override
  State<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends State<ReviewSubmissionScreen> {
  int _selectedRating = 5;
  bool _isSubmitting = false;
  bool _reviewSubmitted = false;
  final TextEditingController _commentController = TextEditingController();

  // Theme colors
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  final List<String> _tagsAr = ['ممتاز جداً', 'سريع بالعمل', 'سعر مناسب', 'دقيق ومحترف', 'خلوق ومحترم'];
  final List<String> _tagsEn = ['Excellent', 'Fast Worker', 'Fair Price', 'Very Accurate', 'Polite'];
  final Set<int> _selectedTags = {};

  Future<void> _submitReview() async {
    if (_reviewSubmitted || _isSubmitting) return;

    final orderId = widget.order['id']?.toString() ?? '';
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(t('تعذر تحديد الطلب', 'Could not identify the order')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final selectedTagText = _selectedTags
          .map((index) => t(_tagsAr[index], _tagsEn[index]))
          .join(', ');
      final typedComment = _commentController.text.trim();
      final fullComment = [
        if (selectedTagText.isNotEmpty) selectedTagText,
        if (typedComment.isNotEmpty) typedComment,
      ].join(' — ');

      final response = await ApiService.post(
        '/reviews',
        body: {
          'orderId': orderId,
          'rating': _selectedRating,
          'commentAr': widget.isArabic && fullComment.isNotEmpty
              ? fullComment
              : null,
          'commentEn': !widget.isArabic && fullComment.isNotEmpty
              ? fullComment
              : null,
        },
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode != 201) {
        final message = decoded is Map
            ? decoded['error'] ?? decoded['message']
            : null;
        throw Exception(message?.toString() ?? 'Failed to submit review');
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _reviewSubmitted = true;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Directionality(
            textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4CAF50),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t('شكرًا لتقييمك!', 'Thank you!'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('يساعد تقييمك في تحسين جودة خدمات كرافت جو ومساعدة الآخرين.', 'Your feedback helps improve CraftGo services.'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: dim,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        // Close the success dialog and this review screen only.
                        // The caller (My Orders) stays alive with its logged-in
                        // customer session and refreshes the review state.
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        t('العودة لطلباتي', 'Back to My Orders'),
                        style: GoogleFonts.cairo(
                          color: widget.isDarkMode ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Report Issue Dialog (Customer side) ─────────────────────────────
  void _showReportDialog() {
    String _selectedCategory = 'other';
    String _selectedAction = 'refund';
    final _descController = TextEditingController();
    bool _submitting = false;

    final categories = [
      ['damaged_in_transit', t('تلف أثناء التوصيل', 'Damaged in Transit')],
      ['wrong_item',         t('منتج خاطئ', 'Wrong Item Delivered')],
      ['quality_issue',      t('جودة رديئة', 'Quality Issue')],
      ['other',              t('أخرى', 'Other')],
    ];

    final rawId = widget.order['id']?.toString() ?? '';
    final orderType = widget.order['type']?.toString();
    final customOrderRequestId = widget.order['customOrderRequestId']?.toString() ??
        (orderType == 'custom' ? rawId : null);
    final hireRequestId = widget.order['hireRequestId']?.toString() ??
        (orderType == 'hire' ? rawId : null);
    final orderId = (customOrderRequestId == null && hireRequestId == null) ? rawId : null;
    final deliveryOrderId = widget.order['deliveryOrderId']?.toString() ??
        widget.order['DeliveryOrder']?['id']?.toString();

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
                const SizedBox(height: 6),
                ...categories.map((cat) => RadioListTile<String>(
                  value: cat[0],
                  groupValue: _selectedCategory,
                  onChanged: (v) => setDialogState(() => _selectedCategory = v!),
                  title: Text(cat[1], style: GoogleFonts.cairo(color: text, fontSize: 14)),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                )),
                const Divider(height: 24),
                Text(t('ماذا تريد؟', 'What resolution do you want?'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 13)),
                const SizedBox(height: 6),
                RadioListTile<String>(
                  value: 'refund',
                  groupValue: _selectedAction,
                  onChanged: (v) => setDialogState(() => _selectedAction = v!),
                  title: Text(t('استرداد المبلغ', 'Full Refund'), style: GoogleFonts.cairo(color: text, fontSize: 14)),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'none',
                  groupValue: _selectedAction,
                  onChanged: (v) => setDialogState(() => _selectedAction = v!),
                  title: Text(t('حل ودي فقط', 'Just Report (No Refund)'), style: GoogleFonts.cairo(color: text, fontSize: 14)),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                ),
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
                    orderId: orderId,
                    customOrderRequestId: customOrderRequestId,
                    hireRequestId: hireRequestId,
                    deliveryOrderId: deliveryOrderId,
                    issueCategory: _selectedCategory,
                    description: _descController.text.trim(),
                    requestedAction: _selectedAction,
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
            t('تقييم الخدمة', 'Rate Service'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          children: [
            // Order Card Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.handyman_outlined, color: accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isArabic ? widget.order['nameAr'] ?? 'خدمة' : widget.order['nameEn'] ?? 'Service',
                          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          widget.order['artisan'] ?? '',
                          style: GoogleFonts.cairo(color: dim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Rating Stars
            Center(
              child: Text(
                t('كيف كانت تجربتك؟', 'How was your experience?'),
                style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _selectedRating;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starIndex;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    transform: isSelected ? Matrix4.diagonal3Values(1.15, 1.15, 1.0) : Matrix4.identity(),
                    child: Icon(
                      Icons.star,
                      size: 46,
                      color: isSelected ? Colors.amber : dim.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Quick Feedback Tags
            Text(
              t('ما أكثر ما أعجبك؟', 'What did you like the most?'),
              style: GoogleFonts.cairo(color: text, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(5, (index) {
                final tag = t(_tagsAr[index], _tagsEn[index]);
                final isSelected = _selectedTags.contains(index);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(index);
                      } else {
                        _selectedTags.add(index);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isSelected ? accent : border),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.cairo(
                        color: isSelected
                            ? (widget.isDarkMode ? Colors.black : Colors.white)
                            : text,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Comment text area
            Text(
              t('اكتب تعليقاً إضافياً (اختياري)', 'Write a comment (Optional)'),
              style: GoogleFonts.cairo(color: text, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: text),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t('أدخل تعليقك هنا...', 'Enter your comment here...'),
                  hintStyle: TextStyle(color: dim),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                (_reviewSubmitted || _isSubmitting) ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
                    : Text(
                  t('إرسال التقييم', 'Submit Review'),
                  style: GoogleFonts.cairo(
                    color:
                    widget.isDarkMode ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Report Issue Button
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
