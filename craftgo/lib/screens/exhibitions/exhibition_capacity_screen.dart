import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import 'craftsman_public_profile_screen.dart';

// ── Data Models for the UI ───────────────────────────────────────────
class ArtisanDayStatus {
  final String id; // artisan ID
  final String nameAr;
  final String nameEn;
  final String specialtyAr;
  final String specialtyEn;
  final String city;
  final double rating;
  final int commitmentScore;
  String boothId;
  bool isPresent;
  String? absenceReason;

  ArtisanDayStatus({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.specialtyAr,
    required this.specialtyEn,
    required this.city,
    required this.rating,
    required this.commitmentScore,
    required this.boothId,
    this.isPresent = true,
    this.absenceReason,
  });
}

class AbsenceAlert {
  final String craftsmanId;
  final String reason;
  final DateTime reportedAt;
  bool resolved;

  AbsenceAlert({
    required this.craftsmanId,
    required this.reason,
    required this.reportedAt,
    this.resolved = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────
class ExhibitionCapacityScreen extends StatefulWidget {
  final String exhibitionName;
  final int maxCapacity;
  final String? exhibitionId;

  const ExhibitionCapacityScreen({
    super.key,
    required this.exhibitionName,
    this.maxCapacity = 10,
    this.exhibitionId,
  });

  @override
  State<ExhibitionCapacityScreen> createState() =>
      _ExhibitionCapacityScreenState();
}

class _ExhibitionCapacityScreenState extends State<ExhibitionCapacityScreen> {
  // ── Per‑day data ──────────────────────────────────────────────────
  List<DateTime> _dates = [];
  List<ArtisanDayStatus> _confirmedArtisans = [];
  List<ArtisanDayStatus> _standbyArtisans = [];
  Map<String, Map<String, bool>> _attendanceMap = {};
  int _selectedDayIndex = 0;
  String? _selectedDateStr;

  // ── Dynamic Booth Storage ─────────────────────────────────────────
  List<String> _allBoothIds = [];

  // ── Legacy UI state (for tabs and alerts) ─────────────────────────
  int _tabIndex = 0;
  AbsenceAlert? _activeAlert;
  ArtisanDayStatus? _suggestedReplacement;

  bool _isLoading = true;
  String _error = '';

  // ── Theme ──────────────────────────────────────────────────────────
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
  Color get confirmedColor => const Color(0xFF66BB6A);
  Color get standbyColor => const Color(0xFFFFB74D);
  Color get absentColor => const Color(0xFFE57373);
  Color get availableColor => context.watch<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  Color get fullColor => const Color(0xFFE57373);

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data Loading ──────────────────────────────────────────────────
  Future<void> _loadData() async {
    final exhibId = widget.exhibitionId;
    if (exhibId == null || exhibId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No exhibition ID provided';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await ExhibitionsService.getExhibitionById(exhibId);
      if (data == null) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load exhibition data';
        });
        return;
      }

      // Dynamic booths based on rows and columns from DB
      final int rows = (data['boothRows'] ?? data['rows'] ?? 2) as int;
      final int cols = (data['boothColumns'] ?? data['columns'] ?? 5) as int;
      _allBoothIds = List.generate(rows * cols, (i) {
        final rowLetter = String.fromCharCode(65 + (i ~/ cols));
        final colNum = (i % cols) + 1;
        return '$rowLetter$colNum';
      });

      _dates = _extractDates(data);
      if (_dates.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No dates found for this exhibition';
        });
        return;
      }
      _selectedDateStr = DateFormat('yyyy-MM-dd').format(_dates.first);

      final attendanceRecords = await ExhibitionsService.getAttendance(exhibId);
      _attendanceMap = {};
      for (final record in attendanceRecords) {
        final artisanId = record['craftsmanId'];
        final date = record['date'];
        final isPresent = record['isPresent'] ?? true;
        if (artisanId != null && date != null) {
          _attendanceMap.putIfAbsent(artisanId, () => {});
          _attendanceMap[artisanId]![date] = isPresent;
        }
      }

      final registrations = (data['ExhibitionCraftsmen'] as List?) ?? [];
      final confirmedList = <ArtisanDayStatus>[];
      final standbyList = <ArtisanDayStatus>[];

