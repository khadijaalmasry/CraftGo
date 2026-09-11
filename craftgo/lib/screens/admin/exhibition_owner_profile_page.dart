import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/exhibitions_service.dart';

class ExhibitionOwnerProfilePage extends StatefulWidget {
  final Map<String, dynamic> owner;
  final bool isArabic;
  final bool isDarkMode;

  const ExhibitionOwnerProfilePage({
    super.key,
    required this.owner,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<ExhibitionOwnerProfilePage> createState() => _ExhibitionOwnerProfilePageState();
}

class _ExhibitionOwnerProfilePageState extends State<ExhibitionOwnerProfilePage> {
  List<dynamic> _exhibitions = [];
  bool _isLoading = true;

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadOwnerExhibitions();
  }

  Future<void> _loadOwnerExhibitions() async {
    final ownerId = widget.owner['id']?.toString() ?? '';
    if (ownerId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final list = await ExhibitionsService.getOwnerExhibitions(ownerId);
      if (mounted) {
        setState(() {
          _exhibitions = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.owner['name']?.toString() ?? t('منظم المعارض', 'Exhibition Organizer');
    final email = widget.owner['email']?.toString() ?? '—';
    final phone = widget.owner['phone']?.toString() ?? '—';
    final city = widget.owner['city']?.toString() ?? '—';

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: accent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('ملف منظم المعارض', 'Exhibition Organizer Profile'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.purple.withValues(alpha: 0.15),
                          child: const Icon(Icons.event_seat_rounded, color: Colors.purple, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t('منظم معارض معتمد', 'Verified Organizer'),
                                  style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    _infoRow(Icons.email_outlined, t('البريد الإلكتروني:', 'Email:'), email),
                    const SizedBox(height: 6),
                    _infoRow(Icons.phone_outlined, t('رقم الهاتف:', 'Phone:'), phone),
                    const SizedBox(height: 6),
                    _infoRow(Icons.location_city_outlined, t('المدينة:', 'City:'), city),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Organized Exhibitions section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('المعارض المنظمة', 'Organized Exhibitions'),
                    style: GoogleFonts.cairo(color: text, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_exhibitions.length} ${t('معرض', 'Exhibitions')}',
                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: accent)))
                  : _exhibitions.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_outlined, size: 40, color: dim),
                              const SizedBox(height: 8),
                              Text(
                                t('لم يقم المنظم بإنشاء أي معارض بعد', 'No organized exhibitions yet.'),
                                style: TextStyle(color: dim, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _exhibitions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final ex = Map<String, dynamic>.from(_exhibitions[idx] as Map);
                            final exTitle = widget.isArabic
                                ? (ex['name'] ?? ex['title'] ?? '—')
                                : (ex['nameEn'] ?? ex['name'] ?? '—');
                            final status = ex['status']?.toString() ?? 'upcoming';
                            final location = ex['location']?.toString() ?? ex['city']?.toString() ?? '—';
                            final capacity = ex['capacity'] ?? 0;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.museum_outlined, color: accent, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(exTitle, style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text('${t('الموقع:', 'Location:')} $location', style: TextStyle(color: dim, fontSize: 11)),
                                        Text('${t('السعة التخزينية:', 'Capacity:')} $capacity ${t('جناح', 'Booths')}', style: TextStyle(color: dim, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  _statusBadge(status),
                                ],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Expanded(child: Text(val, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color stColor = Colors.orange;
    String label = t('قادم', 'Upcoming');

    if (status == 'completed' || status == 'ended') {
      stColor = Colors.grey;
      label = t('منتهي', 'Completed');
    } else if (status == 'active' || status == 'ongoing') {
      stColor = Colors.green;
      label = t('جاري حالياً', 'Ongoing');
    } else if (status == 'cancelled') {
      stColor = Colors.red;
      label = t('ملغي', 'Cancelled');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: stColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
