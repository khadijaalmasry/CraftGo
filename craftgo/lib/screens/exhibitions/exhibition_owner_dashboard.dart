import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import '../../services/payment_service.dart';
import 'exhibition_add_screen.dart';
import 'craftsmen_browse_screen.dart';
import 'craftsman_public_profile_screen.dart';

class ExhibitionOwnerDashboard extends StatefulWidget {
  final String ownerName;
  final void Function(int)? onSwitchTab;

  const ExhibitionOwnerDashboard({
    super.key,
    required this.ownerName,
    this.onSwitchTab,
  });

  @override
  State<ExhibitionOwnerDashboard> createState() =>
      _ExhibitionOwnerDashboardState();
}

class _ExhibitionOwnerDashboardState extends State<ExhibitionOwnerDashboard>
    with TickerProviderStateMixin {
  // ── Local state ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _exhibitions = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  Map<String, dynamic>? _earningsData;
  int _totalCraftsmen = 0;
  bool _isLoading = true;

  // ── Pagination ────────────────────────────────────────────────────
  int _recentPage = 0;
  final int _recentPageSize = 3;

  // ── Selected event filter for requests ─────────────────────────────
  String? _selectedEventFilter;
  TabController? _tabController;

  // ── Theme helpers ──────────────────────────────────────────────────
  Color get bg => context.read<AppState>().isDarkMode
      ? const Color(0xFF0D1420)
      : const Color(0xFFF5F6F8);
  Color get surface => context.read<AppState>().isDarkMode
      ? const Color(0xFF1C2431)
      : Colors.white;
  Color get text =>
      context.read<AppState>().isDarkMode ? Colors.white : Colors.black87;
  Color get dim =>
      context.read<AppState>().isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => context.read<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);
  Color get accentLight => const Color(0xFFF7E8B5);
  Color get accentDark => const Color(0xFFB8860B);
  Color get primaryDark => const Color(0xFF0D1B33);

  String t(String ar, String en) => context.read<AppState>().isArabic ? ar : en;

  // ── Quick actions ──────────────────────────────────────────────────
  void _addExhibition() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExhibitionAddScreen(),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        _loadDashboardData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('تم إضافة المعرض بنجاح ✅', 'Exhibition added ✅')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  void _manageCraftsmen() {
    widget.onSwitchTab?.call(2);
  }

  void _showStarredArtisans() {
    final appState = context.read<AppState>();
    final starred = appState.starredArtisans;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.star, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      t('الحرفيون المفضّلون', 'Starred Artisans'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: dim),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: border),
              Expanded(
                child: starred.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_border,
                              size: 48,
                              color: dim.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t('لا توجد حرفيون مفضّلون',
                                  'No starred artisans yet'),
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('قم بتفضيل الحرفيين من خلال الضغط على النجمة في ملفهم الشخصي',
                                  'Star artisans by tapping the star on their profile'),
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: starred.length,
                        itemBuilder: (_, i) {
                          final a = starred[i];
                          final isArabic = context.watch<AppState>().isArabic;
                          final name = isArabic ? a['name'] : a['nameEn'];
                          final craft = isArabic ? a['craft'] : a['craftEn'];
                          final city = isArabic ? a['city'] : a['cityEn'];
                          final rating = a['rating'];
                          return ListTile(
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CraftsmanPublicProfileScreen(
                                    artisan: a,
                                    isArabic: isArabic,
                                    isDarkMode:
                                        context.watch<AppState>().isDarkMode,
                                    showFavoriteButton: true,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: accent.withValues(alpha: 0.2),
                              child: Text(
                                name[0],
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$craft • $city',
                              style: GoogleFonts.cairo(color: dim),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating?.toString() ?? '0.0',
                                  style: GoogleFonts.cairo(
                                    color: accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Data loading ──────────────────────────────────────────────────────
  Future<void> _loadDashboardData() async {
    final appState = context.read<AppState>();
    final ownerId = appState.userId;
    if (ownerId == null || ownerId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final backendExhibitions =
          await ExhibitionsService.getOwnerExhibitions(ownerId);
      final mappedExhibitions = <Map<String, dynamic>>[];
      final pending = <Map<String, dynamic>>[];
      int craftsmenCount = 0;

      for (final item in backendExhibitions) {
        List<Color> gradientColors = [
          const Color(0xFFD4A017),
          const Color(0xFFB8860B)
        ];
        if (item['gradient'] != null &&
            item['gradient'] is List &&
            (item['gradient'] as List).isNotEmpty) {
          try {
            gradientColors = (item['gradient'] as List).map((c) {
              final hex = c.toString().replaceAll('#', '');
              return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex));
            }).toList();
          } catch (_) {}
        }

        final craftsmen = (item['ExhibitionCraftsmen'] as List?) ?? [];
        craftsmenCount += craftsmen.length;

        // Collect pending participation requests for this exhibition
        for (final ec in craftsmen) {
          final status = (ec['status'] ?? '').toString();
          if (status == 'pending') {
            final craftsman = ec['Craftsman'] as Map<String, dynamic>? ?? {};
            final name = craftsman['name']?.toString() ?? '';
            final exhibitionName = item['name']?.toString() ?? '';
            // Only add if we have both a name and exhibition name
            if (name.isNotEmpty && exhibitionName.isNotEmpty) {
              pending.add({
                'id': ec['id']?.toString() ?? '', // registration ID
                'craftsmanId': craftsman['id']?.toString() ??
                    '', // ✅ actual craftsman user ID
                'exhibitionId': item['id']?.toString() ?? '',
                'exhibition': exhibitionName,
                'exhibitionEn': item['nameEn']?.toString() ?? exhibitionName,
                'name': name,
                'nameEn': craftsman['name']?.toString() ?? name,
                'craft': ec['craftCategory']?.toString() ?? 'حرفة',
                'craftEn': ec['craftCategory']?.toString() ?? 'Craft',
                'boothId': ec['boothId']?.toString() ?? '',
                'status': status,
                'time': 'منذ قليل',
                'timeEn': 'Recently',
              });
            }
          }
        }

        final status = item['status']?.toString().toLowerCase() ?? 'upcoming';
        final statusMap = {
          'active': 'Active',
          'upcoming': 'Upcoming',
          'past': 'Past',
        };
        final mappedStatus = statusMap[status] ?? 'Upcoming';

        mappedExhibitions.add({
          'id': item['id']?.toString() ?? '',
          'name': item['name'] ?? '',
          'nameEn': item['nameEn'] ?? item['name'] ?? '',
          'status': mappedStatus,
          'type': 'Public',
          'location': item['location'] ?? '',
          'locationEn': item['locationEn'] ?? item['location'] ?? '',
          'startDate': item['startDate'] != null
              ? item['startDate'].toString().split('T')[0]
              : '',
          'endDate': item['endDate'] != null
              ? item['endDate'].toString().split('T')[0]
              : '',
          'selectedDates': item['selectedDates'] ?? [],
          'description': item['description'] ?? '',
          'maxCapacity': item['capacity'] ?? 0,
          // Booth & layout
          'boothPrice': (item['boothPrice'] != null)
              ? double.tryParse(item['boothPrice'].toString()) ?? 0.0
              : 0.0,
          'boothRows': item['boothRows'] ?? 2,
          'boothColumns': item['boothColumns'] ?? 3,
          'boothLayout': item['boothLayout'] ?? [],
          'categoryCapacities': item['categoryCapacities'] ?? {},
          // Classification
          'eventType': item['eventType'],
          'eventTheme': item['eventTheme'],
          'targetAudience': item['targetAudience'],
          'priceRange': item['priceRange'],
          'isPublic': item['isPublic'] ?? true,
          // Location detail
          'country': item['country'] ?? '',
          'city': item['city'] ?? '',
          'street': item['street'] ?? '',
          'building': item['building'] ?? '',
          'extraDetails': item['extraDetails'] ?? '',
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'manualLocation': item['manualLocation'] ?? false,
          // Venue & permits
          'venueType': item['venueType'],
          'hasPermit': item['hasPermit'] ?? false,
          'hasBusinessLicense': item['hasBusinessLicense'] ?? false,
          'permitNumber': item['permitNumber'] ?? '',
          'issuerName': item['issuerName'] ?? '',
          'issuerPhone': item['issuerPhone'] ?? '',
          'issueDate': item['issueDate'],
          'expiryDate': item['expiryDate'],
          // Crafts
          'crafts': item['crafts'] ?? [],
          // Display
          'imageUrl': item['imageUrl'],
          'interested': craftsmen.length,
          'gradient': gradientColors,
          'participants': craftsmen.map((ec) {
            final c = ec['Craftsman'] as Map<String, dynamic>? ?? {};
            return {
              'boothId': ec['boothId'] ?? '',
              'name': c['name'] ?? '',
              'nameEn': c['name'] ?? '',
              'craft': ec['craftCategory'] ?? '',
              'craftEn': ec['craftCategory'] ?? '',
              'status': ec['status'] ?? 'confirmed',
            };
          }).toList(),
        });
      }

      final earnings = await PaymentService.getOwnerEarnings();

      setState(() {
        _exhibitions = mappedExhibitions;
        _pendingRequests = pending;
        _totalCraftsmen = craftsmenCount;
        _earningsData = earnings;
        _isLoading = false;
      });

      // Update tab controller
      _tabController?.dispose();
      final names = _pendingRequests
          .map((r) => r['exhibition'] as String)
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) {
        _tabController = TabController(length: names.length, vsync: this);
        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) {
            setState(() {
              _selectedEventFilter = names[_tabController!.index];
            });
          }
        });
        setState(() {
          _selectedEventFilter = names.first;
        });
      } else {
        _tabController = TabController(length: 0, vsync: this);
        setState(() {
          _selectedEventFilter = null;
        });
      }
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Accept / Decline dialogs ──────────────────────────────────────
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
    final customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            t('سبب الرفض', 'Decline Reason'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? req['name'] : req['nameEn'],
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t('اختر سبب الرفض (اختياري):',
                    'Select a decline reason (optional):'),
                style: GoogleFonts.cairo(color: dim, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ..._declineReasons.map((reason) => RadioListTile<String>(
                    title: Text(
                      isArabic ? reason : _getReasonEn(reason),
                      style: GoogleFonts.cairo(color: text),
                    ),
                    value: reason,
                    groupValue: _selectedDeclineReason,
                    onChanged: (value) =>
                        setDialogState(() => _selectedDeclineReason = value),
                    activeColor: accent,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: customReasonController,
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
              child: Text(
                t('إلغاء', 'Cancel'),
                style: TextStyle(color: dim),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final customText = customReasonController.text.trim();
                final reasonToSave = customText.isNotEmpty
                    ? customText
                    : (_selectedDeclineReason != null
                        ? (isArabic
                            ? _selectedDeclineReason!
                            : _getReasonEn(_selectedDeclineReason!))
                        : (isArabic
                            ? 'لم يتم استيفاء المتطلبات'
                            : 'Requirements not met'));

                Navigator.pop(ctx);
                final regId = req['id']?.toString() ?? '';
                final exhibId = req['exhibitionId']?.toString() ?? '';
                if (regId.isNotEmpty && exhibId.isNotEmpty) {
                  await ExhibitionsService.updateRegistrationStatus(
                    exhibId,
                    regId,
                    'rejected',
                    reason: reasonToSave,
                  );
                }
                await _loadDashboardData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تم رفض الطلب وإبلاغ الحرفي بالسبب',
                          'Request rejected and artisan notified')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t('تأكيد الرفض', 'Confirm Decline'),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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

  void _showAcceptConfirmationDialog(Map<String, dynamic> req) {
    final isArabic = context.read<AppState>().isArabic;
    final name = isArabic ? req['name'] : req['nameEn'];
    final craft = isArabic ? req['craft'] : req['craftEn'];
    final exhibition = req['exhibition'];
    final boothId = req['boothId'];
    final isStandby = req['status'] == 'standby';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: accent, size: 28),
            const SizedBox(width: 10),
            Text(
              isStandby
                  ? t('تأكيد القبول في الاحتياط', 'Confirm Standby Acceptance')
                  : t('تأكيد القبول', 'Confirm Acceptance'),
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
                    value: name,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.handyman_outlined,
                    label: t('التخصص', 'Craft'),
                    value: craft,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.event_outlined,
                    label: t('المعرض', 'Exhibition'),
                    value: exhibition,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.room_outlined,
                    label: t('الكشك المفصل', 'Preferred Booth'),
                    value: '$boothId',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isStandby
                          ? t(
                              'سيتم إدراج هذا الحرفي في قائمة الاحتياط وسيتم إشعاره بذلك.',
                              'This artisan will be added to the standby list and will receive a notification.',
                            )
                          : t(
                              'سيتم تأكيد مشاركة هذا الحرفي في المعرض وسيتم إشعاره بذلك.',
                              'This artisan will be confirmed for the exhibition and will receive a notification.',
                            ),
                      style: GoogleFonts.cairo(
                        color: Colors.amber.shade700,
                        fontSize: 12,
                      ),
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
            child: Text(
              t('إلغاء', 'Cancel'),
              style: TextStyle(color: dim),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final regId = req['id']?.toString() ?? '';
              final exhibId = req['exhibitionId']?.toString() ?? '';
              final targetStatus = isStandby ? 'standby' : 'confirmed';
              if (regId.isNotEmpty && exhibId.isNotEmpty) {
                await ExhibitionsService.updateRegistrationStatus(
                    exhibId, regId, targetStatus);
              }
              await _loadDashboardData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isStandby
                          ? t('تم إضافة ${isArabic ? req['name'] : req['nameEn']} لقائمة الاحتياط!',
                              '${isArabic ? req['name'] : req['nameEn']} added to standby list!')
                          : t('تم قبول ${isArabic ? req['name'] : req['nameEn']} في المعرض!',
                              '${isArabic ? req['name'] : req['nameEn']} accepted to the exhibition!'),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              t('تأكيد القبول', 'Confirm Accept'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.cairo(
            color: dim,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final exhibitionCount = _exhibitions.length;
    final totalInterested = _exhibitions.fold<int>(
        0, (sum, item) => sum + ((item['interested'] as int?) ?? 0));

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: RefreshIndicator(
          color: accent,
          onRefresh: _loadDashboardData,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                if (isDesktop) {
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(
                                  color: accent,
                                  backgroundColor:
                                      accentLight.withValues(alpha: 0.3),
                                  minHeight: 3,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),

                            // Hero Header & Quick Actions Desktop Container
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t('مرحباً، ${widget.ownerName}',
                                                'Welcome, ${widget.ownerName}'),
                                            style: GoogleFonts.cairo(
                                              color: text,
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            t('إدارة معارضك ومتابعة الطلبات',
                                                'Manage your exhibitions and requests'),
                                            style: GoogleFonts.cairo(
                                                color: dim, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Stats Row
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.event,
                                        number: '$exhibitionCount',
                                        label: t('معارض', 'Exhibitions'),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.people,
                                        number: '$_totalCraftsmen',
                                        label: t('حرفيون', 'Artisans'),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.hourglass_empty,
                                        number: '${_pendingRequests.length}',
                                        label: t('طلبات', 'Requests'),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.favorite,
                                        number: '$totalInterested',
                                        label: t('مهتمون', 'Interested'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Quick Actions
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildActionButton(
                                          icon: Icons.add,
                                          label:
                                              t('معرض جديد', 'New Exhibition'),
                                          onTap: _addExhibition,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildActionButton(
                                          icon: Icons.search,
                                          label: t('حرفيون', 'Craftsmen'),
                                          onTap: _manageCraftsmen,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildActionButton(
                                          icon: Icons.star,
                                          label: t('مفضّلون', 'Starred'),
                                          onTap: _showStarredArtisans,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Revenue Overview Card
                            _buildEarningsCard(),
                            const SizedBox(height: 28),

                            // 2-Column Desktop Grid: Recent Exhibitions & Pending Requests
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('معارضي الأخيرة',
                                            'Recent Exhibitions'),
                                        style: GoogleFonts.cairo(
                                          color: text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildRecentExhibitions(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildRequestsSection(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Mobile Layout (< 600px / mobile screen)
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            color: accent,
                            backgroundColor: accentLight.withValues(alpha: 0.3),
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                      // Header
                      Text(
                        t('مرحباً، ${widget.ownerName}',
                            'Welcome, ${widget.ownerName}'),
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('إدارة معارضك ومتابعة الطلبات',
                            'Manage your exhibitions and requests'),
                        style: GoogleFonts.cairo(color: dim, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Stats Row
                      Row(
                        children: [
                          _buildStatCard(
                            icon: Icons.event,
                            number: '$exhibitionCount',
                            label: t('معارض', 'Exhibitions'),
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            icon: Icons.people,
                            number: '$_totalCraftsmen',
                            label: t('حرفيون', 'Artisans'),
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            icon: Icons.hourglass_empty,
                            number: '${_pendingRequests.length}',
                            label: t('طلبات', 'Requests'),
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            icon: Icons.favorite,
                            number: '$totalInterested',
                            label: t('مهتمون', 'Interested'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.add,
                              label: t('معرض جديد', 'New Exhibition'),
                              onTap: _addExhibition,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.search,
                              label: t('حرفيون', 'Craftsmen'),
                              onTap: _manageCraftsmen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.star,
                              label: t('مفضّلون', 'Starred'),
                              onTap: _showStarredArtisans,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Revenue Overview
                      _buildEarningsCard(),
                      const SizedBox(height: 32),

                      // Recent Exhibitions
                      Text(
                        t('معارضي الأخيرة', 'Recent Exhibitions'),
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentExhibitions(),
                      const SizedBox(height: 32),

                      // Pending Requests
                      _buildRequestsSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget builders ──────────────────────────────────────────────

  Widget _buildEarningsCard() {
    final summary = _earningsData?['summary'] as Map<String, dynamic>? ?? {};
    final gross = (summary['totalGrossSales'] as num?)?.toDouble() ?? 0.0;
    final commission =
        (summary['totalPlatformFees'] as num?)?.toDouble() ?? 0.0;
    final net = (summary['totalNetEarnings'] as num?)?.toDouble() ?? 0.0;
    final count = (summary['totalBoothsBooked'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.account_balance_wallet, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('أرباح الأكشاك والمبيعات', 'Booth Sales & Revenue'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    t('رسوم منصة CraftGo: 5% فقط', 'CraftGo Platform Fee: 5%'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('إجمالي المبيعات', 'Gross Revenue'),
                        style: GoogleFonts.cairo(color: dim, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gross.toStringAsFixed(2)} JOD',
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('عمولة المنصة (5%)', 'Platform Fee (5%)'),
                        style: GoogleFonts.cairo(color: dim, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '-${commission.toStringAsFixed(2)} JOD',
                        style: GoogleFonts.cairo(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentDark, accent],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('صافي أرباح المنظم المقدرة',
                          'Net Estimated Owner Earnings'),
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${net.toStringAsFixed(2)} JOD',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t('$count أكشاك محجوزة', '$count Booths Booked'),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await PaymentService.openPayoutOnboarding();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t('تعذر فتح رابط إعدادات السحب من Stripe',
                            'Could not open Stripe Payout setup link'),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.account_balance_outlined,
                  color: Colors.white, size: 18),
              label: Text(
                t('ربط / إدارة حساب الـ Stripe لصرف الأرباح',
                    'Connect / Manage Stripe Payout Account'),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF635BFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String number,
    required String label,
  }) {
    final surface = this.surface;
    final text = this.text;
    final dim = this.dim;
    final border = this.border;
    final accent = this.accent;
    final accentLight = this.accentLight;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          gradient: LinearGradient(
            colors: [accentLight.withValues(alpha: 0.15), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 4),
            Text(
              number,
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: dim,
                fontSize: 9,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final surface = this.surface;
    final text = this.text;
    final border = this.border;
    final accent = this.accent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExhibitions() {
    final total = _exhibitions.length;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            t('لا توجد معارض حتى الآن', 'No exhibitions yet'),
            style: GoogleFonts.cairo(color: dim),
          ),
        ),
      );
    }
    final start = _recentPage * _recentPageSize;
    final end =
        (start + _recentPageSize) > total ? total : start + _recentPageSize;
    final pageItems = _exhibitions.sublist(start, end);

    return Column(
      children: [
        ...pageItems.map((ex) => _buildRecentExhibitionCard(ex)),
        if (total > _recentPageSize)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _recentPage > 0
                      ? () => setState(() => _recentPage--)
                      : null,
                  color: _recentPage > 0 ? accent : dim,
                ),
                Text(
                  '${_recentPage + 1} / ${(total / _recentPageSize).ceil()}',
                  style: GoogleFonts.cairo(color: dim),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      end < total ? () => setState(() => _recentPage++) : null,
                  color: end < total ? accent : dim,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentExhibitionCard(Map<String, dynamic> ex) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);

    final name = (isArabic ? ex['name'] : ex['nameEn'])?.toString() ??
        (isArabic ? ex['nameEn'] : ex['name'])?.toString() ??
        t('بدون عنوان', 'Untitled');
    final location =
        (isArabic ? ex['location'] : ex['locationEn'])?.toString() ??
            (isArabic ? ex['locationEn'] : ex['location'])?.toString() ??
            t('غير محدد', 'Not specified');
    final status = ex['status']?.toString() ?? 'Upcoming';
    final statusColor = status == 'Active'
        ? Colors.green
        : (status == 'Upcoming' ? Colors.amber : Colors.grey);
    final statusText = t(
      status == 'Active' ? 'نشط' : (status == 'Upcoming' ? 'قادم' : 'منتهي'),
      status,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: dim),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.cairo(color: dim, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${ex['startDate']} - ${ex['endDate']}',
                      style: GoogleFonts.cairo(color: dim, fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.cairo(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${ex['interested']}/${ex['maxCapacity']}',
            style: GoogleFonts.cairo(
                color: accent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Requests Section ──────────────────────────────────────────────

  Widget _buildRequestsSection() {
    final isArabic = context.watch<AppState>().isArabic;
    // Get unique exhibition names, filtering out null/empty
    final eventNames = _pendingRequests
        .map((r) => r['exhibition']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    if (_pendingRequests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: accent.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              t('لا توجد طلبات معلقة', 'No pending requests'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              t('سيظهر هنا طلبات الحرفيين الجديدة',
                  'New artisan requests will appear here'),
              style: GoogleFonts.cairo(color: dim, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Ensure selected filter is valid; if it's not in the list, reset to first
    if (_selectedEventFilter != null &&
        !eventNames.contains(_selectedEventFilter)) {
      setState(() {
        _selectedEventFilter = eventNames.isNotEmpty ? eventNames.first : null;
      });
    }

    // If no filter is selected, select the first
    if (_selectedEventFilter == null && eventNames.isNotEmpty) {
      setState(() {
        _selectedEventFilter = eventNames.first;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t('طلبات المشاركة المعلقة', 'Pending Requests'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_pendingRequests.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Google-style Tabs ──────────────────────────────────────────
        if (eventNames.isNotEmpty &&
            _tabController != null &&
            _tabController!.length == eventNames.length)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: border),
              ),
            ),
            child: TabBar(
              controller: _tabController!,
              isScrollable: true,
              indicatorColor: accent,
              indicatorWeight: 3,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelColor: accent,
              unselectedLabelColor: dim,
              labelStyle: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.cairo(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              tabs: eventNames.map((name) => Tab(text: name)).toList(),
            ),
          ),

        const SizedBox(height: 12),

        // ── Requests list ──────────────────────────────────────────────
        ..._buildFilteredRequestCards(),
      ],
    );
  }

  List<Widget> _buildFilteredRequestCards() {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              t('لا توجد طلبات في هذا المعرض',
                  'No requests for this exhibition'),
              style: GoogleFonts.cairo(color: dim),
            ),
          ),
        ),
      ];
    }
    return filtered.map((req) => _buildRequestCard(req)).toList();
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedEventFilter == null || _selectedEventFilter!.isEmpty) {
      return List.from(_pendingRequests);
    }
    return _pendingRequests
        .where(
            (r) => (r['exhibition']?.toString() ?? '') == _selectedEventFilter)
        .toList();
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);

    // Safe access with fallbacks
    final safeName = isArabic
        ? (req['name']?.toString() ?? 'حرفي')
        : (req['nameEn']?.toString() ?? 'Craftsman');
    final safeCraft = isArabic
        ? (req['craft']?.toString() ?? 'حرفة')
        : (req['craftEn']?.toString() ?? 'Craft');
    final safeTime = isArabic
        ? (req['time']?.toString() ?? '')
        : (req['timeEn']?.toString() ?? '');
    final safeBoothId = req['boothId']?.toString() ?? '';

    // ✅ Use the actual craftsman ID, not the exhibition ID
    final artisanMap = {
      'id': req['craftsmanId'] ?? '', // <-- correct craftsman ID
      'name': req['name'] ?? 'حرفي',
      'nameEn': req['nameEn'] ?? 'Craftsman',
      'craft': req['craft'] ?? 'حرفة',
      'craftEn': req['craftEn'] ?? 'Craft',
      'city': 'عمان',
      'cityEn': 'Amman',
      'rating': 4.8,
      'completedOrders': 20,
      'available': true,
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
                    safeName.isNotEmpty ? safeName[0] : '?',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeName,
                        style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            safeCraft,
                            style: GoogleFonts.cairo(color: dim, fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                          if (safeBoothId.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${t('كشك', 'Booth')} $safeBoothId',
                                style: GoogleFonts.cairo(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (req['status'] == 'pending'
                                      ? Colors.orange
                                      : Colors.amber)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              req['status'] == 'pending'
                                  ? t('طلب مشاركة', 'Participation Request')
                                  : t('انتظار', 'Standby'),
                              style: GoogleFonts.cairo(
                                color: req['status'] == 'pending'
                                    ? Colors.orange
                                    : Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (safeTime.isNotEmpty)
                  Text(
                    safeTime,
                    style: GoogleFonts.cairo(color: dim, fontSize: 11),
                  ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
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
}
