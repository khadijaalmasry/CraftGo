import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';

class CommunityExhibitionsScreen extends StatefulWidget {
  const CommunityExhibitionsScreen({super.key});

  @override
  State<CommunityExhibitionsScreen> createState() =>
      _CommunityExhibitionsScreenState();
}

class _CommunityExhibitionsScreenState extends State<CommunityExhibitionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoading = true;
  String _error = '';

  // ── Theme helpers ────────────────────────────────────────────────
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

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExhibitions();
  }

  // ── Robust date parser (Timezone-safe) ──────────────────────────────────────────────
  static DateTime? _parseFlexibleDate(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    final str = input.toString().trim();
    if (str.isEmpty) return null;

    try {
      // Clean time/timezone string to prevent local timezone shifts
      final dateOnly = str.contains('T') ? str.split('T')[0] : str;
      final parts = dateOnly.split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return DateTime.parse(dateOnly);
    } catch (_) {}

    try {
      if (str.contains('/')) {
        final parts = str.split('/');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return DateTime(
                int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            return DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } else if (str.contains('-')) {
        final parts = str.split('-');
        if (parts.length == 3 && parts[0].length != 4) {
          return DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}

    return null;
  }

  // ── Status determiner ──────────────────────────────────────────────
  static String _determineStatus(
      dynamic backendStatus, DateTime? start, DateTime? end) {
    if (backendStatus != null && backendStatus.toString().isNotEmpty) {
      final bs = backendStatus.toString().trim().toLowerCase();
      if (bs == 'active' || bs == 'نشط' || bs == 'ongoing') return 'Active';
      if (bs == 'upcoming' || bs == 'قادم' || bs == 'future') return 'Upcoming';
      if (bs == 'past' || bs == 'منتهي' || bs == 'completed' || bs == 'ended') {
        return 'Past';
      }
    }

    if (start != null && end != null) {
      final now = DateTime.now();
      final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      if (now.isAfter(endOfDay)) return 'Past';
      if (now.isBefore(startOfDay)) return 'Upcoming';
      return 'Active';
    } else if (start != null) {
      final now = DateTime.now();
      final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
      if (now.isBefore(startOfDay)) return 'Upcoming';
      return 'Active';
    }
    return 'Upcoming';
  }

  // ── Soft pastel gradient generator ────────────────────────────────
  List<Color> _getPastelGradient(int index) {
    const pastelPalettes = [
      [Color(0xFFB8C0FF), Color(0xFFC8B6FF)],
      [Color(0xFFFFCAD4), Color(0xFFF4ACB7)],
      [Color(0xFFD8E2DC), Color(0xFFFFE5D9)],
      [Color(0xFFE2ECE9), Color(0xFFBEE1E6)],
      [Color(0xFFFDE2E4), Color(0xFFFFF1E6)],
      [Color(0xFFEEDC9A), Color(0xFFE4C560)],
    ];
    return pastelPalettes[index % pastelPalettes.length];
  }

  // ── Load exhibitions ────────────────────────────────────────────────
  Future<void> _loadExhibitions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await ExhibitionsService.getAllExhibitions();
      if (data.isNotEmpty) {
        int index = 0;
        final mapped = data.map<Map<String, dynamic>>((item) {
          // ── 1. Parse raw dates matching ExhibitionDetailScreen ──────
          final rawStart =
              (item['startDate'] ?? item['start_date'] ?? item['start'] ?? '')
                  .toString();
          final rawEnd =
              (item['endDate'] ?? item['end_date'] ?? item['end'] ?? '')
                  .toString();

          final startDt = _parseFlexibleDate(rawStart);
          final endDt = _parseFlexibleDate(rawEnd);

          // ── 2. Parse selectedDates if explicitly provided ────────────
          List<DateTime> parsedSelectedDates = [];
          final selectedDatesRaw = item['selectedDates'] ??
              item['selected_dates'] ??
              item['dates'] ??
              item['dateList'] ??
              [];

          if (selectedDatesRaw is List && selectedDatesRaw.isNotEmpty) {
            for (final d in selectedDatesRaw) {
              final parsed = _parseFlexibleDate(d);
              if (parsed != null) {
                parsedSelectedDates.add(parsed);
              }
            }
            parsedSelectedDates.sort((a, b) => a.compareTo(b));
          }

          // ── 3. Clean date strings for display ────────────────────────
          String startDateStr =
              rawStart.contains('T') ? rawStart.split('T')[0] : rawStart;
          if (startDateStr.isEmpty && startDt != null) {
            startDateStr =
                '${startDt.year}-${startDt.month.toString().padLeft(2, '0')}-${startDt.day.toString().padLeft(2, '0')}';
          }

          String endDateStr =
              rawEnd.contains('T') ? rawEnd.split('T')[0] : rawEnd;
          if (endDateStr.isEmpty && endDt != null) {
            endDateStr =
                '${endDt.year}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}';
          }

          // ── 4. Determine status ────────────────────────────────────
          final rawStatus = item['status'] ?? item['state'];
          String status = _determineStatus(rawStatus, startDt, endDt);

          // ── 5. Parse participants matching ExhibitionDetailScreen ──
          final craftsmenRaw = item['ExhibitionCraftsmen'] ??
              item['exhibitionCraftsmen'] ??
              item['exhibition_craftsmen'] ??
              item['craftsmen'] ??
              item['Craftsmen'] ??
              item['artisans'] ??
              [];

          final craftsmenList = (craftsmenRaw is List) ? craftsmenRaw : [];

          final participants = craftsmenList
              .where((ec) {
                if (ec is! Map) return false;
                // Only include confirmed registrations (matching ExhibitionDetailScreen)
                final st =
                    (ec['status'] ?? 'confirmed').toString().toLowerCase();
                return st == 'confirmed' ||
                    st == 'accepted' ||
                    st == 'approved';
              })
              .map((ec) {
                final ecMap = Map<String, dynamic>.from(ec as Map);
                final cRaw = ecMap['Craftsman'] ??
                    ecMap['craftsman'] ??
                    ecMap['User'] ??
                    ecMap['user'] ??
                    ecMap;
                final c =
                    (cRaw is Map) ? Map<String, dynamic>.from(cRaw) : ecMap;

                final name = c['name'] ??
                    c['fullName'] ??
                    c['full_name'] ??
                    ecMap['name'] ??
                    '';
                final nameEn = c['nameEn'] ??
                    c['name_en'] ??
                    c['englishName'] ??
                    c['english_name'] ??
                    name;

                final craft = ecMap['craftCategory'] ??
                    ecMap['craft_category'] ??
                    ecMap['craft'] ??
                    c['craftCategory'] ??
                    c['craft_category'] ??
                    c['craft'] ??
                    '';
                final craftEn = ecMap['craftCategoryEn'] ??
                    ecMap['craft_category_en'] ??
                    ecMap['craftEn'] ??
                    c['craftCategoryEn'] ??
                    craft;

                final boothId = ecMap['boothId'] ??
                    ecMap['booth_id'] ??
                    ecMap['boothNumber'] ??
                    c['boothId'] ??
                    '';

                return {
                  'id': c['id']?.toString() ?? ecMap['id']?.toString() ?? '',
                  'boothId': boothId.toString(),
                  'name': name.toString(),
                  'nameEn': nameEn.toString(),
                  'craft': craft.toString(),
                  'craftEn': craftEn.toString(),
                };
              })
              .where((p) => (p['name'] as String).isNotEmpty)
              .toList();

          // ── 6. Gradient ─────────────────────────────────────────────
          List<Color> gradientColors = _getPastelGradient(index++);
          if (item['gradient'] != null &&
              item['gradient'] is List &&
              (item['gradient'] as List).isNotEmpty) {
            try {
              gradientColors = (item['gradient'] as List).map((c) {
                if (c is Color) return c;
                final hex = c.toString().replaceAll('#', '');
                return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex));
              }).toList();
            } catch (_) {}
          }

          // ── 7. Schedule ─────────────────────────────────────────────
          final scheduleRaw = item['schedules'] ??
              item['Schedules'] ??
              item['schedule'] ??
              item['Schedule'] ??
              [];
          final scheduleList = (scheduleRaw is List) ? scheduleRaw : [];

          // ── 8. Image URL ────────────────────────────────────────────
          final imageUrl = item['bannerUrl'] ??
              item['imageUrl'] ??
              item['banner'] ??
              item['image'] ??
              item['coverImage'] ??
              '';

          // ── 9. Build final map ─────────────────────────────────────
          return {
            'id': item['id']?.toString() ?? '',
            'name': item['name'] ?? '',
            'nameEn': item['nameEn'] ?? item['name'] ?? '',
            'location': item['location'] ?? '',
            'locationEn': item['locationEn'] ?? item['location'] ?? '',
            'startDate': startDateStr,
            'endDate': endDateStr,
            'selectedDates': parsedSelectedDates,
            'status': status,
            'type': item['type'] ?? item['visibility'] ?? 'Public',
            'description': item['description'] ?? '',
            'descriptionEn': item['descriptionEn'] ?? item['description'] ?? '',
            'maxCapacity': item['capacity'] ??
                item['maxCapacity'] ??
                item['max_capacity'] ??
                20,
            'interested': item['interestedCount'] ??
                item['interested_count'] ??
                item['interested'] ??
                ((item['UserInteractions'] is List)
                    ? (item['UserInteractions'] as List).length
                    : 0),
            'boothRows': item['boothRows'] ?? item['rows'] ?? 3,
            'boothColumns': item['boothColumns'] ?? item['cols'] ?? 4,
            'gradient': gradientColors,
            'imageUrl': imageUrl,
            'schedule': scheduleList,
            'participants': participants,
          };
        }).toList();
        setState(() => _exhibitions = mapped);
      } else {
        setState(() => _exhibitions = []);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Upcoming':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Active':
        return t('نشط', 'Active');
      case 'Upcoming':
        return t('قادم', 'Upcoming');
      default:
        return t('منتهي', 'Past');
    }
  }

  String _formatDate(String iso) {
    final parsed = _parseFlexibleDate(iso);
    if (parsed != null) {
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    return iso;
  }

  List<Map<String, dynamic>> _filterByTab(
      List<Map<String, dynamic>> all, int idx) {
    final statuses = [
      ['Active'],
      ['Upcoming'],
      ['Past']
    ];
    final query = _search.toLowerCase().trim();
    return all
        .where((e) =>
            statuses[idx].contains(e['status'] ?? '') &&
            ((e['name'] ?? '').toLowerCase().contains(query) ||
                (e['nameEn'] ?? '').toLowerCase().contains(query) ||
                (e['location'] ?? '').toLowerCase().contains(query)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final bg = isDark ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDark ? const Color(0xFF1C2431) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dim = isDark ? Colors.white54 : Colors.black45;
    final accent = const Color(0xFFD4A017);

    final heroColors = isDark
        ? [const Color(0xFF0D1B33), const Color(0xFF0D1420)]
        : [Colors.white, const Color(0xFFF8FAFC)];
    final heroTextColor = isDark ? Colors.white : Colors.black87;
    final heroSubtextColor = isDark ? Colors.white54 : Colors.black54;
    final heroSearchBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final heroSearchBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Directionality(
      textDirection: appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                child: Column(
                  children: [
                    // ── Hero banner ──────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: heroColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: isDesktop
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(24))
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.explore,
                                        color: Color(0xFFD4A017), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('مجتمع المعارض',
                                            'Exhibition Community'),
                                        style: GoogleFonts.cairo(
                                          color: heroTextColor,
                                          fontSize: isDesktop ? 24 : 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        t('اكتشف، شارك، وتواصل',
                                            'Discover - Connect - Attend'),
                                        style: GoogleFonts.cairo(
                                          color: heroSubtextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  color: heroSearchBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: heroSearchBorder),
                                ),
                                child: TextField(
                                  style: TextStyle(color: heroTextColor),
                                  decoration: InputDecoration(
                                    hintText: t('ابحث عن معرض...',
                                        'Search exhibitions...'),
                                    hintStyle: TextStyle(
                                      color: heroSubtextColor,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: heroSubtextColor,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (v) => setState(() => _search = v),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TabBar(
                                controller: _tabController,
                                indicatorColor: accent,
                                indicatorWeight: 3,
                                labelColor: accent,
                                unselectedLabelColor: heroSubtextColor,
                                labelStyle: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                unselectedLabelStyle:
                                    GoogleFonts.cairo(fontSize: 13),
                                tabs: [
                                  Tab(text: t('نشطة', 'Active')),
                                  Tab(text: t('قادمة', 'Upcoming')),
                                  Tab(text: t('منتهية', 'Past')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Body ─────────────────────────────────────────────────────
                    Expanded(
                      child: Container(
                        color: bg,
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(color: accent))
                            : _error.isNotEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.error_outline,
                                            size: 48, color: Colors.red),
                                        const SizedBox(height: 12),
                                        Text(
                                          t('حدث خطأ', 'Something went wrong'),
                                          style: GoogleFonts.cairo(
                                              color: textColor, fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _error,
                                          style: GoogleFonts.cairo(
                                              color: dim, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _loadExhibitions,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: Text(
                                              t('إعادة المحاولة', 'Retry')),
                                        ),
                                      ],
                                    ),
                                  )
                                : TabBarView(
                                    controller: _tabController,
                                    children: List.generate(3, (tabIdx) {
                                      final items =
                                          _filterByTab(_exhibitions, tabIdx);
                                      if (items.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.event_busy,
                                                  size: 60, color: dim),
                                              const SizedBox(height: 12),
                                              Text(
                                                t('لا توجد معارض حالياً',
                                                    'No exhibitions right now'),
                                                style: GoogleFonts.cairo(
                                                    color: dim, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return isDesktop
                                          ? GridView.builder(
                                              padding: const EdgeInsets.all(20),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 20,
                                                mainAxisSpacing: 20,
                                                childAspectRatio: 0.85,
                                              ),
                                              itemCount: items.length,
                                              itemBuilder: (context, i) =>
                                                  _ExhibitionCommunityCard(
                                                exhibition: items[i],
                                                appState: appState,
                                                surface: surface,
                                                textColor: textColor,
                                                dim: dim,
                                                border: border,
                                                accent: accent,
                                                statusColor: _statusColor(
                                                    items[i]['status'] ?? ''),
                                                statusLabel: _statusLabel(
                                                    items[i]['status'] ?? ''),
                                                formatDate: _formatDate,
                                              ),
                                            )
                                          : ListView.builder(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      16, 16, 16, 24),
                                              itemCount: items.length,
                                              itemBuilder: (context, i) =>
                                                  _ExhibitionCommunityCard(
                                                exhibition: items[i],
                                                appState: appState,
                                                surface: surface,
                                                textColor: textColor,
                                                dim: dim,
                                                border: border,
                                                accent: accent,
                                                statusColor: _statusColor(
                                                    items[i]['status'] ?? ''),
                                                statusLabel: _statusLabel(
                                                    items[i]['status'] ?? ''),
                                                formatDate: _formatDate,
                                              ),
                                            );
                                    }),
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
}

// ─── Community Card ──────────────────────────────────────────────────
class _ExhibitionCommunityCard extends StatefulWidget {
  final Map<String, dynamic> exhibition;
  final AppState appState;
  final Color surface;
  final Color textColor;
  final Color dim;
  final Color border;
  final Color accent;
  final Color statusColor;
  final String statusLabel;
  final String Function(String) formatDate;

  const _ExhibitionCommunityCard({
    required this.exhibition,
    required this.appState,
    required this.surface,
    required this.textColor,
    required this.dim,
    required this.border,
    required this.accent,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDate,
  });

  @override
  State<_ExhibitionCommunityCard> createState() =>
      _ExhibitionCommunityCardState();
}

class _ExhibitionCommunityCardState extends State<_ExhibitionCommunityCard> {
  bool _expanded = false;

  String t(String ar, String en) => widget.appState.isArabic ? ar : en;

  // ─── Mini Calendar ──────────────────────────────────────────────────
  Widget _buildMiniCalendar(
      DateTime start, DateTime end, List<DateTime> selectedDates) {
    final accent = widget.accent;
    final dim = widget.dim;
    final textColor = widget.textColor;
    final now = DateTime.now();

    // Determine which month to display
    final bool isOngoing =
        now.isAfter(start.subtract(const Duration(days: 1))) &&
            now.isBefore(end.add(const Duration(days: 1)));
    final display = isOngoing ? now : start;
    final firstDayOfMonth = DateTime(display.year, display.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(display.year, display.month);
    final startWeekday = firstDayOfMonth.weekday % 7;

    final monthNames = widget.appState.isArabic
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر'
          ]
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];

    final dayHeaders = widget.appState.isArabic
        ? ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب']
        : ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month,
                color: Color(0xFFD4A017), size: 16),
            const SizedBox(width: 6),
            Text(
              '${monthNames[display.month - 1]} ${display.year}',
              style: GoogleFonts.cairo(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.formatDate(start.toIso8601String().split('T')[0])} → ${widget.formatDate(end.toIso8601String().split('T')[0])}',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayHeaders
              .map((d) => SizedBox(
                    width: 28,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: dim, fontSize: 10),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, idx) {
            if (idx < startWeekday) return const SizedBox();
            final day = idx - startWeekday + 1;
            final date = DateTime(display.year, display.month, day);

            final inRange = selectedDates.isNotEmpty
                ? selectedDates.any((d) => DateUtils.isSameDay(d, date))
                : (!date.isBefore(start) && !date.isAfter(end));
            final isToday = DateUtils.isSameDay(date, now);

            Color? bgCol;
            Color textCol = textColor;
            if (inRange) {
              bgCol = accent.withValues(alpha: 0.25);
              textCol = accent;
            }
            if (isToday) {
              bgCol = accent;
              textCol = Colors.black;
            }

            return Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: bgCol,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: textCol,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Booth Distribution ─────────────────────────────────────────────
  Widget _buildBoothDistribution(
      List<dynamic> participants, int rows, int cols) {
    final accent = widget.accent;
    final textColor = widget.textColor;
    final dim = widget.dim;
    final surface = widget.surface;
    final border = widget.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('توزيع الأكشاك', 'Booth Distribution'),
          style: GoogleFonts.cairo(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: rows * cols,
          itemBuilder: (context, index) {
            final participant =
                participants.length > index ? participants[index] : null;
            final isOccupied = participant != null &&
                (participant['name'] ?? '').toString().isNotEmpty;
            final boothId = participant != null &&
                    (participant['boothId'] ?? '').toString().isNotEmpty
                ? participant['boothId']
                : '${String.fromCharCode(65 + (index ~/ cols))}${(index % cols) + 1}';

            return Container(
              decoration: BoxDecoration(
                color: isOccupied ? accent.withValues(alpha: 0.1) : surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOccupied ? accent : border,
                  width: isOccupied ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    boothId,
                    style: TextStyle(
                      color: isOccupied ? accent : dim,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (isOccupied) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.appState.isArabic
                          ? participant['name']
                          : participant['nameEn'],
                      style: TextStyle(
                        color: textColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                  if (!isOccupied)
                    Text(
                      t('متاح', 'Available'),
                      style: TextStyle(
                        color: dim,
                        fontSize: 8,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _legendItem(accent, t('محجوز', 'Taken')),
            _legendItem(Colors.transparent, t('متاح', 'Available')),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    final isDark = widget.appState.isDarkMode;
    final surface = isDark ? const Color(0xFF1C2431) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final dim = widget.dim;

    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color == Colors.transparent ? surface : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: dim,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // ─── Daily Schedule ──────────────────────────────────────────────────
  Widget _buildDailySchedule(List<dynamic> schedule) {
    final textColor = widget.textColor;
    final dim = widget.dim;
    final accent = widget.accent;

    if (schedule.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('الجدول اليومي', 'Daily Schedule'),
          style: GoogleFonts.cairo(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...schedule.map((item) {
          final day = (item['day'] ?? item['date'] ?? '').toString();
          final start = (item['startTime'] ?? item['start'] ?? '').toString();
          final end = (item['endTime'] ?? item['end'] ?? '').toString();
          final formattedDay = widget.formatDate(day);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDay,
                  style: GoogleFonts.cairo(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      start,
                      style: GoogleFonts.cairo(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' - ',
                      style: TextStyle(color: dim, fontSize: 12),
                    ),
                    Text(
                      end,
                      style: GoogleFonts.cairo(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exhibition;
    final accent = widget.accent;
    final isDark = widget.appState.isDarkMode;
    final border = widget.border;

    final gradientColors = (e['gradient'] as List?)?.map((c) {
          if (c is Color) return c;
          if (c is int) return Color(c);
          return const Color(0xFFD4A017);
        }).toList() ??
        [const Color(0xFFB8C0FF), const Color(0xFFC8B6FF)];

    final imageUrl = (e['imageUrl'] ?? '').toString();
    final name = widget.appState.isArabic
        ? (e['name'] ?? '')
        : (e['nameEn'] ?? e['name'] ?? '');
    final location = widget.appState.isArabic
        ? (e['location'] ?? '')
        : (e['locationEn'] ?? e['location'] ?? '');
    final description = widget.appState.isArabic
        ? (e['description'] ?? '')
        : (e['descriptionEn'] ?? e['description'] ?? '');
    final startDate = e['startDate'] ?? '';
    final endDate = e['endDate'] ?? '';
    final List<DateTime> selectedDates =
        (e['selectedDates'] as List?)?.cast<DateTime>() ?? [];

    final interested = e['interested'] ?? 0;
    final capacity = e['maxCapacity'] ?? 0;
    final type = e['type'] ?? 'Public';
    final schedule = e['schedule'] ?? [];
    final participants = e['participants'] ?? [];
    final boothRows = e['boothRows'] ?? 3;
    final boothCols = e['boothColumns'] ?? 4;

    DateTime? dtStart =
        _CommunityExhibitionsScreenState._parseFlexibleDate(startDate) ??
            (selectedDates.isNotEmpty ? selectedDates.first : null);
    DateTime? dtEnd =
        _CommunityExhibitionsScreenState._parseFlexibleDate(endDate) ??
            (selectedDates.isNotEmpty ? selectedDates.last : null);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: widget.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner ────────────────────────────────────────────────
            Container(
              height: 95,
              decoration: BoxDecoration(
                gradient: imageUrl.isEmpty
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                const Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                location,
                                style: GoogleFonts.cairo(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.statusColor.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.statusColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            widget.statusLabel,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            type == 'Public'
                                ? t('عام', 'Public')
                                : t('خاص', 'Private'),
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick info row ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _chip(
                    Icons.calendar_today,
                    '${widget.formatDate(startDate)} → ${widget.formatDate(endDate)}',
                    widget.dim,
                  ),
                  _chip(
                    Icons.favorite,
                    '$interested',
                    const Color(0xFFE74C3C),
                  ),
                  _chip(
                    Icons.groups,
                    '${participants.length}/${capacity > 0 ? capacity : "∞"}',
                    accent,
                  ),
                ],
              ),
            ),

            // ── Attending Artisans ──────────────────────────────────
            if (participants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Text(
                      t('الحرفيون المشاركون:', 'Participating Artisans:'),
                      style: GoogleFonts.cairo(
                        color: widget.dim,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...participants.take(5).map((p) => Tooltip(
                          message: widget.appState.isArabic
                              ? p['name']
                              : p['nameEn'],
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                (widget.appState.isArabic
                                    ? p['name']
                                    : p['nameEn'])[0],
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )),
                    if (participants.length > 5)
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '+${participants.length - 5}',
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // ── Expand toggle ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded
                          ? t('إخفاء التفاصيل', 'Hide Details')
                          : t('عرض التفاصيل', 'Show Details'),
                      style: GoogleFonts.cairo(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: accent,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded panel ──────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: GoogleFonts.cairo(
                          color: widget.dim,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (dtStart != null && dtEnd != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child:
                            _buildMiniCalendar(dtStart, dtEnd, selectedDates),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // ── Booth Distribution ─────────────────────────
                    _buildBoothDistribution(participants, boothRows, boothCols),
                    const SizedBox(height: 16),
                    // ── Daily Schedule ─────────────────────────────
                    if (schedule.isNotEmpty) ...[
                      _buildDailySchedule(schedule),
                      const SizedBox(height: 16),
                    ],
                    // ── Full Participants List ─────────────────────
                    Text(
                      t('قائمة الحرفيين المشاركين',
                          'Participating Artisans List'),
                      style: GoogleFonts.cairo(
                        color: widget.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (participants.isEmpty)
                      Text(
                        t('لا يوجد حرفيون مشاركون حتى الآن',
                            'No participating artisans yet'),
                        style: GoogleFonts.cairo(
                          color: widget.dim,
                          fontSize: 13,
                        ),
                      )
                    else
                      ...participants.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (widget.appState.isArabic
                                        ? p['name']
                                        : p['nameEn'])[0],
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.appState.isArabic
                                      ? p['name']
                                      : p['nameEn'],
                                  style: GoogleFonts.cairo(
                                    color: widget.textColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if ((p['craft'] ?? '').toString().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.appState.isArabic
                                        ? p['craft']
                                        : p['craftEn'],
                                    style: GoogleFonts.cairo(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if ((p['boothId'] ?? '').toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    t('كشك', 'Booth') + ' ${p['boothId']}',
                                    style: GoogleFonts.cairo(
                                      color: widget.dim,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.cairo(color: color, fontSize: 11),
        ),
      ],
    );
  }
}
