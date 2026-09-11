import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/ai_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/exhibitions_service.dart';
import 'craftsman_public_profile_screen.dart';
import 'exhibition_add_screen.dart';

class ExhibitionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exhibition;
  final bool isAdminView;

  const ExhibitionDetailScreen({
    super.key,
    required this.exhibition,
    this.isAdminView = false,
  });

  @override
  State<ExhibitionDetailScreen> createState() => _ExhibitionDetailScreenState();
}

class _ExhibitionDetailScreenState extends State<ExhibitionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  Map<String, dynamic>? _exhibitionData;
  Map<String, dynamic>? _predictionData;
  Map<String, dynamic>? _trustScoreData;
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoadingDetails = true;
  bool _isUploadingBanner = false;
  String _error = '';

  // Theme helpers
  Color get bg => context.watch<AppState>().isDarkMode
      ? const Color(0xFF0D1420)
      : const Color(0xFFF5F6F8);
  Color get surface => context.watch<AppState>().isDarkMode
      ? const Color(0xFF1C2431)
      : Colors.white;
  Color get text =>
      context.watch<AppState>().isDarkMode ? Colors.white : Colors.black87;
  Color get dim =>
      context.watch<AppState>().isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => context.watch<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);
  Color get accentDark => const Color(0xFFB8860B);
  Color get primaryDark => const Color(0xFF0D1B33);

  String t(String ar, String en) => context.read<AppState>().isArabic ? ar : en;

  // ── Gradient parser ────────────────────────────────────
  List<Color> _parseGradient(dynamic gradientData) {
    const defaultPastelGradient = [Color(0xFFFBC2EB), Color(0xFFA6C1EE)];
    if (gradientData is List && gradientData.isNotEmpty) {
      try {
        return gradientData.map<Color>((c) {
          final hex = c.toString().replaceAll('#', '');
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
          return defaultPastelGradient.first;
        }).toList();
      } catch (_) {
        return defaultPastelGradient;
      }
    }
    return defaultPastelGradient;
  }

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

    _exhibitionData = Map<String, dynamic>.from(widget.exhibition);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final exhibId = widget.exhibition['id']?.toString();
    if (exhibId == null || exhibId.isEmpty) {
      setState(() {
        _isLoadingDetails = false;
        _error = 'No exhibition ID provided';
      });
      return;
    }

    setState(() => _isLoadingDetails = true);
    try {
      final res = await ExhibitionsService.getExhibitionById(exhibId);
      if (!mounted) return;
      final prediction = await AiService.predictExhibition(exhibId);
      if (!mounted) return;
      final trustData = await AiService.analyzeTrustScore(exhibId);
      if (!mounted) return;

      if (res != null) {
        final targetScore =
            (trustData?['scorePercentage'] as num?)?.toDouble() ?? 0.85;
        setState(() {
          _exhibitionData = Map<String, dynamic>.from(res);
          _predictionData = prediction;
          _trustScoreData = trustData;
          _isLoadingDetails = false;
          _error = '';
        });

        _progressAnimation = Tween<double>(begin: 0, end: targetScore).animate(
          CurvedAnimation(
              parent: _progressController, curve: Curves.easeOutCubic),
        );
        _progressController.forward(from: 0);

        final craftsmen = (res['ExhibitionCraftsmen'] as List?) ?? [];
        final List<Map<String, dynamic>> pending = [];
        for (final ec in craftsmen) {
          final status = (ec['status'] ?? '').toString();
          if (status == 'pending') {
            final craftsman = ec['Craftsman'] as Map<String, dynamic>? ?? {};
            pending.add({
              'id': ec['id']?.toString() ?? '',
              'exhibitionId': exhibId,
              'craftsmanId': craftsman['id']?.toString() ?? '',
              'name': craftsman['name'] ?? 'حرفي',
              'nameEn': craftsman['name'] ?? 'Craftsman',
              'craft': ec['craftCategory'] ?? 'حرفة',
              'craftEn': ec['craftCategory'] ?? 'Craft',
              'boothId': ec['boothId'] ?? '',
              'status': status,
              'city': craftsman['city'] ?? 'عمان',
              'cityEn': craftsman['city'] ?? 'Amman',
              'rating': 4.8,
              'completedOrders': 20,
              'available': true,
              'time': 'منذ قليل',
              'timeEn': 'Recently',
            });
          }
        }
        if (mounted) setState(() => _pendingRequests = pending);
      } else {
        setState(() {
          _isLoadingDetails = false;
          _error = 'Failed to load exhibition details';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _error = e.toString();
        });
      }
    }
  }

  // ── Pick and Upload Banner ────────────────────────────────
  Future<void> _pickAndUploadBanner() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() => _isUploadingBanner = true);
    try {
      final imageUrl = await CloudinaryService.uploadImage(pickedFile);
      if (imageUrl != null && mounted) {
        final exhibId = _exhibitionData?['id']?.toString();
        if (exhibId != null) {
          await ExhibitionsService.updateExhibition(exhibId, {
            'bannerUrl': imageUrl,
            'imageUrl': imageUrl,
          });
        }
        if (mounted) {
          setState(() {
            _exhibitionData?['bannerUrl'] = imageUrl;
            _exhibitionData?['imageUrl'] = imageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('تم تحديث غلاف المعرض بنجاح!',
                  'Banner updated successfully!')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(t('فشل رفع صورة الغلاف', 'Failed to upload banner image')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ─── Accept / Decline dialogs ──────────────────────────────────
  void _showAcceptConfirmationDialog(Map<String, dynamic> req) {
    final isArabic = context.read<AppState>().isArabic;
    final name = isArabic ? req['name'] : req['nameEn'];
    final craft = isArabic ? req['craft'] : req['craftEn'];
    final boothId = req['boothId'];
    final exhibitionName = isArabic
        ? (_exhibitionData?['name'] ?? '')
        : (_exhibitionData?['nameEn'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: accent, size: 28),
            const SizedBox(width: 10),
            Text(
              t('تأكيد القبول', 'Confirm Acceptance'),
              style: GoogleFonts.cairo(
                  color: text, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                      icon: Icons.person_outline,
                      label: t('الحرفي', 'Artisan'),
                      value: name),
                  const SizedBox(height: 8),
                  _infoRow(
                      icon: Icons.handyman_outlined,
                      label: t('التخصص', 'Craft'),
                      value: craft),
                  const SizedBox(height: 8),
                  _infoRow(
                      icon: Icons.event_outlined,
                      label: t('المعرض', 'Exhibition'),
                      value: exhibitionName),
                  const SizedBox(height: 8),
                  _infoRow(
                      icon: Icons.storefront_outlined,
                      label: t('الكشك', 'Booth'),
                      value: boothId),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(
                        'سيتم تأكيد مشاركة هذا الحرفي في المعرض وسيتم إشعاره بذلك.',
                        'This artisan will be confirmed for the exhibition and will receive a notification.',
                      ),
                      style: GoogleFonts.cairo(
                          color: Colors.amber.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final regId = req['id']?.toString() ?? '';
              final exhibId = req['exhibitionId']?.toString() ?? '';
              final isStandby = req['status'] == 'standby';
              final targetStatus = isStandby ? 'standby' : 'confirmed';
              if (regId.isNotEmpty && exhibId.isNotEmpty) {
                await ExhibitionsService.updateRegistrationStatus(
                    exhibId, regId, targetStatus);
              }
              if (mounted) {
                setState(() => _pendingRequests.remove(req));
                _loadDetails();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isStandby
                          ? t('تم إضافة ${isArabic ? req['name'] : req['nameEn']} لقائمة الاحتياط!',
                              '${isArabic ? req['name'] : req['nameEn']} added to standby list!')
                          : t(
                              'تم قبول ${isArabic ? req['name'] : req['nameEn']} في المعرض!',
                              '${isArabic ? req['name'] : req['nameEn']} accepted to the exhibition!',
                            ),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(t('تأكيد القبول', 'Confirm Accept'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  final List<String> _declineReasons = [
    'المعرض ممتلئ',
    'التخصص غير مناسب',
    'عدد الحرفيين كافٍ',
    'لم يتم استيفاء متطلبات المشاركة',
    'أسباب أخرى',
  ];
  String? _selectedDeclineReason;

  void _showDeclineDialog(Map<String, dynamic> req) {
    final isArabic = context.read<AppState>().isArabic;
    _selectedDeclineReason = null;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            t('سبب الرفض', 'Decline Reason'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? req['name'] : req['nameEn'],
                style: GoogleFonts.cairo(
                    color: accent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                t('اختر سبب الرفض (اختياري):',
                    'Select a decline reason (optional):'),
                style: GoogleFonts.cairo(color: dim, fontSize: 13),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selectedDeclineReason,
                onChanged: (value) =>
                    setDialogState(() => _selectedDeclineReason = value),
                child: Column(
                  children: _declineReasons
                      .map((reason) => RadioListTile<String>(
                            title: Text(
                              isArabic ? reason : _getReasonEn(reason),
                              style: GoogleFonts.cairo(color: text),
                            ),
                            value: reason,
                            activeColor: accent,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 2,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  hintText: t('سبب مخصص (اختياري)', 'Custom reason (optional)'),
                  hintStyle: TextStyle(color: dim),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final regId = req['id']?.toString() ?? '';
                final exhibId = req['exhibitionId']?.toString() ?? '';
                if (regId.isNotEmpty && exhibId.isNotEmpty) {
                  await ExhibitionsService.updateRegistrationStatus(
                      exhibId, regId, 'rejected');
                }
                if (mounted) {
                  setState(() => _pendingRequests.remove(req));
                  _loadDetails();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تم رفض الطلب', 'Request rejected')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                t('تأكيد الرفض', 'Confirm Decline'),
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReasonEn(String ar) {
    switch (ar) {
      case 'المعرض ممتلئ':
        return 'Exhibition full';
      case 'التخصص غير مناسب':
        return 'Specialty mismatch';
      case 'عدد الحرفيين كافٍ':
        return 'Enough artisans';
      case 'لم يتم استيفاء متطلبات المشاركة':
        return 'Requirements not met';
      case 'أسباب أخرى':
        return 'Other';
      default:
        return ar;
    }
  }

  Widget _infoRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.cairo(color: dim, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
                color: text, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _participants {
    final craftsmen = (_exhibitionData?['ExhibitionCraftsmen'] as List?) ?? [];
    return craftsmen
        .where((ec) => (ec['status'] ?? '') == 'confirmed')
        .map((ec) {
      final craftsman = ec['Craftsman'] as Map<String, dynamic>? ?? {};
      return {
        'id': craftsman['id']?.toString() ?? '',
        'boothId': ec['boothId'] ?? '',
        'name': craftsman['name'] ?? '',
        'nameEn': craftsman['name'] ?? '',
        'craft': ec['craftCategory'] ?? '',
        'craftEn': ec['craftCategory'] ?? '',
        'city': craftsman['city'] ?? 'عمان',
        'cityEn': craftsman['city'] ?? 'Amman',
        'status': ec['status'] ?? 'confirmed',
        'rating': 4.8,
        'completedOrders': 20,
        'available': true,
      };
    }).toList();
  }

  // ─── Admin actions ────────────────────────────────────────────────
  Future<void> _adminApprove() async {
    final exhibId = _exhibitionData?['id']?.toString();
    if (exhibId == null) return;
    final result = await ExhibitionsService.approveExhibition(exhibId);
    if (result != null && mounted) {
      setState(() {
        _exhibitionData?['verified'] = true;
        _exhibitionData?['status'] = 'active';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم الموافقة على المعرض', 'Exhibition approved')),
          backgroundColor: Colors.green,
        ),
      );
      _loadDetails();
    }
  }

  Future<void> _adminReject() async {
    final exhibId = _exhibitionData?['id']?.toString();
    if (exhibId == null) return;
    final result = await ExhibitionsService.rejectExhibition(
        exhibId, t('تم الرفض من قبل الإدارة', 'Rejected by admin'));
    if (result != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم رفض المعرض', 'Exhibition rejected')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _adminSuspend() async {
    final exhibId = _exhibitionData?['id']?.toString();
    if (exhibId == null) return;
    final status = (_exhibitionData?['status'] ?? '') == 'suspended'
        ? 'active'
        : 'suspended';
    final result =
        await ExhibitionsService.adminOverrideStatus(exhibId, status);
    if (result != null && mounted) {
      setState(() {
        _exhibitionData?['status'] = status;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'suspended'
                ? t('تم تعليق المعرض', 'Exhibition suspended')
                : t('تم إعادة تفعيل المعرض', 'Exhibition reactivated'),
          ),
          backgroundColor: status == 'suspended' ? Colors.orange : Colors.green,
        ),
      );
      _loadDetails();
    }
  }

  Future<void> _adminDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('تأكيد الحذف', 'Confirm Delete'),
            style: GoogleFonts.cairo(color: text)),
        content: Text(
            t('هل أنت متأكد من حذف هذا المعرض؟',
                'Are you sure you want to delete this exhibition?'),
            style: TextStyle(color: dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('إلغاء', 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final exhibId = _exhibitionData?['id']?.toString();
    if (exhibId == null) return;
    final success = await ExhibitionsService.deleteExhibition(exhibId);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(t('تم حذف المعرض', 'Exhibition deleted')),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;

    if (_isLoadingDetails) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    if (_error.isNotEmpty || _exhibitionData == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(t('حدث خطأ', 'Something went wrong'),
                  style: GoogleFonts.cairo(color: text, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error,
                  style: GoogleFonts.cairo(color: dim, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetails,
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.black),
                child: Text(t('إعادة المحاولة', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final exhibition = _exhibitionData!;
    final name = isArabic ? exhibition['name'] : exhibition['nameEn'];
    final gradient = _parseGradient(exhibition['gradient']);
    final bannerImageUrl = exhibition['bannerUrl'] ?? exhibition['imageUrl'];
    final participants = _participants;
    final owner = exhibition['Owner'] ?? {};
    final ownerName = owner['name'] ?? 'غير معروف';

    final boothPrice = (exhibition['boothLayout'] as List?)?.firstWhere(
          (b) => b['price'] != null,
          orElse: () => {'price': 0},
        )['price'] ??
        0;
    final showRequests = boothPrice == 0 && _pendingRequests.isNotEmpty;

    final isPending =
        exhibition['status'] == 'pending' || exhibition['verified'] == false;
    final isSuspended = exhibition['status'] == 'suspended';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1100 : double.infinity,
                ),
                child: CustomScrollView(
                  slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: surface,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  name ?? '',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(blurRadius: 6, color: Colors.black87)
                    ],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        image: (bannerImageUrl != null &&
                                bannerImageUrl.toString().isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(bannerImageUrl.toString()),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: (bannerImageUrl != null &&
                              bannerImageUrl.toString().isNotEmpty)
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.black.withValues(alpha: 0.1)
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (_isUploadingBanner)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                    Positioned(
                      top: 40,
                      right: isArabic ? null : 16,
                      left: isArabic ? 16 : null,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _pickAndUploadBanner,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  t('تغيير الغلاف', 'Edit Banner'),
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Owner info (admin only)
                    if (widget.isAdminView)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person,
                                color: Color(0xFFD4A017), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${t('المالك', 'Owner')}: $ownerName',
                              style: GoogleFonts.cairo(
                                  color: text, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    // Info Card
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
                          // ─── FIX: Location Row with Expanded ───
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        color: accent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? exhibition['location']
                                            : exhibition['locationEn'],
                                        style: GoogleFonts.cairo(
                                            color: text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: exhibition['type'] == 'Public'
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  exhibition['type'] == 'Public'
                                      ? t('عام', 'Public')
                                      : t('خاص', 'Private'),
                                  style: GoogleFonts.cairo(
                                    color: exhibition['type'] == 'Public'
                                        ? Colors.blueAccent
                                        : Colors.orangeAccent,
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
                                '${exhibition['startDate']?.toString().split('T')[0] ?? ''} - ${exhibition['endDate']?.toString().split('T')[0] ?? ''}',
                                style: GoogleFonts.cairo(color: text),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            exhibition['description'] ?? '',
                            style: GoogleFonts.cairo(
                                color: dim, height: 1.5, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Booth Layout
                    _buildBoothLayout(participants, appState),
                    const SizedBox(height: 24),

                    // AI Predictor
                    _buildAIPredictor(appState),
                    const SizedBox(height: 24),

                    // AI Trust Score
                    _buildAITrustScore(appState),
                    const SizedBox(height: 24),

                    // Participation Requests
                    if (showRequests)
                      _buildRequestsSection(appState)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: accent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t(
                                  'هذا المعرض يتطلب رسوم كشك. طلبات المشاركة ستظهر هنا عند توفر أكشاك مجانية.',
                                  'This exhibition has booth fees. Participation requests will appear here when free booths are available.',
                                ),
                                style:
                                    GoogleFonts.cairo(color: dim, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Participating Artisans
                    _buildParticipatingArtisans(participants, appState),
                    const SizedBox(height: 24),

                    // Location Details
                    _buildLocationDetails(appState),
                    const SizedBox(height: 24),

                    // Admin Actions
                    if (widget.isAdminView)
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
                            Text(
                              t('إجراءات الإدارة', 'Admin Actions'),
                              style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (isPending)
                                  ElevatedButton.icon(
                                    onPressed: _adminApprove,
                                    icon: const Icon(Icons.check, size: 16),
                                    label: Text(t('موافقة', 'Approve')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                if (isPending)
                                  OutlinedButton.icon(
                                    onPressed: _adminReject,
                                    icon: const Icon(Icons.close, size: 16),
                                    label: Text(t('رفض', 'Reject')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ElevatedButton.icon(
                                  onPressed: _adminSuspend,
                                  icon: Icon(
                                      isSuspended
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                      size: 16),
                                  label: Text(
                                    isSuspended
                                        ? t('إعادة تفعيل', 'Reactivate')
                                        : t('تعليق', 'Suspend'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSuspended
                                        ? Colors.green
                                        : Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExhibitionAddScreen(
                                          existingExhibition: exhibition,
                                          isAdminView: true,
                                        ),
                                      ),
                                    ).then((result) {
                                      if (result != null) _loadDetails();
                                    });
                                  },
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: Text(t('تعديل', 'Edit')),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: accent),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _adminDelete,
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: Text(t('حذف', 'Delete')),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
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
}

  // ─── Booth Layout ────────────────────────────────────
  Widget _buildBoothLayout(
      List<Map<String, dynamic>> participants, AppState appState) {
    final rows = _exhibitionData?['boothRows'] ?? 2;
    final columns = _exhibitionData?['boothColumns'] ?? 3;
    return Container(
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
              Icon(Icons.storefront_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                t('توزيع الأكشاك', 'Booth Layout'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('${rows}x$columns',
                  style: GoogleFonts.cairo(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: rows * columns,
            itemBuilder: (context, index) {
              final participant =
                  participants.length > index ? participants[index] : null;
              final isOccupied = participant != null &&
                  participant['name'] != null &&
                  participant['name'] != '';
              final boothId = participant != null
                  ? participant['boothId']
                  : '${String.fromCharCode(65 + (index ~/ columns))}${(index % columns) + 1}';
              return GestureDetector(
                onTap: isOccupied
                    ? () {
                        final artisan = {
                          'id': participant['id'] ?? '',
                          'name': participant['name'] ?? '',
                          'nameEn': participant['nameEn'] ?? '',
                          'craft': participant['craft'] ?? '',
                          'craftEn': participant['craftEn'] ?? '',
                          'city': participant['city'] ?? 'عمان',
                          'cityEn': participant['cityEn'] ?? 'Amman',
                          'rating': participant['rating'] ?? 4.8,
                          'completedOrders':
                              participant['completedOrders'] ?? 20,
                          'available': participant['available'] ?? true,
                        };
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CraftsmanPublicProfileScreen(
                              artisan: artisan,
                              isArabic: appState.isArabic,
                              isDarkMode: appState.isDarkMode,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isOccupied ? accent.withValues(alpha: 0.1) : surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isOccupied ? accent : border,
                        width: isOccupied ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(boothId,
                          style: TextStyle(
                              color: isOccupied ? accent : dim,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (isOccupied) ...[
                        const SizedBox(height: 2),
                        Text(
                          participant['name'] as String,
                          style: TextStyle(
                              color: text,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                      if (!isOccupied)
                        Text(t('متاح', 'Available'),
                            style: TextStyle(color: dim, fontSize: 9)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(accent, t('محجوز', 'Taken'), appState),
              _legendItem(Colors.transparent, t('متاح', 'Available'), appState),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color == Colors.transparent ? surface : color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 10)),
      ],
    );
  }

  // ─── AI Predictor ────────────────────────────────────────────────
  Widget _buildAIPredictor(AppState appState) {
    final isArabic = appState.isArabic;
    final visitors = _predictionData?['expectedVisitors'] ?? '+450';
    final salesChance = isArabic
        ? (_predictionData?['salesChance'] ?? t('ممتاز', 'Excellent'))
        : (_predictionData?['salesChanceEn'] ?? 'Excellent');
    final forecastText = isArabic
        ? (_predictionData?['forecast'] ??
            'بناءً على الموقع الممتاز والطقس المشمس في هذه التواريخ، نتوقع حضوراً كثيفاً.')
        : (_predictionData?['forecastEn'] ??
            'Based on the prime location and sunny weather on these dates, we expect high turnout.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('متنبئ المعارض بالذكاء الاصطناعي', 'AI Exhibition Predictor'),
            style: GoogleFonts.cairo(
                color: text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.05), surface]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('توقعات الحضور والمبيعات',
                          'Attendance & Sales Forecast'),
                      style: GoogleFonts.cairo(
                          color: text, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(visitors,
                          style: GoogleFonts.cairo(
                              color: accent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text(t('زائر متوقع', 'Expected Visitors'),
                          style: GoogleFonts.cairo(color: dim, fontSize: 12)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: border),
                  Column(
                    children: [
                      Text(salesChance,
                          style: GoogleFonts.cairo(
                              color: Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text(t('فرصة المبيعات', 'Sales Chance'),
                          style: GoogleFonts.cairo(color: dim, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(forecastText,
                  style: GoogleFonts.cairo(
                      color: dim, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── AI Trust Score ──────────────────────────────────────────────
  Widget _buildAITrustScore(AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final locationVerified = _trustScoreData?['locationVerified'] ?? true;
    final datesValid = _trustScoreData?['datesValid'] ?? true;
    final isNewAccount = _trustScoreData?['isNewAccount'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('تحليل الذكاء الاصطناعي', 'AI Trust Analysis'),
            style: GoogleFonts.cairo(
                color: text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              primaryDark.withValues(alpha: 0.1),
              accent.withValues(alpha: 0.05)
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryDark.withValues(alpha: 0.3)),
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
                      builder: (context, child) => CircularProgressIndicator(
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
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                            locationVerified
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: locationVerified
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(t('الموقع محقق', 'Location Verified'),
                            style:
                                GoogleFonts.cairo(color: text, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(datesValid ? Icons.check_circle : Icons.cancel,
                            color: datesValid
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(t('التواريخ منطقية', 'Dates Valid'),
                            style:
                                GoogleFonts.cairo(color: text, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                            isNewAccount
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color: isNewAccount
                                ? Colors.amber
                                : Colors.greenAccent,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                            isNewAccount
                                ? t('حساب حديث', 'New Account')
                                : t('حساب موثق', 'Verified Account'),
                            style:
                                GoogleFonts.cairo(color: text, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        t('قيد المراجعة من فريق CraftGo',
                            'Under Review by CraftGo Team'),
                        style: GoogleFonts.cairo(
                            color: dim,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Requests Section ──────────────────────────────────────────────
  Widget _buildRequestsSection(AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    if (_pendingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: accent.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(t('لا توجد طلبات معلقة', 'No pending requests'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                t('سيظهر هنا طلبات الحرفيين الجديدة',
                    'New artisan requests will appear here'),
                style: GoogleFonts.cairo(color: dim, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t('طلبات المشاركة المعلقة', 'Pending Requests'),
                style: GoogleFonts.cairo(
                    color: text, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${_pendingRequests.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingRequests.map((req) => _buildRequestCard(req, appState)),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, AppState appState) {
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final artisanMap = {
      'id': req['craftsmanId'] ?? '',
      'name': req['name'] ?? '',
      'nameEn': req['nameEn'] ?? '',
      'craft': req['craft'] ?? '',
      'craftEn': req['craftEn'] ?? '',
      'city': req['city'] ?? 'عمان',
      'cityEn': req['cityEn'] ?? 'Amman',
      'rating': req['rating'] ?? 4.8,
      'completedOrders': req['completedOrders'] ?? 20,
      'available': req['available'] ?? true,
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CraftsmanPublicProfileScreen(
              artisan: artisanMap,
              isArabic: isArabic,
              isDarkMode: isDarkMode,
              showFavoriteButton: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    isArabic ? req['name'][0] : req['nameEn'][0],
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isArabic ? req['name'] : req['nameEn'],
                          style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Row(
                        children: [
                          Text(isArabic ? req['craft'] : req['craftEn'],
                              style:
                                  GoogleFonts.cairo(color: dim, fontSize: 12)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '${t('كشك', 'Booth')} ${req['boothId']}',
                                style: GoogleFonts.cairo(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(isArabic ? req['time'] : req['timeEn'],
                    style: GoogleFonts.cairo(color: dim, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showAcceptConfirmationDialog(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(t('قبول', 'Accept')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDeclineDialog(req),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(t('رفض', 'Reject')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Participating Artisans ─────────────────────────────────────────
  Widget _buildParticipatingArtisans(
      List<Map<String, dynamic>> participants, AppState appState) {
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    final confirmed = participants
        .where((p) => p['name'] != null && p['name'] != '')
        .toList();

    if (confirmed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            t('لا يوجد حرفيون مشاركون حالياً', 'No participating artisans yet'),
            style: GoogleFonts.cairo(color: dim, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('الحرفيون المشاركون (${confirmed.length})',
              'Participating Artisans (${confirmed.length})'),
          style: GoogleFonts.cairo(
              color: text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: confirmed.map((p) {
            final name = p['name'] as String;
            final craft = p['craft'] as String;
            final boothId = p['boothId'] as String;

            final artisanMap = {
              'id': p['id'] ?? '',
              'name': name,
              'nameEn': p['nameEn'] ?? name,
              'craft': craft,
              'craftEn': p['craftEn'] ?? craft,
              'city': p['city'] ?? 'عمان',
              'cityEn': p['cityEn'] ?? 'Amman',
              'rating': p['rating'] ?? 4.8,
              'completedOrders': p['completedOrders'] ?? 20,
              'available': p['available'] ?? true,
            };

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CraftsmanPublicProfileScreen(
                      artisan: artisanMap,
                      isArabic: isArabic,
                      isDarkMode: isDarkMode,
                      showFavoriteButton: true,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 80,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      child: Text(name[0],
                          style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ),
                    const SizedBox(height: 4),
                    Text(name,
                        style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    Text(t('كشك $boothId', 'Booth $boothId'),
                        style: GoogleFonts.cairo(color: dim, fontSize: 8)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Location Details ──────────────────────────────────────────────
  Widget _buildLocationDetails(AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    final country = _exhibitionData?['country'] ?? '';
    final city = _exhibitionData?['city'] ?? '';
    final street = _exhibitionData?['street'] ?? '';
    final building = _exhibitionData?['building'] ?? '';
    final extraDetails = _exhibitionData?['extraDetails'] ?? '';

    final hasLocation = country.isNotEmpty ||
        city.isNotEmpty ||
        street.isNotEmpty ||
        building.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('تفاصيل الموقع', 'Location Details'),
            style: GoogleFonts.cairo(
                color: text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: hasLocation
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (country.isNotEmpty) ...[
                      _locationRow(
                          icon: Icons.public,
                          label: t('الدولة', 'Country'),
                          value: country),
                      const SizedBox(height: 8),
                    ],
                    if (city.isNotEmpty) ...[
                      _locationRow(
                          icon: Icons.location_city,
                          label: t('المدينة', 'City'),
                          value: city),
                      const SizedBox(height: 8),
                    ],
                    if (street.isNotEmpty) ...[
                      _locationRow(
                          icon: Icons.streetview,
                          label: t('الشارع', 'Street'),
                          value: street),
                      const SizedBox(height: 8),
                    ],
                    if (building.isNotEmpty) ...[
                      _locationRow(
                          icon: Icons.home,
                          label: t('المبنى / الوحدة', 'Building / Unit'),
                          value: building),
                      const SizedBox(height: 8),
                    ],
                    if (extraDetails.isNotEmpty) ...[
                      _locationRow(
                          icon: Icons.info_outline,
                          label: t('تفاصيل إضافية', 'Additional Details'),
                          value: extraDetails),
                    ],
                  ],
                )
              : Center(
                  child: Text(
                    t('لا توجد تفاصيل موقع محددة',
                        'No location details provided'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 14),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _locationRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: GoogleFonts.cairo(
                  color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: GoogleFonts.cairo(color: text, fontSize: 13))),
      ],
    );
  }
}

// ─── Helper: RadioGroup (used in decline dialog) ──────────────────
class RadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final Widget child;

  const RadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroupScope(
      groupValue: groupValue,
      onChanged: onChanged,
      child: child,
    );
  }
}

class RadioGroupScope<T> extends InheritedWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  const RadioGroupScope({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  static RadioGroupScope<T>? of<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RadioGroupScope<T>>();
  }

  @override
  bool updateShouldNotify(covariant RadioGroupScope<T> oldWidget) {
    return groupValue != oldWidget.groupValue ||
        onChanged != oldWidget.onChanged;
  }
}
