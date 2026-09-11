import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import '../../services/api_service.dart';
import 'exhibition_detail_screen.dart';
import 'craftsman_public_profile_screen.dart';

class CraftsmenBrowseScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? exhibitions;

  const CraftsmenBrowseScreen({
    super.key,
    this.exhibitions,
  });

  @override
  State<CraftsmenBrowseScreen> createState() => _CraftsmenBrowseScreenState();
}

class _CraftsmenBrowseScreenState extends State<CraftsmenBrowseScreen> {
  // ── State ──────────────────────────────────────────────────────────
  String _searchQuery = '';
  String? _selectedCraftFilter;
  String? _selectedCountry;
  String? _selectedCity;
  int _selectedTabIndex = 0;
  String _categorySearch = '';

  // ── Data ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _artisans = [];
  List<Map<String, dynamic>> _allExhibitions = []; // public (for calendar)
  List<Map<String, dynamic>> _ownerExhibitions = []; // owner's own exhibitions
  bool _isLoadingArtisans = false;
  bool _isLoadingExhibitions = false;
  bool _isLoadingOwnerExhibitions = false;

  // ── Language-aware helpers ──────────────────────────────────────
  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  // ── Countries ────────────────────────────────────────────────────
  List<String> get _countries {
    final base = ['Palestine', 'Jordan'];
    final arabic = ['فلسطين', 'الأردن'];
    final isArabic = context.watch<AppState>().isArabic;
    final list = isArabic ? arabic : base;
    return [t('الكل', 'All'), ...list];
  }

  // ── Cities map (Arabic ↔ English) ──────────────────────────────
  final Map<String, List<String>> _citiesByCountry = {
    'فلسطين': [
      'القدس',
      'رام الله',
      'نابلس',
      'الخليل',
      'بيت لحم',
      'جنين',
      'اريحا',
      'طولكرم',
      'قلقيلية',
      'سلفيت',
      'طوباس'
    ],
    'Palestine': [
      'Jerusalem',
      'Ramallah',
      'Nablus',
      'Hebron',
      'Bethlehem',
      'Jenin',
      'Jericho',
      'Tulkarm',
      'Qalqilya',
      'Salfit',
      'Tubas'
    ],
    'الأردن': [
      'عمان',
      'الزرقاء',
      'اربد',
      'السلط',
      'معان',
      'العقبة',
      'مادبا',
      'جرش',
      'عجلون'
    ],
    'Jordan': [
      'Amman',
      'Zarqa',
      'Irbid',
      'Salt',
      'Ma\'an',
      'Aqaba',
      'Madaba',
      'Jerash',
      'Ajloun'
    ],
  };

  // ── Reverse map: Arabic city → English city ─────────────────────
  Map<String, String> get _arabicToEnglishCity {
    final map = <String, String>{};
    for (final entry in _citiesByCountry.entries) {
      final isArabic = entry.key == 'فلسطين' || entry.key == 'الأردن';
      final englishKey = isArabic
          ? (entry.key == 'فلسطين' ? 'Palestine' : 'Jordan')
          : entry.key;
      final arabicList = _citiesByCountry[isArabic ? entry.key : ''];
      final englishList = _citiesByCountry[englishKey];
      if (arabicList != null && englishList != null) {
        for (int i = 0; i < arabicList.length && i < englishList.length; i++) {
          map[arabicList[i]] = englishList[i];
        }
      }
    }
    return map;
  }

