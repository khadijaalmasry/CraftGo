// lib/features/artisan/screens/craftsman_exhibitions_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/exhibitions_service.dart';
import 'craftsman_exhibition_detail_screen.dart';

class CraftsmanExhibitionsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String craftsmanId;

  const CraftsmanExhibitionsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.craftsmanId,
  });

  @override
  State<CraftsmanExhibitionsScreen> createState() =>
      _CraftsmanExhibitionsScreenState();
}

class _CraftsmanExhibitionsScreenState
    extends State<CraftsmanExhibitionsScreen> {
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

  String t(String ar, String en) => widget.isArabic ? ar : en;

  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    setState(() => _isLoading = true);
    final regs =
        await ExhibitionsService.getCraftsmanRegistrations(widget.craftsmanId);
    setState(() {
      _registrations =
          regs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _isLoading = false;
    });
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
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('معارضي', 'My Exhibitions'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1100 : double.infinity,
                ),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _registrations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, color: dim, size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  t('لا توجد معارض مسجلة',
                                      'No registered exhibitions'),
                                  style: GoogleFonts.cairo(
                                      color: dim,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t('استكشف المعارض وسجل في المناسب منها',
                                      'Explore exhibitions and register for the ones that suit you'),
                                  style: TextStyle(color: dim, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _registrations.length,
                            itemBuilder: (context, index) {
                              final reg = _registrations[index];
                              final ex =
                                  reg['Exhibition'] as Map<String, dynamic>;
                              final status = reg['status'];
                              final isConfirmed = status == 'confirmed';
                              final isStandby = status == 'standby';
                              final isPending =
                                  status == 'pending' || status == 'invited';
                              final standbyRank = reg['standbyRank'];
                              final boothId = reg['boothId'];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CraftsmanExhibitionDetailScreen(
                                        exhibition: ex,
                                        craftsmanId: widget.craftsmanId,
                                        isArabic: widget.isArabic,
                                        isDarkMode: widget.isDarkMode,
                                        registration: reg,
                                      ),
                                    ),
                                  ).then((_) => _loadRegistrations());
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isConfirmed
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : isStandby
                                              ? Colors.amber
                                                  .withValues(alpha: 0.3)
                                              : Colors.blue
                                                  .withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Header with status
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isConfirmed
                                              ? Colors.green
                                                  .withValues(alpha: 0.08)
                                              : isStandby
                                                  ? Colors.amber
                                                      .withValues(alpha: 0.08)
                                                  : Colors.blue
                                                      .withValues(alpha: 0.08),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(20)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isConfirmed
                                                    ? Colors.green
                                                    : isStandby
                                                        ? Colors.amber
                                                        : Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isConfirmed
                                                    ? Icons.check_circle
                                                    : isStandby
                                                        ? Icons.hourglass_empty
                                                        : Icons.pending,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isConfirmed
                                                        ? t('✅ مؤكد',
                                                            '✅ Confirmed')
                                                        : isStandby
                                                            ? t('⏳ قائمة انتظار',
                                                                '⏳ On Standby')
                                                            : t('⏳ قيد الموافقة',
                                                                '⏳ Pending'),
                                                    style: GoogleFonts.cairo(
                                                      color: isConfirmed
                                                          ? Colors.green
                                                          : isStandby
                                                              ? Colors.amber
                                                                  .shade700
                                                              : Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (isStandby &&
                                                      standbyRank != null)
                                                    Text(
                                                      t('الترتيب: #$standbyRank',
                                                          'Rank: #$standbyRank'),
                                                      style: GoogleFonts.cairo(
                                                        color: dim,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  if (isConfirmed &&
                                                      boothId != null)
                                                    Text(
                                                      t('الكشك: $boothId',
                                                          'Booth: $boothId'),
                                                      style: GoogleFonts.cairo(
                                                        color: Colors.green,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // "Registered" badge with check
                                            if (isConfirmed)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.check,
                                                        color: Colors.white,
                                                        size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      t('مسجل', 'Registered'),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Exhibition info
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.event,
                                                    color: accent, size: 24),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    ex['name']?.toString() ??
                                                        '',
                                                    style: GoogleFonts.cairo(
                                                      color: text,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    color: dim, size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${_formatDate(ex['startDate'])} - ${_formatDate(ex['endDate'])}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.cairo(
                                                        color: dim,
                                                        fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on,
                                                    color: dim, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  widget.isArabic
                                                      ? ex['location']
                                                      : ex['locationEn'],
                                                  style: GoogleFonts.cairo(
                                                      color: dim, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // Quick actions
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _showTicketDialog(
                                                            context, ex, reg),
                                                    icon: const Icon(
                                                        Icons.qr_code,
                                                        size: 16),
                                                    label: Text(
                                                      t('بطاقة الدخول',
                                                          'Entry Ticket'),
                                                      style: GoogleFonts.cairo(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      side: BorderSide(
                                                          color:
                                                              accent.withValues(
                                                                  alpha: 0.5)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              CraftsmanExhibitionDetailScreen(
                                                            exhibition: ex,
                                                            craftsmanId: widget
                                                                .craftsmanId,
                                                            isArabic:
                                                                widget.isArabic,
                                                            isDarkMode: widget
                                                                .isDarkMode,
                                                            registration: reg,
                                                          ),
                                                        ),
                                                      ).then((_) =>
                                                          _loadRegistrations());
                                                    },
                                                    icon: const Icon(
                                                        Icons.info_outline,
                                                        color: Colors.black,
                                                        size: 16),
                                                    label: Text(
                                                      t('تفاصيل', 'Details'),
                                                      style: GoogleFonts.cairo(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: accent,
                                                      foregroundColor:
                                                          Colors.black,
                                                      elevation: 0,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Detailed Ticket Dialog ──────────────────────────────────────────────
  void _showTicketDialog(
      BuildContext context, Map<String, dynamic> ex, Map<String, dynamic> reg) {
    final boothId = reg['boothId'] ?? '—';
    final status = reg['status'] ?? 'confirmed';
    final isConfirmed = status == 'confirmed';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.qr_code, color: accent),
              const SizedBox(width: 10),
              Text(
                t('بطاقة الدخول', 'Entry Ticket'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                  ),
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
                      style: GoogleFonts.cairo(color: dim, fontSize: 13),
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
                            Text(
                              t('الكشك', 'Booth'),
                              style: TextStyle(color: dim, fontSize: 11),
                            ),
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
                            Text(
                              t('الحالة', 'Status'),
                              style: TextStyle(color: dim, fontSize: 11),
                            ),
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
              child: Text(
                t('إغلاق', 'Close'),
                style: TextStyle(color: dim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      final format = widget.isArabic
          ? DateFormat('d MMM y', 'ar')
          : DateFormat('MMM d, y', 'en_US');
      return format.format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }
}
