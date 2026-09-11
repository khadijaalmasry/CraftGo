import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/ai_service.dart';
import '../../services/exhibitions_service.dart';
import 'exhibition_registration_screen.dart';

class CraftsmanExhibitionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exhibition;
  final String craftsmanId;
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic>? registration;

  const CraftsmanExhibitionDetailScreen({
    super.key,
    required this.exhibition,
    required this.craftsmanId,
    required this.isArabic,
    required this.isDarkMode,
    this.registration,
  });

  @override
  State<CraftsmanExhibitionDetailScreen> createState() =>
      _CraftsmanExhibitionDetailScreenState();
}

class _CraftsmanExhibitionDetailScreenState
    extends State<CraftsmanExhibitionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // State from registration
  String?
      _registrationStatus; // 'confirmed', 'standby', 'pending', 'invited', 'none'
  String? _assignedBoothId;
  double? _boothPrice;
  bool _hasPaid = false;
  bool _reportedAbsence = false;
  int? _standbyRank;

  List<Map<String, dynamic>> _participants = [];

  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0.85).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    _loadRegistrationData();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _progressController.forward();
    });
  }

  String? _rejectionReason;

  void _loadRegistrationData() {
    final reg = widget.registration;
    final ex = widget.exhibition;

    // If registration is passed, use it
    if (reg != null) {
      _registrationStatus = reg['status'] ?? 'none';
      _assignedBoothId = reg['boothId'];
      _boothPrice = (reg['boothPrice'] ?? 0).toDouble();
      _hasPaid = reg['hasPaid'] ?? false;
      _reportedAbsence = reg['reportedAbsence'] ?? false;
      _standbyRank = reg['standbyRank'];
      _rejectionReason = reg['rejectionReason'];
    } else {
      // Otherwise, check if invited or any other state from exhibition data
      _registrationStatus = ex['invited'] == true ? 'invited' : 'none';
      _assignedBoothId = null;
      _boothPrice = 0;
      _hasPaid = false;
      _reportedAbsence = false;
      _standbyRank = null;
      _rejectionReason = null;
    }

    // Parse participants from exhibition data
    final craftsmen = ex['ExhibitionCraftsmen'] as List?;
    if (craftsmen != null && craftsmen.isNotEmpty) {
      _participants = craftsmen.map<Map<String, dynamic>>((ec) {
        final craftsman = ec['Craftsman'] as Map<String, dynamic>? ?? {};
        return {
          'name': craftsman['name'] ?? 'حرفي',
          'craft': ec['craftCategory'] ?? 'حرفة',
          'status': ec['status'] ?? 'confirmed',
          'id': craftsman['id']?.toString() ?? '',
        };
      }).toList();
    } else {
      _participants = [];
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String getStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return t('مؤكد', 'Confirmed');
      case 'standby':
        return t('قائمة انتظار', 'Standby');
      case 'invited':
        return t('مدعو', 'Invited');
      case 'pending':
        return t('طلبك قيد الانتظار', 'Request Pending');
      case 'rejected':
        return t('لم تتم الموافقة', 'Not Approved');
      default:
        return t('غير مسجل', 'Not Registered');
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'standby':
        return Colors.amber;
      case 'invited':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'standby':
        return Icons.hourglass_empty;
      case 'invited':
        return Icons.mail_outline;
      case 'pending':
        return Icons.pending_actions;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.cancel_outlined;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final format = isArabic
          ? DateFormat('d MMM y', 'ar')
          : DateFormat('MMM d, y', 'en_US');
      return format.format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  void _showAbsenceDialog() {
    // (same as before, unchanged)
    String selectedReason = 'sick';
    bool isGeneratingMessage = false;
    String generatedMessage = '';
    final exName =
        isArabic ? widget.exhibition['name'] : widget.exhibition['nameEn'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    t('الإبلاغ عن غياب', 'Report Absence'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'تنبيه: الإبلاغ عن الغياب في وقت متأخر قد يؤثر سلباً على درجة التزامك. سيتم إرسال إشعار لإدارة المعرض لإيجاد بديل من قائمة الانتظار باستخدام الذكاء الاصطناعي.',
                        'Warning: Reporting absence late may negatively impact your commitment score. A notification will be sent to exhibition management to find a standby replacement using AI.',
                      ),
                      style: TextStyle(color: dim, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t('سبب الغياب', 'Reason for Absence'),
                      style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          dropdownColor: surface,
                          icon: Icon(Icons.keyboard_arrow_down, color: text),
                          items: [
                            DropdownMenuItem(
                              value: 'sick',
                              child: Text(t('مرض مفاجئ', 'Sudden illness'),
                                  style: TextStyle(color: text)),
                            ),
                            DropdownMenuItem(
                              value: 'emergency',
                              child: Text(t('طوارئ عائلية', 'Family emergency'),
                                  style: TextStyle(color: text)),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text(
                                  t('مشكلة في المواصلات',
                                      'Transportation issue'),
                                  style: TextStyle(color: text)),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(t('أسباب أخرى', 'Other reasons'),
                                  style: TextStyle(color: text)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedReason = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (generatedMessage.isEmpty && !isGeneratingMessage)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => isGeneratingMessage = true);
                            final reasonMap = {
                              'sick': isArabic ? 'مرض مفاجئ' : 'sudden illness',
                              'emergency': isArabic
                                  ? 'طوارئ عائلية'
                                  : 'family emergency',
                              'transport': isArabic
                                  ? 'مشكلة في المواصلات'
                                  : 'transportation issue',
                              'other': isArabic
                                  ? 'ظروف طارئة'
                                  : 'unforeseen circumstances',
                            };
                            final reasonText =
                                reasonMap[selectedReason] ?? selectedReason;
                            final aiMessage = await AiService.generateApology(
                              craftsmanName: isArabic ? 'الحرفي' : 'Craftsman',
                              exhibitionName: exName,
                              reason: reasonText,
                            );
                            setState(() {
                              generatedMessage = aiMessage ??
                                  (isArabic
                                      ? 'السادة إدارة معرض $exName\n\nأعتذر بصدق عن عدم تمكني من الحضور بسبب $reasonText.\n\nمع خالص التقدير.'
                                      : 'Dear $exName Management,\n\nPlease accept my sincere apologies for being unable to attend due to $reasonText.\n\nBest regards.');
                              isGeneratingMessage = false;
                            });
                          },
                          icon: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 18),
                          label: Text(
                            t('إنشاء رسالة اعتذار بالذكاء الاصطناعي',
                                'Generate AI Apology'),
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else if (isGeneratingMessage)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.purpleAccent),
                            const SizedBox(height: 12),
                            Text(
                              t('جاري صياغة الرسالة المهنية...',
                                  'Drafting professional message...'),
                              style: TextStyle(
                                  color: Colors.purpleAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  Colors.purpleAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    color: Colors.purpleAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  t('رسالة مقترحة من الذكاء الاصطناعي',
                                      'AI Suggested Message'),
                                  style: TextStyle(
                                    color: Colors.purpleAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              generatedMessage,
                              style: TextStyle(
                                  color: text, height: 1.5, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
                ),
                ElevatedButton(
                  onPressed: generatedMessage.isEmpty
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final success =
                              await ExhibitionsService.reportAbsence(
                            exhibitionId: widget.exhibition['id'],
                            registrationId: widget.registration?['id'] ?? '',
                            reason: selectedReason,
                            apologyText: generatedMessage,
                          );
                          nav.pop();
                          if (!mounted) return;
                          if (success) {
                            setState(() {
                              _reportedAbsence = true;
                              _registrationStatus = 'none';
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                content: Text(
                                  t('تم إرسال البلاغ إلى إدارة المعرض بنجاح',
                                      'Report sent to exhibition management successfully'),
                                  style: GoogleFonts.cairo(color: Colors.white),
                                ),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(t('فشل إرسال البلاغ',
                                    'Failed to send report')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor:
                        Colors.redAccent.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    t('تأكيد الغياب', 'Confirm Absence'),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleInviteResponse(bool accept) {
    if (accept) {
      setState(() {
        _registrationStatus = 'pending';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم قبول الدعوة', 'Invite accepted')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _registrationStatus = 'none';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم رفض الدعوة', 'Invite declined')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _contactOwner() {
    final owner = widget.exhibition['Owner'] as Map<String, dynamic>?;
    if (owner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لا تتوفر معلومات الاتصال بالمنظم',
              'Organizer contact info not available')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final name = owner['name'] ?? t('المنظم', 'Organizer');
    final email = owner['email'] ?? '';
    final phone = owner['phone'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.contact_page, color: accent),
              const SizedBox(width: 10),
              Text(
                t('معلومات المنظم', 'Organizer Contact'),
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.person, t('الاسم', 'Name'), name),
              if (email.isNotEmpty) _infoRow(Icons.email, 'Email', email),
              if (phone.isNotEmpty)
                _infoRow(Icons.phone, t('الهاتف', 'Phone'), phone),
            ],
          ),
          actions: [
            if (phone.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  // Launch phone dialer
                  // Uri(scheme: 'tel', path: phone);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('سيتم فتح تطبيق الاتصال للرقم: $phone',
                          'Opening dialer for $phone')),
                      backgroundColor: accent,
                    ),
                  );
                },
                icon: Icon(Icons.phone, color: Colors.green),
                label: Text(
                  t('اتصال', 'Call'),
                  style: TextStyle(color: Colors.green),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إغلاق', 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: dim, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showTicketDialog() {
    final reg = widget.registration;
    final ex = widget.exhibition;
    final boothId = reg?['boothId'] ?? _assignedBoothId ?? 'N/A';
    final status = _registrationStatus ?? 'none';
    final isConfirmed = status == 'confirmed';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.qr_code, color: accent),
              const SizedBox(width: 10),
              Text(
                t('بطاقة الدخول', 'Entry Ticket'),
                style: TextStyle(
                    color: text, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isConfirmed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t('هذه البطاقة مؤقتة لحين تأكيد المشاركة',
                              'This ticket is temporary until participation is confirmed'),
                          style: GoogleFonts.cairo(
                            color: Colors.amber.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    // QR Code
                    QrImageView(
                      data: jsonEncode({
                        'exhibition': ex['id'],
                        'craftsman': widget.craftsmanId,
                        'booth': boothId,
                        'status': status,
                        'timestamp': DateTime.now().toIso8601String(),
                      }),
                      version: QrVersions.auto,
                      size: 120,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFFD4A017),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFFD4A017),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ex['name']?.toString() ?? 'Craft Exhibition',
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(ex['startDate'])} - ${_formatDate(ex['endDate'])}',
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConfirmed
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isConfirmed
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isConfirmed
                                ? Icons.check_circle
                                : Icons.hourglass_empty,
                            color: isConfirmed ? Colors.green : Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConfirmed
                                ? t('مؤكد', 'Confirmed')
                                : t('قيد الموافقة', 'Pending'),
                            style: TextStyle(
                              color: isConfirmed ? Colors.green : Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: border),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('الكشك', 'Booth'),
                                style: TextStyle(color: dim, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              boothId,
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t('الحالة', 'Status'),
                                style: TextStyle(color: dim, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              isConfirmed
                                  ? t('نشط', 'Active')
                                  : t('معلق', 'Pending'),
                              style: TextStyle(
                                color:
                                    isConfirmed ? Colors.green : Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (reg != null)
                      Text(
                        t('رمز التسجيل: ${reg['id']?.toString().substring(0, 8) ?? 'N/A'}',
                            'Reg ID: ${reg['id']?.toString().substring(0, 8) ?? 'N/A'}'),
                        style: TextStyle(color: dim, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إغلاق', 'Close'), style: TextStyle(color: dim)),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _parseGradient(dynamic gradientData) {
    const defaultColors = [Colors.blue, Colors.green];
    if (gradientData == null) return defaultColors;
    if (gradientData is List<Color>) {
      return gradientData.isNotEmpty ? gradientData : defaultColors;
    }

    dynamic rawList = gradientData;
    if (gradientData is String) {
      final trimmed = gradientData.trim();
      if (trimmed.startsWith('[')) {
        try {
          rawList = jsonDecode(trimmed);
        } catch (_) {}
      } else if (trimmed.contains(',')) {
        rawList = trimmed.split(',');
      }
    }

    if (rawList is List && rawList.isNotEmpty) {
      try {
        final colors = rawList.map<Color>((c) {
          if (c is Color) return c;
          final hex = c
              .toString()
              .replaceAll('#', '')
              .replaceAll('"', '')
              .replaceAll('\\', '')
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
          return defaultColors.first;
        }).toList();
        if (colors.isNotEmpty) return colors;
      } catch (_) {}
    }
    return defaultColors;
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exhibition;
    final name = isArabic ? ex['name'] : ex['nameEn'];
    final location = isArabic ? ex['location'] : ex['locationEn'];
    final startDateFormatted = _formatDate(ex['startDate']);
    final endDateFormatted = _formatDate(ex['endDate']);
    final gradient = _parseGradient(ex['gradient']);
    final description = ex['description'] ??
        t(
          'معرض حرفي يضم أفضل الحرفيين المبدعين.',
          'A craft exhibition gathering the finest creative artisans.',
        );

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: surface,
              leading: IconButton(
                icon: Icon(
                  isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    name,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(blurRadius: 4, color: Colors.black54)
                      ],
                    ),
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        _registrationStatus != null
                            ? getStatusLabel(_registrationStatus!)
                            : t('غير مسجل', 'Not Registered'),
                        style: TextStyle(
                          color: getStatusColor(_registrationStatus ?? 'none'),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.people, size: 16, color: dim),
                      const SizedBox(width: 4),
                      Text(
                        '${_participants.length}',
                        style: TextStyle(color: dim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.cairo(
                                    color: text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: dim, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '$startDateFormatted - $endDateFormatted',
                                style: GoogleFonts.cairo(color: text),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: GoogleFonts.cairo(
                              color: dim,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Booth Information (only if confirmed and booth assigned)
                    if (_assignedBoothId != null &&
                        _registrationStatus == 'confirmed')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          gradient: LinearGradient(
                            colors: [accent.withValues(alpha: 0.05), surface],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront_outlined, color: accent),
                                const SizedBox(width: 8),
                                Text(
                                  t('كشكي', 'My Booth'),
                                  style: GoogleFonts.cairo(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('رقم الكشك', 'Booth Number'),
                                      style:
                                          TextStyle(color: dim, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _assignedBoothId!,
                                      style: GoogleFonts.cairo(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      t('السعر', 'Price'),
                                      style:
                                          TextStyle(color: dim, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_boothPrice?.toStringAsFixed(0) ?? '0'} JOD',
                                      style: GoogleFonts.cairo(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  _hasPaid
                                      ? Icons.payment
                                      : Icons.payment_outlined,
                                  color:
                                      _hasPaid ? Colors.green : Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _hasPaid
                                      ? t('مدفوع', 'Paid')
                                      : t('لم يدفع بعد', 'Not yet paid'),
                                  style: TextStyle(
                                    color:
                                        _hasPaid ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Participants
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('الحرفيون المشاركون', 'Participating Artisans'),
                          style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_participants.length}',
                          style: TextStyle(
                              color: accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_participants.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Center(
                          child: Text(
                            t('لا يوجد حرفيون مشاركون حالياً',
                                'No participating artisans yet'),
                            style: TextStyle(color: dim, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _participants.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final p = _participants[index];
                            return Column(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      accent.withValues(alpha: 0.2),
                                  child: Text(
                                    p['name'][0],
                                    style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p['name'],
                                  style: TextStyle(color: dim, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),

                    // AI Trust Score
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                            accent.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: AnimatedBuilder(
                                  animation: _progressAnimation,
                                  builder: (context, child) =>
                                      CircularProgressIndicator(
                                    value: _progressAnimation.value,
                                    strokeWidth: 8,
                                    backgroundColor: surface,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) => Text(
                                  '${(_progressAnimation.value * 100).toInt()}%',
                                  style: GoogleFonts.cairo(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('درجة الثقة في المعرض (AI)',
                                      'Exhibition Trust Score'),
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('الموقع محقق', 'Location Verified'),
                                      style:
                                          TextStyle(color: dim, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('التواريخ منطقية', 'Dates Valid'),
                                      style:
                                          TextStyle(color: dim, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Colors.amber, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('منظم جديد', 'New Organizer'),
                                      style:
                                          TextStyle(color: dim, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions based on status
                    if (_registrationStatus == 'invited') _buildInviteActions(),
                    if (_registrationStatus == 'confirmed' && !_reportedAbsence)
                      _buildConfirmedActions(),
                    if (_registrationStatus == 'standby') _buildStandbyInfo(),
                    if (_registrationStatus == 'none' &&
                        _registrationStatus != 'invited')
                      _buildNotRegisteredActions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    String status = _registrationStatus ?? 'none';
    Color color = getStatusColor(status);
    IconData icon = getStatusIcon(status);
    String label = getStatusLabel(status);

    String subtitle = '';
    if (status == 'confirmed') {
      subtitle = t(
        'تم تأكيد مشاركتك في المعرض. كشكك محجوز.',
        'Your participation is confirmed. Your booth is reserved.',
      );
    } else if (status == 'standby') {
      subtitle = t(
        'أنت في قائمة الانتظار برقم $_standbyRank',
        'You are on standby list at rank #$_standbyRank',
      );
    } else if (status == 'invited') {
      subtitle = t(
        'لقد تلقيت دعوة. يرجى القبول أو الرفض.',
        'You have received an invitation. Please accept or decline.',
      );
    } else if (status == 'pending') {
      subtitle = t(
        'طلب مشاركتك قيد مراجعة المنظم وسوف تتلقى إشعاراً عند القرار.',
        'Your participation request is under review by the organizer. You will be notified upon decision.',
      );
    } else if (status == 'rejected') {
      final reasonText = (_rejectionReason != null && _rejectionReason!.isNotEmpty)
          ? '\n${t('السبب: ', 'Reason: ')}$_rejectionReason'
          : '';
      subtitle = t(
        'للأسف لم تتم الموافقة على طلب مشاركتك في المعرض.$reasonText',
        'Regrettably, your request to join this exhibition was not approved.$reasonText',
      );
    } else {
      subtitle = t(
        'أنت غير مسجل لهذا المعرض.',
        'You are not registered for this exhibition.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: dim, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleInviteResponse(false),
                icon: Icon(Icons.close, color: Colors.red),
                label: Text(
                  t('رفض', 'Decline'),
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _handleInviteResponse(true),
                icon: const Icon(Icons.check, color: Colors.black),
                label: Text(
                  t('قبول الدعوة', 'Accept Invite'),
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _contactOwner,
          icon: Icon(Icons.chat_outlined, color: accent),
          label: Text(
            t('التواصل مع المنظم', 'Contact Organizer'),
            style: TextStyle(color: accent),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAbsenceDialog,
                icon: Icon(Icons.event_busy, color: Colors.redAccent),
                label: Text(
                  t('الإبلاغ عن غياب', 'Report Absence'),
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showTicketDialog,
                icon: Icon(Icons.qr_code, color: Colors.black),
                label: Text(
                  t('بطاقة الدخول', 'Entry Ticket'),
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _contactOwner,
          icon: Icon(Icons.chat_outlined, color: accent),
          label: Text(
            t('التواصل مع المنظم', 'Contact Organizer'),
            style: TextStyle(color: accent),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStandbyInfo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(
                    'أنت في قائمة الانتظار برقم $_standbyRank. إذا ألغى حرفي مؤكد مشاركته، سيتم ترقيتك تلقائياً بناءً على تقييم الذكاء الاصطناعي.',
                    'You are on the standby list at rank $_standbyRank. If a confirmed artisan cancels, you will be promoted automatically based on AI ranking.',
                  ),
                  style: TextStyle(color: dim, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _contactOwner,
          icon: Icon(Icons.chat_outlined, color: accent),
          label: Text(
            t('التواصل مع المنظم', 'Contact Organizer'),
            style: TextStyle(color: accent),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNotRegisteredActions() {
    final boothPrice = (widget.exhibition['boothPrice'] != null)
        ? double.tryParse(widget.exhibition['boothPrice'].toString()) ?? 0.0
        : 0.0;
    final isInvited = widget.exhibition['invited'] == true || _registrationStatus == 'invited';
    final isFreeRequest = boothPrice == 0 && !isInvited;
    final isFull = widget.exhibition['isFull'] == true;

    return Column(
      children: [
        if (isFull)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t(
                      'المعرض ممتلئ حالياً. يمكنك التقديم على قائمة الاحتياط لتأكيد انضمامك عند اعتذار أحد المشاركين.',
                      'Exhibition is currently fully booked. You can apply for a reserve slot to fill in if a spot opens up.',
                    ),
                    style: TextStyle(color: text, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExhibitionRegistrationScreen(
                    isArabic: isArabic,
                    isDarkMode: isDarkMode,
                    exhibition: widget.exhibition,
                    craftsmanId: widget.craftsmanId,
                    isInvited: isInvited,
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  _loadRegistrationData();
                  if (mounted) setState(() {});
                }
              });
            },
            icon: Icon(
              isFull
                  ? Icons.hourglass_top_rounded
                  : (isFreeRequest ? Icons.send_rounded : Icons.event_available),
              color: Colors.black,
            ),
            label: Text(
              isFull
                  ? t('الانضمام لقائمة الاحتياط', 'Apply for Reserve Slot')
                  : (isFreeRequest
                      ? t('تقديم طلب مشاركة', 'Submit Participation Request')
                      : t('سجل الآن', 'Register Now')),
              style:
                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFull ? Colors.amber : accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _contactOwner,
            icon: Icon(Icons.chat_outlined, color: accent),
            label: Text(
              t('التواصل مع المنظم', 'Contact Organizer'),
              style: TextStyle(color: accent),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