  // ── Load data ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadCraftsmen();
    _loadExhibitions();
    _loadOwnerExhibitions();
  }

  Future<void> _loadCraftsmen() async {
    setState(() => _isLoadingArtisans = true);
    try {
      final data = await ExhibitionsService.getAllCraftsmen();
      if (data.isNotEmpty && mounted) {
        final mapped = data.map<Map<String, dynamic>>((c) {
          final profile = c['ArtisanProfile'] as Map<String, dynamic>? ?? {};
          final craft = profile['primaryCategory'] ?? 'حرفي';
          final craftEn = profile['primaryCategory'] ?? 'Craftsman';
          final city = c['city'] ?? '';
          final cityEn = c['city'] ?? '';
          return {
            'id': c['id']?.toString() ?? '',
            'name': c['name'] ?? '',
            'nameEn': c['name'] ?? '',
            'craft': craft,
            'craftEn': craftEn,
            'city': city,
            'cityEn': cityEn,
            'rating': (profile['rating'] is num)
                ? (profile['rating'] as num).toDouble()
                : 4.5,
            'reviews': profile['reviewCount'] ?? 0,
            'yearsExp': profile['yearsOfExperience'] ?? 1,
            'phone': c['phone'] ?? '',
            'bio': profile['bio'] ?? '',
            'bioEn': profile['bioEn'] ?? profile['bio'] ?? '',
            'isAvailable': profile['isAvailable'] ?? true,
            'country': c['country'] ?? 'Palestine',
            'countryEn': c['country'] ?? 'Palestine',
          };
        }).toList();
        setState(() => _artisans = mapped);
      }
    } catch (e) {
      debugPrint('Error loading craftsmen: $e');
    } finally {
      if (mounted) setState(() => _isLoadingArtisans = false);
    }
  }

  Future<void> _loadExhibitions() async {
    setState(() => _isLoadingExhibitions = true);
    try {
      final data = await ExhibitionsService.getAllExhibitions();
      if (data.isNotEmpty && mounted) {
        setState(() {
          _allExhibitions = data.map<Map<String, dynamic>>((item) {
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
            return {
              ...item,
              'gradient': gradientColors,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading exhibitions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingExhibitions = false);
    }
  }

  // ── Load owner's own exhibitions ──────────────────────────────────
  Future<void> _loadOwnerExhibitions() async {
    final appState = context.read<AppState>();
    final userId = appState.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() => _isLoadingOwnerExhibitions = true);
    try {
      final data = await ExhibitionsService.getOwnerExhibitions(userId);
      if (data.isNotEmpty && mounted) {
        setState(() {
          _ownerExhibitions = data.map<Map<String, dynamic>>((item) {
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
            return {
              ...item,
              'gradient': gradientColors,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading owner exhibitions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOwnerExhibitions = false);
    }
  }

  // ── Get exhibitions owned by the current user (active/upcoming) ──
  List<Map<String, dynamic>> _getMyActiveExhibitions() {
    final appState = context.read<AppState>();
    final userId = appState.userId;
    final isOwner = appState.isExhibitionOwner;

    if (!isOwner || userId == null || userId.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Use _ownerExhibitions (loaded from the owner-specific endpoint)
    return _ownerExhibitions.where((ex) {
      // The ownerId should match; but since it's already owner's, we skip check.
      final status = ex['status']?.toString().toLowerCase() ?? '';
      if (status == 'past' ||
          status == 'completed' ||
          status == 'cancelled' ||
          status == 'rejected' ||
          status == 'draft' ||
          status == 'pending') {
        return false;
      }

      final endDateStr = ex['endDate']?.toString().split('T').first ?? '';
      if (endDateStr.isNotEmpty && todayStr.compareTo(endDateStr) > 0) {
        return false;
      }

      return true;
    }).toList();
  }

  // ── Distinct crafts from artisans ──────────────────────────────
  List<String> _getDistinctCrafts(bool isArabic) {
    final Set<String> crafts = {};
    for (final a in _artisans) {
      final craft = isArabic ? a['craft'] : a['craftEn'];
      if (craft != null && craft.toString().isNotEmpty) {
        crafts.add(craft.toString());
      }
    }
    final sorted = crafts.toList()..sort();
    return [t('الكل', 'All'), ...sorted];
  }

  List<String> _getFilteredCrafts(bool isArabic) {
    final query = _categorySearch.toLowerCase().trim();
    final all = _getDistinctCrafts(isArabic);
    if (query.isEmpty) return all;
    return all.where((c) => c.toLowerCase().contains(query)).toList();
  }

  // ── Available exhibitions for invite (excluding owner filter) ──
  List<Map<String, dynamic>> get _availableExhibitions {
    final list = (widget.exhibitions != null && widget.exhibitions!.isNotEmpty)
        ? widget.exhibitions!
        : _allExhibitions;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    return list.where((e) {
      final status = e['status']?.toString().toLowerCase() ?? '';
      final startDateStr = e['startDate']?.toString().split('T').first ?? '';
      final endDateStr = e['endDate']?.toString().split('T').first ?? '';

      // Exclude inactive / past / pending statuses
      if (status == 'past' ||
          status == 'completed' ||
          status == 'cancelled' ||
          status == 'rejected' ||
          status == 'draft' ||
          status == 'pending') {
        return false;
      }

      // Exclude if end date has passed
      if (endDateStr.isNotEmpty && todayStr.compareTo(endDateStr) > 0) {
        return false;
      }

      if (status == 'active' || status == 'upcoming') {
        return true;
      }

      // Fallback date check: if start date is future or ongoing
      return true;
    }).toList();
  }

  // ── Theme helpers ──────────────────────────────────────────────
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

  // ── Filtered artisans (real-time search & category filter) ─────
  List<Map<String, dynamic>> _getFilteredArtisans(bool isArabic) {
    final query = _searchQuery.toLowerCase().trim();
    final catQuery = _categorySearch.toLowerCase().trim();

    final selectedCityRaw = _selectedCity;
    String? selectedCityEnglish;
    if (selectedCityRaw != null &&
        selectedCityRaw.isNotEmpty &&
        selectedCityRaw != t('الكل', 'All')) {
      selectedCityEnglish =
          _arabicToEnglishCity[selectedCityRaw] ?? selectedCityRaw;
    }

    final craftFilter = _selectedCraftFilter;
    final isAllCraft = craftFilter == null ||
        craftFilter == t('الكل', 'All') ||
        craftFilter == 'الكل' ||
        craftFilter == 'All';

    return _artisans.where((artisan) {
      final name = isArabic
          ? (artisan['name'] ?? '').toString()
          : (artisan['nameEn'] ?? '').toString();
      final craft = isArabic
          ? (artisan['craft'] ?? '').toString()
          : (artisan['craftEn'] ?? '').toString();
      final city = isArabic
          ? (artisan['city'] ?? '').toString()
          : (artisan['cityEn'] ?? '').toString();

      final matchesSearch = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          craft.toLowerCase().contains(query) ||
          city.toLowerCase().contains(query);

      final craftAr = (artisan['craft'] ?? '').toString().toLowerCase();
      final craftEn = (artisan['craftEn'] ?? '').toString().toLowerCase();
      final matchesCategorySearch = catQuery.isEmpty ||
          craftAr.contains(catQuery) ||
          craftEn.contains(catQuery);

      bool matchesCraftChip = true;
      if (!isAllCraft && craftFilter != null) {
        final filterNorm = craftFilter.toLowerCase().trim();
        matchesCraftChip = craftAr == filterNorm ||
            craftEn == filterNorm ||
            craft.toLowerCase().trim() == filterNorm;
      }

      final matchesCity = selectedCityEnglish == null ||
          selectedCityEnglish == t('الكل', 'All') ||
          artisan['cityEn'] == selectedCityEnglish ||
          artisan['city'] == _selectedCity;

      return matchesSearch &&
          matchesCategorySearch &&
          matchesCraftChip &&
          matchesCity;
    }).toList();
  }

  // ── Calendar events ─────────────────────────────────────────────
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap() {
    final events = <DateTime, List<Map<String, dynamic>>>{};
    final isArabic = context.watch<AppState>().isArabic;
    for (final ex in _allExhibitions) {
      final name = isArabic
          ? (ex['name'] ?? ex['nameEn'] ?? '')
          : (ex['nameEn'] ?? ex['name'] ?? '');

      // 1. If selectedDates list is present and non-empty
      final selectedDates = ex['selectedDates'] ?? ex['dates'];
      if (selectedDates is List && selectedDates.isNotEmpty) {
        for (final item in selectedDates) {
          try {
            if (item is Map) {
              final rawDate = item['date'];
              if (rawDate == null) continue;
              final dt = rawDate is DateTime
                  ? rawDate
                  : DateTime.parse(rawDate.toString());
              final dateOnly = DateTime(dt.year, dt.month, dt.day);
              final startT = item['start']?.toString() ?? '10:00';
              final endT = item['end']?.toString() ?? '18:00';
              final timeStr = '$startT - $endT';

              events.putIfAbsent(dateOnly, () => []).add({
                'name': name,
                'time': timeStr,
                'exhibition': ex,
              });
            }
          } catch (_) {}
        }
        continue;
      }

      // 2. Fallback: Parse startDate and endDate
      final startStr = ex['startDate'];
      final endStr = ex['endDate'];
      if (startStr == null || endStr == null || startStr.toString().isEmpty)
        continue;

      try {
        final start = DateTime.parse(startStr.toString());
        final end = DateTime.parse(endStr.toString());

        String timeStr;
        if (start.hour == 0 &&
            start.minute == 0 &&
            end.hour == 0 &&
            end.minute == 0) {
          timeStr = '10:00 - 18:00';
        } else {
          timeStr =
              '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
        }

        for (var d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))) {
          final dateOnly = DateTime(d.year, d.month, d.day);
          events.putIfAbsent(dateOnly, () => []).add({
            'name': name,
            'time': timeStr,
            'exhibition': ex,
          });
        }
      } catch (_) {}
    }
    return events;
  }

  // ── Invite Dialog ──────────────────────────────────────────────
  void _showInviteDialog(Map<String, dynamic> artisan, bool isArabic) {
    final appState = context.read<AppState>();
    final userId = appState.userId;
    final isOwner = appState.isExhibitionOwner;

    // If the user is not an exhibition owner, show a prompt
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('يمكن لحاملي معارض فقط إرسال دعوات.',
                'Only exhibition owners can send invites.'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get my active/upcoming exhibitions (now using _ownerExhibitions)
    final myExhibitions = _getMyActiveExhibitions();

    String? selectedExhibitionId;
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedExhibition = selectedExhibitionId != null
              ? myExhibitions.firstWhere((e) => e['id'] == selectedExhibitionId)
              : null;

          return AlertDialog(
            backgroundColor: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.send, color: Color(0xFFD4A017)),
                const SizedBox(width: 8),
                Text(
                  t('دعوة الحرفي', 'Invite Craftsman'),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Artisan info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: accent.withValues(alpha: 0.2),
                            child: Text(
                              (isArabic
                                  ? (artisan['name'] ?? 'H')
                                  : (artisan['nameEn'] ??
                                      artisan['name'] ??
                                      'H'))[0],
                              style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic
                                      ? (artisan['name'] ?? '')
                                      : (artisan['nameEn'] ??
                                          artisan['name'] ??
                                          ''),
                                  style: GoogleFonts.cairo(
                                      color: text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  isArabic
                                      ? (artisan['craft'] ?? '')
                                      : (artisan['craftEn'] ??
                                          artisan['craft'] ??
                                          ''),
                                  style: GoogleFonts.cairo(
                                      color: dim, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t('اختر معرضك الذي تريد دعوته إليه:',
                          'Select your exhibition to invite them to:'),
                      style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingOwnerExhibitions)
                      const Center(child: CircularProgressIndicator())
                    else if (myExhibitions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.amber.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t('لا تملك معارض نشطة أو قادمة لإرسال دعوة.',
                                    'You don\'t have any active or upcoming exhibitions to invite to.'),
                                style: GoogleFonts.cairo(
                                    color: Colors.amber.shade700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...myExhibitions.map((ex) => RadioListTile<String>(
                            title: Text(
                                isArabic
                                    ? ex['name']
                                    : (ex['nameEn'] ?? ex['name']),
                                style: GoogleFonts.cairo(color: text)),
                            subtitle: Text(
                              t(
                                ex['status'] == 'active'
                                    ? 'جاري'
                                    : ex['status'] == 'upcoming'
                                        ? 'قادم'
                                        : ex['status'],
                                ex['status'],
                              ),
                              style: GoogleFonts.cairo(
                                color: ex['status'] == 'active'
                                    ? Colors.green
                                    : ex['status'] == 'upcoming'
                                        ? Colors.amber
                                        : Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            value: ex['id'],
                            groupValue: selectedExhibitionId,
                            onChanged: (value) => setDialogState(
                                () => selectedExhibitionId = value),
                            activeColor: accent,
                          )),
                    if (selectedExhibition != null) ...[
                      const Divider(color: Colors.transparent, height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('ملخص الدعوة', 'Invite Summary'),
                              style: GoogleFonts.cairo(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              icon: Icons.person_outline,
                              label: t('الحرفي', 'Artisan'),
                              value: isArabic
                                  ? (artisan['name'] ?? '')
                                  : (artisan['nameEn'] ??
                                      artisan['name'] ??
                                      ''),
                            ),
                            _infoRow(
                              icon: Icons.event_outlined,
                              label: t('المعرض', 'Exhibition'),
                              value: isArabic
                                  ? selectedExhibition['name']
                                  : (selectedExhibition['nameEn'] ??
                                      selectedExhibition['name']),
                            ),
                            _infoRow(
                              icon: Icons.info_outline,
                              label: t('الحالة', 'Status'),
                              value: t(
                                selectedExhibition['status'] == 'active'
                                    ? 'نشط'
                                    : selectedExhibition['status'] == 'upcoming'
                                        ? 'قادم'
                                        : selectedExhibition['status'] ?? '',
                                selectedExhibition['status'] ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 2,
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        hintText: t('رسالة شخصية (اختياري)',
                            'Personal message (optional)'),
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
              ),
              ElevatedButton(
                onPressed: selectedExhibitionId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final selected = myExhibitions
                            .firstWhere((e) => e['id'] == selectedExhibitionId);

                        try {
                          final response = await ApiService.post(
                            '/exhibitions/$selectedExhibitionId/invite/${artisan['id'] ?? artisan['userId']}',
                            body: {'message': messageController.text.trim()},
                          );
                          if (response.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t(
                                    '✅ تم إرسال الدعوة إلى ${isArabic ? artisan['name'] : (artisan['nameEn'] ?? artisan['name'])} للمشاركة في ${isArabic ? selected['name'] : (selected['nameEn'] ?? selected['name'])}!',
                                    '✅ Invite sent to ${isArabic ? artisan['name'] : (artisan['nameEn'] ?? artisan['name'])} for ${isArabic ? selected['name'] : (selected['nameEn'] ?? selected['name'])}!',
                                  ),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t('فشل إرسال الدعوة',
                                    'Failed to send invite')),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('حدث خطأ أثناء إرسال الدعوة',
                                  'Error sending invite')),
                              backgroundColor: Colors.redAccent,
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
                child: Text(t('إرسال الدعوة', 'Send Invite'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.cairo(color: dim, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                  color: text, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final filteredCrafts = _getFilteredCrafts(isArabic);

    List<String> availableCities = [];
    if (_selectedCountry != null && _selectedCountry!.isNotEmpty) {
      final raw = _citiesByCountry[_selectedCountry] ?? [];
      availableCities = [t('الكل', 'All'), ...raw];
    }

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            t('الحرفيون', 'Craftsmen'),
            style: GoogleFonts.cairo(
                color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Column(
          children: [
            // ── Main Search Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  hintText: t('ابحث عن حرفي بالاسم أو الحرفة أو المدينة...',
                      'Search by name, craft, or city...'),
                  hintStyle: TextStyle(color: dim),
                  prefixIcon: Icon(Icons.search, color: dim),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── Country & City Dropdowns ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedCountry,
                      items: _countries,
                      hint: t('الدولة', 'Country'),
                      onChanged: (value) {
                        setState(() {
                          _selectedCountry = value;
                          _selectedCity = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      value: _selectedCity,
                      items: availableCities,
                      hint: t('المدينة', 'City'),
                      onChanged: (value) =>
                          setState(() => _selectedCity = value),
                      enabled: _selectedCountry != null &&
                          _selectedCountry!.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Category Search ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (value) => setState(() => _categorySearch = value),
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  hintText: t('ابحث عن حرفة...', 'Search craft...'),
                  hintStyle: TextStyle(color: dim),
                  prefixIcon: Icon(Icons.search, color: dim),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),

            // ── Craft Filter Chips ──────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filteredCrafts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final label = filteredCrafts[i];
                  final isAllLabel = label == t('الكل', 'All') ||
                      label == 'الكل' ||
                      label == 'All';
                  final isSelected = (_selectedCraftFilter == label) ||
                      (isAllLabel &&
                          (_selectedCraftFilter == null ||
                              _selectedCraftFilter == t('الكل', 'All')));

                  return FilterChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.black : text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isAllLabel || _selectedCraftFilter == label) {
                          _selectedCraftFilter = null;
                        } else {
                          _selectedCraftFilter = label;
                        }
                      });
                    },
                    backgroundColor: surface,
                    selectedColor: accent,
                    side: BorderSide(
                      color: isSelected ? accent : border,
                      width: isSelected ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── Tabs: List / Calendar ──────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: t('قائمة الحرفيين', 'Craftsmen List'),
                      selected: _selectedTabIndex == 0,
                      onTap: () => setState(() => _selectedTabIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: t('التقويم', 'Calendar'),
                      selected: _selectedTabIndex == 1,
                      onTap: () => setState(() => _selectedTabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildCraftsmenList(isArabic),
                  _buildCalendarView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dropdown helper ──────────────────────────────────────────────
  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: dim, fontSize: 13)),
          icon: Icon(Icons.keyboard_arrow_down, color: enabled ? accent : dim),
          dropdownColor: surface,
          style: TextStyle(color: text, fontSize: 13),
          items: items
              .map((item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  // ── Tab button ──────────────────────────────────────────────────
  Widget _buildTabButton(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: selected ? Colors.black : dim,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Craftsmen List ──────────────────────────────────────────────
  Widget _buildCraftsmenList(bool isArabic) {
    final filtered = _getFilteredArtisans(isArabic);
    if (_isLoadingArtisans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: dim.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              t('لا توجد نتائج', 'No results found'),
              style: GoogleFonts.cairo(color: dim, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final artisan = filtered[index];
        final name = isArabic ? artisan['name'] : artisan['nameEn'];
        final craft = isArabic ? artisan['craft'] : artisan['craftEn'];
        final city = isArabic ? artisan['city'] : artisan['cityEn'];
        final rating = artisan['rating'] ?? 0.0;
        final completed = artisan['completedOrders'] ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CraftsmanPublicProfileScreen(
                  artisan: artisan,
                  isArabic: isArabic,
                  isDarkMode: context.watch<AppState>().isDarkMode,
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(
                    name[0],
                    style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      Text(
                        '$craft • $city',
                        style: GoogleFonts.cairo(color: dim, fontSize: 12),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.cairo(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$completed ${t('طلب', 'orders')}',
                            style: GoogleFonts.cairo(color: dim, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showInviteDialog(artisan, isArabic),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(t('دعوة', 'Invite')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Calendar View ────────────────────────────────────────────────
  Widget _buildCalendarView() {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;

    final firstDayOfMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday;
    final offset = startWeekday - 1;
    final monthName = DateFormat('MMMM yyyy').format(_calendarMonth);
    final weekDays = isArabic
        ? ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final eventMap = _buildEventMap();

    List<Widget> dayWidgets = [];
    for (int i = 0; i < offset; i++) {
      dayWidgets.add(Container());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
      final hasEvent = eventMap.containsKey(date);
      final isSelected = _selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day;
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              _selectedDayEvents = eventMap[date] ?? [];
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? accent
                  : (isToday
                      ? accent.withValues(alpha: 0.15)
                      : Colors.transparent),
              border: isToday ? Border.all(color: accent, width: 1.5) : null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected ? Colors.black : text,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (hasEvent)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.amber),
                    )
                  else
                    const SizedBox(height: 5),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Selected day events ────────────────────────────────────────
    Widget eventsWidget = const SizedBox.shrink();
    if (_selectedDate != null) {
      if (_selectedDayEvents.isNotEmpty) {
        eventsWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMM yyyy').format(_selectedDate!),
                style: TextStyle(color: text, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._selectedDayEvents.map((event) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event,
                            color: Color(0xFFD4A017), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['name'] ?? '',
                                style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                event['time'] ?? '',
                                style: TextStyle(color: dim, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExhibitionDetailScreen(
                                  exhibition: event['exhibition']
                                      as Map<String, dynamic>,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t('تفاصيل', 'Details'),
                              style: GoogleFonts.cairo(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      } else {
        eventsWidget = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              t('لا توجد فعاليات في هذا اليوم', 'No events on this day'),
              style: TextStyle(color: dim),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Calendar header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                  _selectedDate = null;
                  _selectedDayEvents = [];
                });
              },
            ),
            Text(
              monthName,
              style: TextStyle(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                  _selectedDate = null;
                  _selectedDayEvents = [];
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.2,
          children: weekDays
              .map((e) => Center(
                    child: Text(
                      e,
                      style: TextStyle(
                          color: dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.2,
          children: dayWidgets,
        ),
        const SizedBox(height: 16),
        eventsWidget,
        const SizedBox(height: 24),

        // ── Quick stats ────────────────────────────────────────────
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
                t('إحصائيات سريعة', 'Quick Stats'),
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    count: '${_artisans.length}',
                    label: t('إجمالي الحرفيين', 'Total Craftsmen'),
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    count:
                        '${_artisans.where((a) => a['isAvailable'] == true).length}',
                    label: t('متاحون', 'Available'),
                    color: Colors.green,
                  ),
                  _buildStatItem(
                    count: '${_getDistinctCrafts(isArabic).length - 1}',
                    label: t('الحرف', 'Crafts'),
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.cairo(
              color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(color: dim, fontSize: 11),
        ),
      ],
    );
  }

  // ── Calendar state ────────────────────────────────────────────────
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedDayEvents = [];
}