      for (final ec in registrations) {
        final craftsman = ec['Craftsman'] as Map<String, dynamic>? ?? {};
        final status = (ec['status'] ?? '').toString();
        final artisanId = craftsman['id']?.toString() ?? '';
        final dateStr = _selectedDateStr!;
        final isPresent = _attendanceMap[artisanId]?[dateStr] ?? true;

        final artisan = ArtisanDayStatus(
          id: artisanId,
          nameAr: craftsman['name'] ?? 'حرفي',
          nameEn: craftsman['name'] ?? 'Craftsman',
          specialtyAr: ec['craftCategory'] ?? 'حرفة',
          specialtyEn: ec['craftCategory'] ?? 'Craft',
          city: craftsman['city'] ?? 'Palestine',
          rating: 4.5,
          commitmentScore: 85,
          boothId: ec['boothId'] ?? '',
          isPresent: isPresent,
        );

        if (status == 'confirmed') {
          confirmedList.add(artisan);
        } else if (status == 'standby') {
          standbyList.add(artisan);
        }
      }

      setState(() {
        _confirmedArtisans = confirmedList;
        _standbyArtisans = standbyList;
        _isLoading = false;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<DateTime> _extractDates(Map<String, dynamic> data) {
    List<DateTime> dates = [];
    final selectedDatesRaw = data['selectedDates'] ?? data['dates'];
    if (selectedDatesRaw is List && selectedDatesRaw.isNotEmpty) {
      for (var d in selectedDatesRaw) {
        if (d is Map && d['date'] != null) {
          final dt = DateTime.tryParse(d['date'].toString());
          if (dt != null) dates.add(DateTime(dt.year, dt.month, dt.day));
        }
      }
    } else if (data['startDate'] != null && data['endDate'] != null) {
      final start = DateTime.tryParse(data['startDate'].toString());
      final end = DateTime.tryParse(data['endDate'].toString());
      if (start != null && end != null) {
        for (var d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))) {
          dates.add(DateTime(d.year, d.month, d.day));
        }
      }
    }
    if (dates.isEmpty) dates = [DateTime.now()];
    return dates;
  }

  // ── Absence Reporting ──────────────────────────────────
  Future<void> _reportAbsence(ArtisanDayStatus artisan) async {
    final isArabic = context.read<AppState>().isArabic;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t('تأكيد الغياب', 'Confirm Absence'),
          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          t('هل أنت متأكد من أن ${isArabic ? artisan.nameAr : artisan.nameEn} غائب في هذا اليوم؟',
              'Are you sure that ${isArabic ? artisan.nameAr : artisan.nameEn} is absent on this day?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: absentColor,
              foregroundColor: Colors.white,
            ),
            child: Text(t('تأكيد الغياب', 'Confirm Absence')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final exhibId = widget.exhibitionId!;
    final dateStr = _selectedDateStr!;

    setState(() {
      artisan.isPresent = false;
      _attendanceMap.putIfAbsent(artisan.id, () => {})[dateStr] = false;
    });

    final success = await ExhibitionsService.updateAttendance(
      exhibitionId: exhibId,
      craftsmanId: artisan.id,
      date: dateStr,
      isPresent: false,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        artisan.isPresent = true;
        _attendanceMap[artisan.id]?[dateStr] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تحديث الحضور', 'Failed to update attendance')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_standbyArtisans.isNotEmpty) {
      _showPromotionDialog(artisan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم تسجيل الغياب', 'Absence recorded')),
          backgroundColor: confirmedColor,
        ),
      );
    }
  }

