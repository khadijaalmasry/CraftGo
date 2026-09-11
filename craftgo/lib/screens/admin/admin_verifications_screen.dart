import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminVerificationsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AdminVerificationsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  String t(String ar, String en) => widget.isArabic ? ar : en;

  Color get bgColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accentColor =>
      widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get textColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get subtitleColor =>
      widget.isDarkMode ? Colors.white70 : Colors.black54;

  List<Map<String, dynamic>> _pendingArtisans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('/admin/pending-artisans');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pendingArtisans = List<Map<String, dynamic>>.from(
            (data['data'] as List).map((e) => {
                  ...Map<String, dynamic>.from(e),
                  'expanded': false,
                  'loading': false,
                  'aiLoading': false,
                  'aiReport': null,
                  'aiError': null,
                }),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = t('فشل تحميل البيانات', 'Failed to load data');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = t('خطأ في الاتصال بالخادم', 'Connection error');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGroqAssessment(int index) async {
    final artisan = _pendingArtisans[index];

    setState(() {
      _pendingArtisans[index]['aiLoading'] = true;
      _pendingArtisans[index]['aiError'] = null;
    });

    try {
      final response = await ApiService.post(
        '/ai/artisan-account-assessment',
        body: {
          'name': artisan['name'] ?? '',
          'email': artisan['email'] ?? '',
          'phone': artisan['phone'] ?? '',
          'city': artisan['city'] ?? '',
          'category': artisan['category'] ?? artisan['primaryCategory'] ?? '',
          'bio': artisan['bio'] ?? '',
          'experienceYears': artisan['experienceYears'] ?? 0,
          'priceRange': artisan['priceRange'] ?? '',
          'specializations': artisan['specializations'] ?? const [],
          'trustedHands': artisan['trustedHands'] == true,
          'portfolioImages': _portfolioUrls(artisan),
          'idFrontUrl': _normalizeUrl(artisan['idFrontUrl']),
          'idBackUrl': _normalizeUrl(artisan['idBackUrl']),
          'language': widget.isArabic ? 'ar' : 'en',
        },
      );

      Map<String, dynamic> body = {};
      try {
        if (response.body.isNotEmpty) {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('JSON decode error for AI assessment: $e');
        body = {
          'error': response.statusCode != 200
              ? 'Server Error (code: ${response.statusCode})'
              : 'Invalid response format from AI API'
        };
      }

      if (!mounted) return;

      if (response.statusCode == 200 &&
          (body['success'] == true || body['score'] != null)) {
        setState(() {
          _pendingArtisans[index]['aiReport'] = body;
          _pendingArtisans[index]['aiLoading'] = false;
        });
      } else {
        setState(() {
          _pendingArtisans[index]['aiLoading'] = false;
          _pendingArtisans[index]['aiError'] = (body['error'] ??
                  t(
                    'تعذر الحصول على تقييم Groq.',
                    'Could not get the Groq assessment.',
                  ))
              .toString();
        });
      }
    } catch (error) {
      debugPrint('Groq artisan assessment error: $error');
      if (!mounted) return;
      setState(() {
        _pendingArtisans[index]['aiLoading'] = false;
        _pendingArtisans[index]['aiError'] = t(
          'تعذر الاتصال بخدمة الذكاء الاصطناعي.',
          'Could not connect to the AI service.',
        );
      });
    }
  }

  Future<void> _review(int index, String action) async {
    final artisan = _pendingArtisans[index];
    final profileId = artisan['artisanProfileId'];

    setState(() => _pendingArtisans[index]['loading'] = true);

    try {
      final response = await ApiService.patch(
        '/admin/artisans/$profileId/review',
        body: {'action': action},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _pendingArtisans.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve'
              ? t('تم قبول الحرفي بنجاح ✓', 'Artisan approved successfully ✓')
              : t('تم رفض الطلب', 'Request rejected')),
          backgroundColor:
              action == 'approve' ? accentColor : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        setState(() => _pendingArtisans[index]['loading'] = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('حدث خطأ، حاول مجدداً', 'Error occurred, try again')),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingArtisans[index]['loading'] = false);
      }
    }
  }

  String _normalizeUrl(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';

    // Always use the same backend origin that ApiService is currently using.
    // This is important for repaired/old DB rows that may contain a hard-coded
    // localhost/127.0.0.1/10.0.2.2 URL with a different port.
    final apiUri = Uri.parse(ApiService.baseUrl);
    final apiOrigin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString().replaceFirst(RegExp(r'/$'), '');

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final parsed = Uri.tryParse(raw);
      if (parsed == null) return raw;

      final isLocalHost = parsed.host == 'localhost' ||
          parsed.host == '127.0.0.1' ||
          parsed.host == '10.0.2.2';

      if (isLocalHost) {
        final suffix =
            parsed.hasQuery ? '${parsed.path}?${parsed.query}' : parsed.path;
        return '$apiOrigin$suffix';
      }

      return raw;
    }

    if (raw.startsWith('/')) {
      return '$apiOrigin$raw';
    }

    return '$apiOrigin/$raw';
  }

  List<String> _portfolioUrls(Map<String, dynamic> artisan) {
    final value = artisan['portfolioImages'];
    if (value is List) {
      return value.map(_normalizeUrl).where((url) => url.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map(_normalizeUrl)
              .where((url) => url.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return [_normalizeUrl(value)].where((url) => url.isNotEmpty).toList();
      }
    }
    return <String>[];
  }

  void _openImageViewer({required String imageUrl, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 72,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aiReportSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(emptyText, style: TextStyle(color: subtitleColor, fontSize: 13))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, color: color, size: 7),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showGroqReport(Map<String, dynamic> report) {
    final score = int.tryParse(report['score'].toString()) ?? 0;
    final confidence = int.tryParse(report['confidence'].toString()) ?? 0;
    final strengths = report['strengths'] is List
        ? List<String>.from(
            (report['strengths'] as List).map((e) => e.toString()),
          )
        : <String>[];
    final warnings = report['warnings'] is List
        ? List<String>.from(
            (report['warnings'] as List).map((e) => e.toString()),
          )
        : <String>[];
    final imageAssessment = report['imageAssessment'] is Map
        ? Map<String, dynamic>.from(report['imageAssessment'] as Map)
        : <String, dynamic>{};

    final color = score >= 85
        ? Colors.green
        : score >= 70
            ? Colors.lightGreen
            : score >= 50
                ? Colors.orange
                : Colors.redAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: subtitleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      t('تقرير Groq الكامل', 'Full Groq Assessment'),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$score%',
                      style: TextStyle(
                        color: color,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      (report['label'] ?? '').toString(),
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (report['recommendation'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t('ثقة التحليل:', 'Confidence:')} $confidence%',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if ((report['profileAnalysis'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  t('تحليل الملف', 'Profile Analysis'),
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  report['profileAnalysis'].toString(),
                  style: TextStyle(color: subtitleColor, height: 1.5),
                ),
              ],
              const SizedBox(height: 20),
              _aiReportSection(
                title: t('نقاط القوة', 'Strengths'),
                icon: Icons.check_circle_outline,
                color: Colors.green,
                items: strengths,
                emptyText: t(
                  'لم يحدد Groq نقاط قوة إضافية.',
                  'Groq did not identify additional strengths.',
                ),
              ),
              const SizedBox(height: 18),
              _aiReportSection(
                title: t('التنبيهات', 'Warnings'),
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
                items: warnings,
                emptyText: t(
                  'لم يحدد Groq تنبيهات.',
                  'Groq did not identify warnings.',
                ),
              ),
              const SizedBox(height: 18),
              if (imageAssessment.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('تقييم الصور', 'Image Assessment'),
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (imageAssessment['note'] ?? '').toString(),
                        style: TextStyle(
                            color: subtitleColor, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        color: bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('طلبات التوثيق', 'Verification Requests'),
                    style: GoogleFonts.arefRuqaa(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: _fetchPending,
                      icon: Icon(Icons.refresh_rounded, color: accentColor),
                      tooltip: t('تحديث', 'Refresh'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoading && _error == null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _pendingArtisans.isEmpty
                        ? Colors.green.withValues(alpha: 0.15)
                        : accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pendingArtisans.isEmpty
                        ? t('لا توجد طلبات معلقة ✓', 'No pending requests ✓')
                        : t('${_pendingArtisans.length} طلب معلق',
                            '${_pendingArtisans.length} pending'),
                    style: TextStyle(
                      color:
                          _pendingArtisans.isEmpty ? Colors.green : accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : _error != null
                      ? _buildError()
                      : _pendingArtisans.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchPending,
                              color: accentColor,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 8.0),
                                itemCount: _pendingArtisans.length,
                                itemBuilder: (context, index) =>
                                    _buildCard(index),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: subtitleColor, size: 60),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: subtitleColor, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchPending,
            icon: const Icon(Icons.refresh),
            label: Text(t('إعادة المحاولة', 'Retry')),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 70, color: Colors.green),
          ),
          const SizedBox(height: 20),
          Text(
            t('لا توجد طلبات معلقة', 'No Pending Requests'),
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('جميع طلبات الحرفيين تمت مراجعتها',
                'All artisan requests have been reviewed'),
            style: TextStyle(color: subtitleColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<String> _specializations(Map<String, dynamic> artisan) {
    final value = artisan['specializations'];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    return <String>[];
  }

  Widget _buildCard(int index) {
    final artisan = _pendingArtisans[index];
    final bool isExpanded = artisan['expanded'] == true;
    final bool isLoading = artisan['loading'] == true;
    final bool trustedHands = artisan['trustedHands'] == true;
    final String priceRange = (artisan['priceRange'] ?? '').toString().trim();
    final List<String> materials = _specializations(artisan);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _pendingArtisans[index]['expanded'] = !isExpanded;
              });
              if (!isExpanded &&
                  _pendingArtisans[index]['aiReport'] == null &&
                  _pendingArtisans[index]['aiLoading'] != true) {
                _fetchGroqAssessment(index);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline,
                            color: accentColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artisan['name'] ?? '—',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${artisan['category'] ?? '—'} • ${artisan['city'] ?? '—'}',
                              style:
                                  TextStyle(fontSize: 13, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: subtitleColor,
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 20),
                    Divider(color: textColor.withValues(alpha: 0.08)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.email_outlined, artisan['email'] ?? '—'),
                        _chip(Icons.phone_outlined, artisan['phone'] ?? '—'),
                        _chip(
                          Icons.workspace_premium_outlined,
                          '${artisan['experienceYears'] ?? 0} ${t('سنة', 'yrs')}',
                        ),
                        _chip(
                          trustedHands
                              ? Icons.verified_user_outlined
                              : Icons.person_outline,
                          trustedHands
                              ? t('الأيدي الموثوقة', 'Trusted Hands')
                              : t('حساب قياسي', 'Standard'),
                        ),
                        if (priceRange.isNotEmpty)
                          _chip(
                            Icons.payments_outlined,
                            '${t('نطاق السعر', 'Price Range')}: $priceRange JOD',
                          ),
                      ],
                    ),
                    if (materials.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        t('المواد / التخصصات:', 'Materials / Specializations:'),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: materials
                            .map(
                              (item) => _chip(
                                Icons.category_outlined,
                                item,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if ((artisan['bio'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        t('نبذة:', 'Bio:'),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artisan['bio'],
                        style: TextStyle(
                            color: subtitleColor, fontSize: 13, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      t('المستندات المرفقة', 'Attached Documents'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (trustedHands)
                      Row(
                        children: [
                          _buildDocumentCard(
                            icon: Icons.badge_outlined,
                            label: t('الهوية الأمامية', 'ID Front'),
                            url: _normalizeUrl(artisan['idFrontUrl']),
                          ),
                          const SizedBox(width: 12),
                          _buildDocumentCard(
                            icon: Icons.badge_outlined,
                            label: t('الهوية الخلفية', 'ID Back'),
                            url: _normalizeUrl(artisan['idBackUrl']),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: accentColor,
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                t(
                                  'حساب قياسي — الهوية الوطنية غير مطلوبة.',
                                  'Standard account — National ID is not required.',
                                ),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      t('نماذج الأعمال', 'Portfolio Samples'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPortfolioSection(artisan),
                    const SizedBox(height: 18),
                    _buildGroqAiSummaryCard(index, artisan),
                    const SizedBox(height: 20),
                    isLoading
                        ? Center(
                            child:
                                CircularProgressIndicator(color: accentColor))
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _review(index, 'reject'),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: Text(t('رفض', 'Reject')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor,
                                        widget.isDarkMode
                                            ? const Color(0xFFE8B632)
                                            : const Color(0xFF1E3A6D),
                                      ],
                                    ),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _review(index, 'approve'),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: Text(t('قبول', 'Approve')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: widget.isDarkMode
                                          ? Colors.black87
                                          : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      shadowColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String label,
    required String url,
  }) {
    final hasImage = url.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: hasImage
            ? () => _openImageViewer(imageUrl: url, title: label)
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasImage
                  ? accentColor.withValues(alpha: 0.45)
                  : textColor.withValues(alpha: 0.08),
            ),
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _docPlaceholderContent(icon, label, false),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ],
                )
              : _docPlaceholderContent(icon, label, false),
        ),
      ),
    );
  }

  Widget _buildPortfolioSection(Map<String, dynamic> artisan) {
    final images = _portfolioUrls(artisan);

    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: textColor.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined, color: subtitleColor, size: 36),
            const SizedBox(height: 8),
            Text(
              t('لم يتم رفع صور أعمال', 'No portfolio images uploaded'),
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final url = images[index];
        return InkWell(
          onTap: () => _openImageViewer(
            imageUrl: url,
            title: '${t('نموذج عمل', 'Portfolio Sample')} ${index + 1}',
          ),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: bgColor,
                    child:
                        Icon(Icons.broken_image_outlined, color: subtitleColor),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.zoom_in,
                        color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroqAiSummaryCard(int index, Map<String, dynamic> artisan) {
    final isLoading = artisan['aiLoading'] == true;
    final error = artisan['aiError']?.toString();
    final reportValue = artisan['aiReport'];
    final report =
        reportValue is Map ? Map<String, dynamic>.from(reportValue) : null;

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.purpleAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('Groq يحلل بيانات الحساب...',
                    'Groq is assessing the account...'),
                style: const TextStyle(
                    color: Colors.purpleAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null && error.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _fetchGroqAssessment(index),
              icon: const Icon(Icons.refresh),
              label: Text(t('إعادة التحليل', 'Analyze Again')),
            ),
          ],
        ),
      );
    }

    if (report == null) {
      return OutlinedButton.icon(
        onPressed: () => _fetchGroqAssessment(index),
        icon: const Icon(Icons.auto_awesome),
        label: Text(t('تحليل الحساب عبر Groq', 'Analyze with Groq')),
      );
    }

    final score = int.tryParse(report['score'].toString()) ?? 0;
    final confidence = int.tryParse(report['confidence'].toString()) ?? 0;
    final color = score >= 85
        ? Colors.green
        : score >= 70
            ? Colors.lightGreen
            : score >= 50
                ? Colors.orange
                : Colors.redAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Colors.purpleAccent, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('تقييم Groq للحساب', 'Groq Account Assessment'),
                  style: GoogleFonts.cairo(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: subtitleColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  (report['recommendation'] ?? '').toString(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showGroqReport(report),
                child: Text(t('عرض التقرير', 'View Report')),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${t('ثقة التحليل:', 'Analysis confidence:')} $confidence%',
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docPlaceholderContent(IconData icon, String label, bool uploaded) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32, color: subtitleColor),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: subtitleColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          uploaded ? t('تم الرفع', 'Uploaded') : t('غير مرفوع', 'Not uploaded'),
          style: TextStyle(
            fontSize: 10,
            color: uploaded ? Colors.green : Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