  // ── Undo Absence with Dynamic Booth Allocation ───────────────────────
  Future<void> _undoAbsence(ArtisanDayStatus artisan) async {
    final dateStr = _selectedDateStr!;

    // Find all occupied booths by active present artisans
    final occupiedBooths = _confirmedArtisans
        .where((a) => a.isPresent && a.id != artisan.id)
        .map((a) => a.boothId)
        .toSet();

    String targetBooth = artisan.boothId;
    bool boothReassigned = false;

    // Check if original booth was occupied while artisan was away
    if (targetBooth.isEmpty || occupiedBooths.contains(targetBooth)) {
      final availableBooths =
          _allBoothIds.where((b) => !occupiedBooths.contains(b)).toList();

      if (availableBooths.isNotEmpty) {
        targetBooth = availableBooths.first;
        boothReassigned = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('لا توجد أكشاك متاحة للإعادة',
                'No available booths left to allocate')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final success = await ExhibitionsService.updateAttendance(
      exhibitionId: widget.exhibitionId!,
      craftsmanId: artisan.id,
      date: dateStr,
      isPresent: true,
      boothId: targetBooth,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        artisan.isPresent = true;
        artisan.boothId = targetBooth;
        _attendanceMap.putIfAbsent(artisan.id, () => {})[dateStr] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            boothReassigned
                ? t('تم إلغاء الغياب وتم تعيين الكشك الجديد: $targetBooth',
                    'Absence undone. Allocated to next booth: $targetBooth')
                : t('تم إلغاء الغياب وعاد للكشك: $targetBooth',
                    'Absence undone. Returned to booth: $targetBooth'),
          ),
          backgroundColor: confirmedColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تحديث الحضور', 'Failed to update attendance')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Dynamic Standby Promotion ─────────────────────────────────────
  Future<void> _promoteStandby(ArtisanDayStatus standby) async {
    final usedBooths = _confirmedArtisans
        .where((a) => a.isPresent)
        .map((a) => a.boothId)
        .toSet();

    final availableBooths =
        _allBoothIds.where((b) => !usedBooths.contains(b)).toList();

    if (availableBooths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لا توجد أكشاك متاحة للترقية',
              'No available booths for promotion')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final availableBooth = availableBooths.first;
    final dateStr = _selectedDateStr!;

    final success = await ExhibitionsService.promoteStandby(
      exhibitionId: widget.exhibitionId!,
      standbyCraftsmanId: standby.id,
      boothId: availableBooth,
      date: dateStr,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        standby.isPresent = true;
        standby.boothId = availableBooth;
        _standbyArtisans.remove(standby);
        _confirmedArtisans.add(standby);
        _attendanceMap.putIfAbsent(standby.id, () => {})[dateStr] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: confirmedColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            '${t('تمت ترقية', 'Promoted')} ${context.read<AppState>().isArabic ? standby.nameAr : standby.nameEn} (${t('كشك', 'Booth')} $availableBooth)',
            style: GoogleFonts.cairo(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل ترقية الحرفي', 'Failed to promote craftsman')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPromotionDialog(ArtisanDayStatus absentArtisan) {
    final isArabic = context.read<AppState>().isArabic;
    final standbyList = _standbyArtisans;
    if (standbyList.isEmpty) return;

    final usedBooths = _confirmedArtisans
        .where((a) => a.isPresent)
        .map((a) => a.boothId)
        .toSet();

    final availableBooths =
        _allBoothIds.where((b) => !usedBooths.contains(b)).toList();

    ArtisanDayStatus? selectedStandby;
    String? selectedBoothId = availableBooths.contains(absentArtisan.boothId)
        ? absentArtisan.boothId
        : (availableBooths.isNotEmpty ? availableBooths.first : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              t('ترقية احتياطي', 'Promote Standby'),
              style:
                  GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('اختر حرفياً من قائمة الاحتياط ليحل محل الغائب',
                      'Select a standby artisan to replace the absent one.'),
                  style: TextStyle(color: dim, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Column(
                  children: standbyList
                      .map((s) => RadioListTile<ArtisanDayStatus>(
                            title: Text(isArabic ? s.nameAr : s.nameEn,
                                style: TextStyle(color: text)),
                            subtitle: Text(
                                isArabic ? s.specialtyAr : s.specialtyEn,
                                style: TextStyle(color: dim)),
                            value: s,
                            groupValue: selectedStandby,
                            onChanged: (value) =>
                                setDialogState(() => selectedStandby = value),
                            activeColor: accent,
                          ))
                      .toList(),
                ),
                if (availableBooths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBoothId,
                    decoration: InputDecoration(
                      labelText: t('اختر كشك', 'Select Booth'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: availableBooths
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, style: TextStyle(color: text)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedBoothId = value),
                    dropdownColor: surface,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
              ),
              ElevatedButton(
                onPressed: selectedStandby == null || selectedBoothId == null
                    ? null
                    : () async {
                        final standby = selectedStandby!;
                        Navigator.pop(ctx);
                        final booth = selectedBoothId!;
                        final dateStr = _selectedDateStr!;
                        final success = await ExhibitionsService.promoteStandby(
                          exhibitionId: widget.exhibitionId!,
                          standbyCraftsmanId: standby.id,
                          boothId: booth,
                          date: dateStr,
                        );
                        if (!mounted) return;
                        if (success) {
                          setState(() {
                            _standbyArtisans.remove(standby);
                            standby.isPresent = true;
                            standby.boothId = booth;
                            _confirmedArtisans.add(standby);
                            _attendanceMap.putIfAbsent(
                                standby.id, () => {})[dateStr] = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                t('تمت ترقية ${isArabic ? standby.nameAr : standby.nameEn}',
                                    'Promoted ${isArabic ? standby.nameAr : standby.nameEn}'),
                              ),
                              backgroundColor: confirmedColor,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(t('فشل الترقية', 'Promotion failed')),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
                child: Text(t('ترقية', 'Promote'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(),
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }
    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error, style: TextStyle(color: dim)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: Text(t('إعادة المحاولة', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final presentCount = _confirmedArtisans.where((a) => a.isPresent).length;
    final isFull = presentCount >= widget.maxCapacity;
    final fillPercent = presentCount / widget.maxCapacity;

    final dayTabs = Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final date = _dates[i];
          final isSelected = i == _selectedDayIndex;
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = i;
                _selectedDateStr = dateStr;
                for (final a in _confirmedArtisans) {
                  a.isPresent = _attendanceMap[a.id]?[dateStr] ?? true;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? accent : surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? accent : border),
              ),
              child: Text(
                DateFormat('EEE, d MMM').format(date),
                style: TextStyle(
                  color: isSelected ? Colors.black : text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildCapacityHeader(isFull, fillPercent, presentCount),
          dayTabs,
          _buildTabBar(),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildConfirmedList(),
                _buildStandbyList(),
                _buildAlertsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            widget.exhibitionName,
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            t('إدارة الطاقة الاستيعابية', 'Capacity Management'),
            style: GoogleFonts.cairo(color: dim, fontSize: 11),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  // ─── Capacity Header ─────────────────────────────────────────────
  Widget _buildCapacityHeader(
      bool isFull, double fillPercent, int presentCount) {
    final isDarkMode = context.watch<AppState>().isDarkMode;
    final gradientColors = isFull
        ? (isDarkMode
            ? [const Color(0xFF3E1E24), const Color(0xFF251216)]
            : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)])
        : (isDarkMode
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]);
    final activeColor = isFull ? fullColor : confirmedColor;
    final availableBoothsCount = widget.maxCapacity - presentCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFull
                          ? t('المعرض ممتلئ', 'Exhibition Full')
                          : t('أكشاك متاحة', 'Booths Available'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFull
                          ? t('التسجيل الجديد ← قائمة الاحتياط',
                              'New registrations → Standby')
                          : '$availableBoothsCount ${t('كشك متبقي', 'booths left')}',
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fillPercent.clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: availableColor,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$presentCount',
                          style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/${widget.maxCapacity}',
                          style: GoogleFonts.cairo(
                            color: dim,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSeatGrid(isFull, presentCount),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLegend(confirmedColor, t('مؤكد', 'Confirmed')),
              const SizedBox(width: 16),
              _buildLegend(standbyColor, t('احتياط', 'Standby')),
              const SizedBox(width: 16),
              _buildLegend(availableColor, t('متاح', 'Available')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatGrid(bool isFull, int presentCount) {
    final total = widget.maxCapacity + _standbyArtisans.length;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(total, (i) {
        Color color;
        if (i < presentCount) {
          color = isFull ? fullColor : confirmedColor;
        } else if (i < widget.maxCapacity) {
          color = availableColor;
        } else {
          color = standbyColor;
        }
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (i * 30)),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.cairo(color: dim, fontSize: 11),
        ),
      ],
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (
        Icons.verified_user_outlined,
        t('مؤكدون', 'Confirmed'),
        _confirmedArtisans.length,
        confirmedColor
      ),
      (
        Icons.hourglass_empty,
        t('احتياط', 'Standby'),
        _standbyArtisans.length,
        standbyColor
      ),
      (
        Icons.notifications_active_outlined,
        t('تنبيهات', 'Alerts'),
        _activeAlert != null ? 1 : 0,
        fullColor
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final selected = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? tab.$4.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: selected ? tab.$4 : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(tab.$1, color: selected ? tab.$4 : dim, size: 20),
                        if (tab.$3 > 0)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: tab.$4,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${tab.$3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.$2,
                      style: GoogleFonts.cairo(
                        color: selected ? text : dim,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Confirmed List ──────────────────────────────────────────────
  Widget _buildConfirmedList() {
    final absent = _confirmedArtisans.where((a) => !a.isPresent).toList();
    final present = _confirmedArtisans.where((a) => a.isPresent).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (absent.isNotEmpty) ...[
          _sectionHeader(
            Icons.warning_amber_rounded,
            t('غائبون (${absent.length})', 'Absent (${absent.length})'),
            fullColor,
          ),
          ...absent.map(
              (a) => _buildArtisanCard(a, isConfirmed: true, isAbsent: true)),
          const SizedBox(height: 12),
        ],
        _sectionHeader(
          Icons.check_circle_outline,
          t('مؤكدون (${present.length}/${widget.maxCapacity})',
              'Confirmed (${present.length}/${widget.maxCapacity})'),
          confirmedColor,
        ),
        ...present.map((a) => _buildArtisanCard(a, isConfirmed: true)),
      ],
    );
  }

  // ─── Standby List ─────────────────────────────────────────────────
  Widget _buildStandbyList() {
    if (_standbyArtisans.isEmpty) {
      return _emptyState(
        Icons.hourglass_empty,
        t('لا يوجد احتياط بعد', 'No standby yet'),
        t('يمكن للحرفيين التسجيل كاحتياط عندما يمتلئ المعرض',
            'Craftsmen can join standby when exhibition is full'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _standbyArtisans.asMap().entries.map((e) {
        final rank = e.key + 1;
        final artisan = e.value;
        return _buildStandbyCard(artisan, rank);
      }).toList(),
    );
  }

  // ─── Alerts Tab ───────────────────────────────────────────────────
  Widget _buildAlertsTab() {
    if (_activeAlert == null) {
      return _emptyState(
        Icons.notifications_none,
        t('لا يوجد تنبيهات', 'No alerts'),
        t('ستظهر هنا تنبيهات الغياب والاستبدال',
            'Absence and replacement alerts appear here'),
      );
    }
    final absent = _confirmedArtisans.firstWhere(
        (a) => a.id == _activeAlert!.craftsmanId,
        orElse: () => _confirmedArtisans.first);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _alertCard(absent),
        if (_suggestedReplacement != null) ...[
          const SizedBox(height: 12),
          _replacementSuggestionCard(_suggestedReplacement!, absent),
        ],
        const SizedBox(height: 16),
        _alertTimeline(),
      ],
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtisanCard(ArtisanDayStatus artisan,
      {required bool isConfirmed, bool isAbsent = false}) {
    final isPresent = artisan.isPresent;
    final color = isPresent ? confirmedColor : absentColor;

    return GestureDetector(
      onTap: () {
        final artisanMap = {
          'id': artisan.id,
          'name': artisan.nameAr,
          'nameEn': artisan.nameEn,
          'craft': artisan.specialtyAr,
          'craftEn': artisan.specialtyEn,
          'city': artisan.city,
          'cityEn': artisan.city,
          'rating': artisan.rating,
          'completedOrders': 20,
          'available': isPresent,
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CraftsmanPublicProfileScreen(
              artisan: artisanMap,
              isArabic: context.watch<AppState>().isArabic,
              isDarkMode: context.watch<AppState>().isDarkMode,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAbsent ? fullColor.withValues(alpha: 0.4) : border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text(
                (context.watch<AppState>().isArabic
                    ? artisan.nameAr
                    : artisan.nameEn)[0],
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.watch<AppState>().isArabic
                              ? artisan.nameAr
                              : artisan.nameEn,
                          style: GoogleFonts.cairo(
                            color: isAbsent ? fullColor : text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isAbsent || !isPresent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: fullColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t('غائب', 'Absent'),
                            style: TextStyle(color: fullColor, fontSize: 10),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '${t('كشك', 'Booth')} ${artisan.boothId}',
                        style: TextStyle(color: dim, fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.handyman_outlined, color: dim, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        context.watch<AppState>().isArabic
                            ? artisan.specialtyAr
                            : artisan.specialtyEn,
                        style: GoogleFonts.cairo(color: dim, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.location_on_outlined, color: dim, size: 12),
                      Text(artisan.city,
                          style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        artisan.rating.toStringAsFixed(1),
                        style: GoogleFonts.cairo(
                            color: Colors.amber, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t('الالتزام', 'Commitment'),
                                  style: GoogleFonts.cairo(
                                      color: dim, fontSize: 9),
                                ),
                                Text(
                                  '${artisan.commitmentScore}%',
                                  style: GoogleFonts.cairo(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: artisan.commitmentScore / 100,
                                minHeight: 4,
                                backgroundColor: color.withValues(alpha: 0.15),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isConfirmed && isPresent)
              IconButton(
                icon: Icon(Icons.person_remove_outlined,
                    color: fullColor, size: 18),
                tooltip: t('الإبلاغ عن غياب', 'Report absence'),
                onPressed: () => _reportAbsence(artisan),
              ),
            if (isConfirmed && !isPresent)
              IconButton(
                icon: Icon(Icons.undo, color: confirmedColor, size: 18),
                tooltip: t('إلغاء الغياب', 'Undo Absence'),
                onPressed: () => _undoAbsence(artisan),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandbyCard(ArtisanDayStatus artisan, int rank) {
    final isArabic = context.watch<AppState>().isArabic;
    return GestureDetector(
      onTap: () {
        final artisanMap = {
          'id': artisan.id,
          'name': artisan.nameAr,
          'nameEn': artisan.nameEn,
          'craft': artisan.specialtyAr,
          'craftEn': artisan.specialtyEn,
          'city': artisan.city,
          'cityEn': artisan.city,
          'rating': artisan.rating,
          'completedOrders': 20,
          'available': true,
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CraftsmanPublicProfileScreen(
              artisan: artisanMap,
              isArabic: isArabic,
              isDarkMode: context.watch<AppState>().isDarkMode,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rank == 1 ? standbyColor : border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rank == 1
                    ? standbyColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: rank == 1 ? standbyColor : border),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: GoogleFonts.cairo(
                    color: rank == 1 ? standbyColor : dim,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isArabic ? artisan.nameAr : artisan.nameEn,
                          style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (rank == 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: standbyColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t('الأول للاستدعاء', 'First to call'),
                            style: TextStyle(color: standbyColor, fontSize: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${isArabic ? artisan.specialtyAr : artisan.specialtyEn} • ${artisan.city} • 10 ${t('كم', 'km')}',
                    style: GoogleFonts.cairo(color: dim, fontSize: 11),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      Text(' ${artisan.rating}',
                          style: GoogleFonts.cairo(
                              color: Colors.amber, fontSize: 11)),
                      const SizedBox(width: 8),
                      Icon(Icons.history, color: dim, size: 12),
                      Text(' ${artisan.commitmentScore}%',
                          style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.phone_outlined,
                      color: confirmedColor, size: 18),
                  tooltip: t('اتصال', 'Call'),
                  onPressed: () => _showContactDialog(artisan),
                ),
                IconButton(
                  icon: Icon(Icons.upgrade, color: accent, size: 18),
                  tooltip: t('ترقية إلى مؤكد', 'Promote to confirmed'),
                  onPressed: () => _promoteStandby(artisan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Alerts and Dialogs ──────────────────────────────────────────────
  Widget _alertCard(ArtisanDayStatus absent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fullColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fullColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: fullColor, size: 20),
              const SizedBox(width: 8),
              Text(
                t('تنبيه غياب!', 'Absence Alert!'),
                style: GoogleFonts.cairo(
                  color: fullColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t(
              '${absent.nameAr} (${absent.specialtyAr}) أبلغ عن اعتذاره من المعرض.',
              '${absent.nameEn} (${absent.specialtyEn}) has reported inability to attend.',
            ),
            style: GoogleFonts.cairo(color: text, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            t('السبب: ${_activeAlert?.reason ?? ''}',
                'Reason: ${_activeAlert?.reason ?? ''}'),
            style: GoogleFonts.cairo(color: dim, fontSize: 12),
          ),
          Text(
            '${t("التوقيت:", "Reported:")} ${DateFormat('HH:mm').format(_activeAlert?.reportedAt ?? DateTime.now())}',
            style: GoogleFonts.cairo(color: dim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _replacementSuggestionCard(
      ArtisanDayStatus suggested, ArtisanDayStatus absent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.1),
            accent.withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                t('ترشيح للاستبدال', 'Replacement Suggestion'),
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'الأنسب للاستبدال: ${suggested.nameAr} (${suggested.specialtyAr}) - تقييم ${suggested.rating} - التزام ${suggested.commitmentScore}% - 10 كم.',
              'Best match: ${suggested.nameEn} (${suggested.specialtyEn}) — rating ${suggested.rating}, commitment ${suggested.commitmentScore}%, 10 km.',
            ),
            style: GoogleFonts.cairo(color: text, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showContactDialog(suggested),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.send, size: 14),
                  label: Text(t('إرسال دعوة', 'Send Invite'),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _promoteStandby(suggested),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.upgrade, size: 14),
                  label: Text(t('ترقية مباشرة', 'Promote Now'),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertTimeline() {
    final hour = _activeAlert?.reportedAt.hour ?? 0;
    final min = _activeAlert?.reportedAt.minute ?? 0;
    final events = [
      (
        Icons.person_remove,
        fullColor,
        t('تم الإبلاغ عن الغياب', 'Absence reported'),
        '$hour:$min',
        true
      ),
      (
        Icons.lightbulb_outline,
        accent,
        t('تم اختيار بديل', 'Replacement selected'),
        t('الآن', 'Now'),
        true
      ),
      (
        Icons.send,
        Colors.blueAccent,
        t('في انتظار الرد من الاحتياط', 'Waiting for standby response'),
        t('قيد الانتظار...', 'Pending...'),
        false
      ),
      (
        Icons.check_circle_outline,
        confirmedColor,
        t('تأكيد الحرفي الجديد', 'New craftsman confirmed'),
        t('قريباً', 'Soon'),
        false
      ),
    ];
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
          Text(
            t('خط سير الاستبدال', 'Replacement Timeline'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final ev = entry.value;
            final isLast = i == events.length - 1;
            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ev.$2.withValues(alpha: ev.$5 ? 0.2 : 0.05),
                          border: Border.all(
                              color:
                                  ev.$2.withValues(alpha: ev.$5 ? 0.8 : 0.3)),
                        ),
                        child: Icon(ev.$1, color: ev.$2, size: 16),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 30,
                          color: i == 0 ? ev.$2.withValues(alpha: 0.5) : border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.$3,
                            style: GoogleFonts.cairo(
                              color: ev.$5 ? text : dim,
                              fontWeight:
                                  ev.$5 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          Text(ev.$4,
                              style:
                                  GoogleFonts.cairo(color: dim, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: dim.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: dim,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(ArtisanDayStatus artisan) {
    final isArabic = context.watch<AppState>().isArabic;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t('التواصل مع الحرفي', 'Contact Craftsman'),
          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? artisan.nameAr : artisan.nameEn,
              style: GoogleFonts.cairo(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text('+970599000000', style: GoogleFonts.cairo(color: dim)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                t(
                  'رسالة AI:\n\nمرحباً ${isArabic ? artisan.nameAr : artisan.nameEn}! تخصصك في ${isArabic ? artisan.specialtyAr : artisan.specialtyEn} مطلوب في ${widget.exhibitionName}. أحد الحرفيين المؤكدين اعتذر. هل يمكنك الحضور؟',
                  'AI Message:\n\nHello ${isArabic ? artisan.nameAr : artisan.nameEn}! Your ${isArabic ? artisan.specialtyAr : artisan.specialtyEn} expertise is needed at ${widget.exhibitionName}. A confirmed craftsman has cancelled. Can you attend?',
                ),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: confirmedColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  content: Text(
                    t('تم إرسال الدعوة!', 'Invite sent!'),
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('إرسال', 'Send'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
