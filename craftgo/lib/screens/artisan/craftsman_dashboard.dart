import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:provider/provider.dart';
import 'exhibition_registration_screen.dart';
import '../exhibitions/explore_exhibitions_screen.dart';
import 'craftsman_exhibitions_screen.dart';
import 'package:craftgo/services/exhibitions_service.dart';
import '../../services/api_service.dart';
import '../../services/story_service.dart';
import '../../widgets/location_picker_screen.dart';
import '../../app_state.dart';
import 'craftsman_exhibition_detail_screen.dart';
import 'craftsman_stories_screen.dart';
import '../custom_order/custom_order_provider.dart';
import '../hire_order/hire_order_provider.dart';
import '../../services/notification_service.dart';

class CraftsmanDashboard extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final String categoryTitleAr;
  final String categoryTitleEn;
  final String name;
  final String city;
  final String experience;
  final String bio;
  final bool isVerified;
  final bool isPending;
  final String craftsmanId;

  const CraftsmanDashboard({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.categoryTitleAr,
    required this.categoryTitleEn,
    required this.name,
    required this.city,
    required this.experience,
    required this.bio,
    this.isVerified = true,
    this.isPending = false,
    required this.craftsmanId,
  });

  @override
  State<CraftsmanDashboard> createState() => _CraftsmanDashboardState();
}

class _CraftsmanDashboardState extends State<CraftsmanDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  final osm.LatLng _defaultLocation = const osm.LatLng(31.9539, 35.9106);

  // ── Calendar state ──────────────────────────────────────────────────
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedDayEvents = [];
  Map<DateTime, List<Map<String, dynamic>>> _eventMap = {};

  // ── Exhibitions ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoadingExhibitions = true;
  int _exhibitionPage = 0;
  List<Map<String, dynamic>> _exhibitionInvites = [];
  bool _isLoadingInvites = true;

  // ── Dashboard story preview ─────────────────────────────────────────────
  List<Map<String, dynamic>> _dashboardStories = [];
  bool _isLoadingStories = true;

  // ── Real profile and dashboard statistics ─────────────────────────────
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  String? _profileError;

  Map<String, dynamic>? _aiInsights;
  bool _isLoadingAiInsights = true;
  String? _aiInsightsError;

  List<Map<String, dynamic>> _registrations = [];
  bool _isLoadingRegistrations = true;

  double _releasedHireEarnings = 0;
  int _completedHireOrders = 0;

  Map<String, dynamic> get _stats {
    final raw = _profile?['stats'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  double get _earnings =>
      (double.tryParse((_stats['earnings'] ?? 0).toString()) ?? 0) +
      _releasedHireEarnings;

  double? get _rating {
    final raw = _stats['rating'];
    if (raw == null) return null;
    return double.tryParse(raw.toString());
  }

  int get _completedOrders =>
      (int.tryParse((_stats['completedOrders'] ?? 0).toString()) ?? 0) +
      _completedHireOrders;

  int get _views => int.tryParse((_stats['views'] ?? 0).toString()) ?? 0;

  String get _earningsText {
    final value = _earnings;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '${localizeNumber(formatted)} JOD';
  }

  String get _ratingText {
    final value = _rating;
    if (value == null) return '—';
    return localizeNumber(value.toStringAsFixed(1));
  }

  String get _completedText => localizeNumber(_completedOrders.toString());

  String get _viewsText => localizeNumber(_views.toString());

  // ── Theme getters ──────────────────────────────────────────────────
  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;
  bool get _isMobile => !kIsWeb;

  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;

  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;

  Color get cardBorderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  Color get surfaceColor => isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => isArabic ? ar : en;

  String get _activeCategory {
    final profile = _profile;

    String? readLocalizedCategory(dynamic raw) {
      if (raw == null) return null;

      if (raw is String) {
        final value = raw.trim();
        return value.isEmpty ? null : value;
      }

      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final candidates = isArabic
            ? [
                map['nameAr'],
                map['titleAr'],
                map['categoryTitleAr'],
                map['ar'],
                map['name'],
                map['title'],
                map['nameEn'],
                map['titleEn'],
              ]
            : [
                map['nameEn'],
                map['titleEn'],
                map['categoryTitleEn'],
                map['en'],
                map['name'],
                map['title'],
                map['nameAr'],
                map['titleAr'],
              ];

        for (final candidate in candidates) {
          final value = candidate?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
      }

      return null;
    }

    if (profile != null) {
      final directCandidates = <dynamic>[
        profile['primaryCategory'],
        profile['category'],
        profile['craftsmanCategory'],
        isArabic ? profile['categoryTitleAr'] : profile['categoryTitleEn'],
      ];

      for (final candidate in directCandidates) {
        final value = readLocalizedCategory(candidate);
        if (value != null) return value;
      }

      for (final key in ['artisan', 'craftsman', 'user']) {
        final nested = profile[key];
        if (nested is Map) {
          final map = Map<String, dynamic>.from(nested);
          final nestedCandidates = <dynamic>[
            map['primaryCategory'],
            map['category'],
            map['craftsmanCategory'],
            isArabic ? map['categoryTitleAr'] : map['categoryTitleEn'],
          ];
          for (final candidate in nestedCandidates) {
            final value = readLocalizedCategory(candidate);
            if (value != null) return value;
          }
        }
      }
    }

    return isArabic ? widget.categoryTitleAr : widget.categoryTitleEn;
  }

  bool _blockPendingAction() {
    if (!widget.isPending) return false;
    _showPendingActionSheet();
    return true;
  }

  Future<void> _showPendingActionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryTextColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: accent,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('حسابك قيد المراجعة', 'Account Under Review'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: primaryTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'يمكنك استكشاف لوحة الحرفي والتعرّف على الواجهات، لكن تنفيذ هذا الإجراء سيتاح بعد موافقة الإدارة وتفعيل حسابك. عادةً تستغرق المراجعة من 24 إلى 48 ساعة.',
                      'You can explore the artisan dashboard and its screens, but this action will be available after the admin approves and activates your account. Review usually takes 24–48 hours.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: secondaryTextColor,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        t('حسنًا، فهمت', 'Got it'),
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String localizeNumber(String value) {
    if (!isArabic) return value;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      value = value.replaceAll(en[i], ar[i]);
    }
    return value;
  }

  Future<void> _fetchCraftsmanProfile() async {
    if (widget.craftsmanId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _profile = <String, dynamic>{
          'stats': <String, dynamic>{
            'earnings': 0,
            'rating': null,
            'completedOrders': 0,
            'views': 0,
          },
        };
        _isLoadingProfile = false;
        _profileError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
        _profileError = null;
      });
    }

    try {
      final response =
          await ApiService.get('/craftsman/profile/${widget.craftsmanId}');

      if (response.statusCode != 200) {
        throw Exception('Profile request failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid artisan profile response');
      }

      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(decoded);
        _isLoadingProfile = false;
        _profileError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profile = <String, dynamic>{
          'stats': <String, dynamic>{
            'earnings': 0,
            'rating': null,
            'completedOrders': 0,
            'views': 0,
          },
        };
        _isLoadingProfile = false;
        _profileError = error.toString();
      });
    }
  }

  Future<void> _fetchHireEarnings() async {
    if (widget.craftsmanId.trim().isEmpty) return;

    try {
      final response = await ApiService.get(
        '/payments/artisan/${widget.craftsmanId}/earnings',
      );
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final available =
          double.tryParse((decoded['available'] ?? 0).toString()) ?? 0;
      final rawTransactions = decoded['transactions'];
      final completedCount = rawTransactions is List
          ? rawTransactions.where((item) {
              return item is Map && item['escrowStatus'] == 'released';
            }).length
          : 0;

      if (!mounted) return;
      setState(() {
        _releasedHireEarnings = available;
        _completedHireOrders = completedCount;
      });
    } catch (error) {
      debugPrint('Hire earnings error: $error');
    }
  }

  Future<void> _loadUnifiedDashboardData() async {
    await Future.wait([
      _fetchCraftsmanProfile(),
      _fetchHireEarnings(),
      _fetchRegistrations(),
    ]);

    if (!mounted) return;
    await _fetchAiInsights();
    _populateCalendarEvents();
  }

  // ── NEW: Fetch registrations ───────────────────────────────────────────
  Future<void> _fetchRegistrations() async {
    if (widget.craftsmanId.trim().isEmpty) {
      setState(() {
        _registrations = [];
        _isLoadingRegistrations = false;
      });
      return;
    }
    setState(() => _isLoadingRegistrations = true);
    try {
      final regs = await ExhibitionsService.getCraftsmanRegistrations(
          widget.craftsmanId);
      setState(() {
        _registrations =
            regs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoadingRegistrations = false;
      });
    } catch (e) {
      setState(() {
        _registrations = [];
        _isLoadingRegistrations = false;
      });
    }
  }

  Future<void> _fetchAiInsights() async {
    if (widget.craftsmanId.trim().isEmpty || widget.isPending) {
      if (!mounted) return;
      setState(() {
        _aiInsights = null;
        _isLoadingAiInsights = false;
        _aiInsightsError = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAiInsights = true;
        _aiInsightsError = null;
      });
    }

    try {
      final response = await ApiService.post(
        '/ai/artisan-dashboard-insights',
        body: {
          'language': isArabic ? 'ar' : 'en',
          'metrics': {
            'earnings': _earnings,
            'completedOrders': _completedOrders,
            'views': _views,
            'rating': _rating,
            'hireEarnings': _releasedHireEarnings,
            'hireCompletedOrders': _completedHireOrders,
          },
        },
      );

      if (response.statusCode != 200) {
        throw Exception('AI insights request failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid AI insights response');
      }

      if (!mounted) return;
      setState(() {
        _aiInsights = Map<String, dynamic>.from(decoded);
        _isLoadingAiInsights = false;
        _aiInsightsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiInsights = null;
        _isLoadingAiInsights = false;
        _aiInsightsError = error.toString();
      });
    }
  }

  // ─── FIX: Remove the .take(3) limit ──────────────────────────────
  Future<void> _fetchDashboardExhibitions() async {
    if (mounted) {
      setState(() => _isLoadingExhibitions = true);
    }

    try {
      final list = await ExhibitionsService.getAllExhibitions();
      final filtered = list.where((ex) {
        final isPublic = ex['isPublic'];
        final isHidden = isPublic == false ||
            isPublic == 0 ||
            isPublic?.toString().toLowerCase() == 'false';
        final status = ex['status']?.toString().toLowerCase();
        final isUnavailable =
            status == 'pending' || status == 'draft' || status == 'rejected';
        return !isHidden && !isUnavailable;
      }).toList();

      if (!mounted) return;
      setState(() {
        _exhibitions = filtered.cast<Map<String, dynamic>>();
        _exhibitionPage = 0;
        _isLoadingExhibitions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exhibitions = <Map<String, dynamic>>[];
        _isLoadingExhibitions = false;
      });
    }
  }

  Future<void> _fetchInvites() async {
    if (mounted) {
      setState(() => _isLoadingInvites = true);
    }
    try {
      final response = await ApiService.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> allNotifications = jsonDecode(response.body);
        final inviteNotifications = allNotifications.where((n) {
          return n['type'] == 'exhibition_invite';
        }).toList();

        final List<Map<String, dynamic>> resolvedInvites = [];
        for (final notification in inviteNotifications) {
          final metadata = notification['metadata'];
          String? exhibitionId;
          if (metadata is Map) {
            exhibitionId = metadata['exhibitionId']?.toString();
          } else if (metadata is String) {
            try {
              final parsed = jsonDecode(metadata);
              if (parsed is Map) {
                exhibitionId = parsed['exhibitionId']?.toString();
              }
            } catch (_) {}
          }

          if (exhibitionId != null) {
            final ex = await ExhibitionsService.getExhibitionById(exhibitionId);
            if (ex != null) {
              resolvedInvites.add({
                'notificationId': notification['id'],
                'exhibition': ex,
                'titleAr': notification['titleAr'] ?? ex['name'],
                'titleEn':
                    notification['titleEn'] ?? ex['nameEn'] ?? ex['name'],
                'bodyAr': notification['bodyAr'],
                'bodyEn': notification['bodyEn'],
                'isRead': notification['isRead'] ?? false,
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            _exhibitionInvites = resolvedInvites;
            _isLoadingInvites = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingInvites = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching invites: $e');
      if (mounted) {
        setState(() => _isLoadingInvites = false);
      }
    }
  }

  List<DateTime> get _eventDates => _eventMap.keys.toList()..sort();

  List<Map<String, dynamic>> getEventsForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _eventMap[dateOnly] ?? [];
  }

  void _populateCalendarEvents() {
    final events = <DateTime, List<Map<String, dynamic>>>{};

    // 1. Exhibition registrations
    for (final reg in _registrations) {
      final ex = reg['Exhibition'] as Map<String, dynamic>?;
      if (ex == null) continue;
      final start = DateTime.tryParse(ex['startDate']?.toString() ?? '');
      final end = DateTime.tryParse(ex['endDate']?.toString() ?? '');
      if (start == null || end == null) continue;

      final status = reg['status'] ?? 'confirmed';
      final isConfirmed = status == 'confirmed';
      final color = isConfirmed ? Colors.green : Colors.amber;

      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final dateOnly = DateTime(d.year, d.month, d.day);
        events.putIfAbsent(dateOnly, () => []).add({
          'titleAr': isConfirmed
              ? 'معرض: ${ex['name'] ?? ''}'
              : 'معرض (قيد الانتظار): ${ex['name'] ?? ''}',
          'titleEn': isConfirmed
              ? 'Exhibition: ${ex['nameEn'] ?? ex['name'] ?? ''}'
              : 'Exhibition (Pending): ${ex['nameEn'] ?? ex['name'] ?? ''}',
          'time': '${ex['startDate']} - ${ex['endDate']}',
          'color': color,
          'type': 'exhibition',
          'registration': reg,
        });
      }
    }

    // 2. Custom order deadlines (from CustomOrderProvider)
    final customProv = context.read<CustomOrderProvider>();
    final customRequests = customProv.requestsForArtisan(widget.craftsmanId);
    for (final request in customRequests) {
      final response = request.artisanResponse;
      if (response == null) continue;
      final deliveryDate = response.deliveryDate;
      final dateOnly =
          DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
      events.putIfAbsent(dateOnly, () => []).add({
        'titleAr': 'موعد تسليم: ${request.templateTitleAr}',
        'titleEn': 'Delivery: ${request.templateTitleEn}',
        'time':
            '${deliveryDate.day}/${deliveryDate.month}/${deliveryDate.year}',
        'color': Colors.purple,
        'type': 'deadline',
        'requestId': request.id,
      });
    }

    // 3. Hire order days (from HireOrderProvider)
    final hireProv = context.read<HireOrderProvider>();
    final hireRequests = hireProv.requestsForArtisan(widget.craftsmanId);
    for (final request in hireRequests) {
      if (request.status == 'cancelled' || request.status == 'completed')
        continue;
      final start = request.startDate;
      final end = request.endDate;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final dateOnly = DateTime(d.year, d.month, d.day);
        events.putIfAbsent(dateOnly, () => []).add({
          'titleAr': 'عمل ميداني: ${request.jobDescription}',
          'titleEn': 'On-Site: ${request.jobDescription}',
          'time': '${start.day}/${start.month} - ${end.day}/${end.month}',
          'color': Colors.teal,
          'type': 'onsite',
          'hireRequestId': request.id,
        });
      }
    }

    _eventMap = events;

    if (_selectedDate != null) {
      _selectedDayEvents = _eventMap[_selectedDate] ?? [];
    }

    if (mounted) setState(() {});
  }

  Future<void> _openStoriesScreen() async {
    if (_blockPendingAction()) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CraftsmanStoriesScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          artisanId: widget.craftsmanId,
        ),
      ),
    );
    await _fetchDashboardStories();
  }

  void _openStoryCreator() {
    _openStoriesScreen();
  }

  Future<void> _fetchDashboardStories() async {
    if (widget.craftsmanId.trim().isEmpty) {
      if (mounted) setState(() => _isLoadingStories = false);
      return;
    }

    if (mounted) setState(() => _isLoadingStories = true);
    final data = await StoryService.getByArtisan(widget.craftsmanId);
    if (!mounted) return;

    setState(() {
      _dashboardStories = data.take(5).map<Map<String, dynamic>>((raw) {
        final story = Map<String, dynamic>.from(raw);
        return {
          'id': story['id']?.toString() ?? '',
          'textAr': story['textAr']?.toString() ?? '',
          'textEn': (story['textEn'] ?? story['textAr'] ?? '').toString(),
          'image': story['imageUrl']?.toString(),
          'likes': story['likes'] ?? 0,
          'comments': story['commentsCount'] ?? 0,
          'liked': (story['likedBy'] is List) &&
              (story['likedBy'] as List)
                  .map((e) => e.toString())
                  .contains(widget.craftsmanId),
          'timeAr': '',
          'timeEn': '',
        };
      }).toList();
      _isLoadingStories = false;
    });
  }

  Future<void> _showDashboardStoryComments(
    Map<String, dynamic> story,
  ) async {
    final storyId = story['id']?.toString() ?? '';
    if (storyId.isEmpty) return;

    final controller = TextEditingController();
    List<Map<String, dynamic>> comments = [];
    bool loading = true;
    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> load() async {
            final data = await StoryService.getComments(storyId);
            if (!sheetContext.mounted) return;
            setSheetState(() {
              comments = data;
              loading = false;
            });
          }

          if (loading && comments.isEmpty) Future.microtask(load);

          Future<void> send() async {
            final value = controller.text.trim();
            if (value.isEmpty || sending) return;
            setSheetState(() => sending = true);

            final created = await StoryService.addComment(storyId, value);
            if (!sheetContext.mounted) return;

            if (created != null) {
              controller.clear();
              setSheetState(() {
                comments.insert(0, created);
                sending = false;
              });
              if (mounted) {
                setState(() {
                  story['comments'] =
                      (int.tryParse((story['comments'] ?? 0).toString()) ?? 0) +
                          1;
                });
              }
            } else {
              setSheetState(() => sending = false);
            }
          }

          return Directionality(
            textDirection:
                isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  height: MediaQuery.of(sheetContext).size.height * 0.68,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondaryTextColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(Icons.forum_outlined, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              t('التعليقات', 'Comments'),
                              style: GoogleFonts.cairo(
                                color: primaryTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: cardBorderColor),
                      Expanded(
                        child: loading
                            ? Center(
                                child: CircularProgressIndicator(color: accent),
                              )
                            : comments.isEmpty
                                ? Center(
                                    child: Text(
                                      t(
                                        'لا توجد تعليقات بعد',
                                        'No comments yet',
                                      ),
                                      style: GoogleFonts.cairo(
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: comments.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) {
                                      final item = comments[index];
                                      final name = (item['userName'] ?? 'User')
                                          .toString();
                                      final avatar =
                                          item['profileImage']?.toString() ??
                                              '';
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                accent.withValues(alpha: 0.15),
                                            backgroundImage: avatar.isNotEmpty
                                                ? NetworkImage(avatar)
                                                : null,
                                            child: avatar.isEmpty
                                                ? Text(
                                                    name.isEmpty
                                                        ? '?'
                                                        : name.characters.first,
                                                    style: TextStyle(
                                                      color: accent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(11),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? Colors.white.withValues(
                                                        alpha: 0.045,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.035,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.cairo(
                                                      color: primaryTextColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    (item['text'] ?? '')
                                                        .toString(),
                                                    style: GoogleFonts.cairo(
                                                      color: primaryTextColor,
                                                      fontSize: 12,
                                                      height: 1.45,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                      ),
                      Divider(height: 1, color: cardBorderColor),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                style:
                                    GoogleFonts.cairo(color: primaryTextColor),
                                minLines: 1,
                                maxLines: 3,
                                onSubmitted: (_) => send(),
                                decoration: InputDecoration(
                                  hintText: t(
                                      'اكتب تعليقاً...', 'Write a comment...'),
                                  hintStyle: GoogleFonts.cairo(
                                    color: secondaryTextColor,
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.045)
                                      : Colors.black.withValues(alpha: 0.035),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: sending ? null : send,
                              icon: sending
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
  }

  void _showStoryViewer(Map<String, dynamic> story) {
    final storyText =
        (isArabic ? story['textAr'] : story['textEn'])?.toString().trim() ?? '';
    final imageUrl = (story['image'] ?? '').toString().trim();
    final isTextOnly = imageUrl.isEmpty;
    final profileImage = (_profile?['profileImage'] ?? '').toString().trim();
    final displayName = (_profile?['name'] ?? widget.name).toString().trim();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 72, 16, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.of(dialogContext).size.height - 130,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisAlignment: isTextOnly
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 5,
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFF1C2431),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                            size: 54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (storyText.isNotEmpty) ...[
                                  SizedBox(height: isTextOnly ? 0 : 18),
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        EdgeInsets.all(isTextOnly ? 22 : 18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C2431),
                                      borderRadius: BorderRadius.circular(
                                        isTextOnly ? 24 : 18,
                                      ),
                                      border: Border.all(
                                        color: isTextOnly
                                            ? accent.withValues(alpha: 0.30)
                                            : Colors.white
                                                .withValues(alpha: 0.10),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (isTextOnly) ...[
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 22,
                                                backgroundColor:
                                                    const Color(0xFF141B26),
                                                backgroundImage: profileImage
                                                        .isNotEmpty
                                                    ? NetworkImage(profileImage)
                                                    : null,
                                                child: profileImage.isEmpty
                                                    ? Icon(
                                                        Icons.person_outline,
                                                        color: accent,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                child: Text(
                                                  displayName.isEmpty
                                                      ? t('حرفي', 'Artisan')
                                                      : displayName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.cairo(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.format_quote_rounded,
                                                color: accent,
                                                size: 28,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 22),
                                        ],
                                        Text(
                                          storyText,
                                          textDirection: isArabic
                                              ? ui.TextDirection.rtl
                                              : ui.TextDirection.ltr,
                                          textAlign: isArabic
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          softWrap: true,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: isTextOnly ? 18 : 16,
                                            height: isTextOnly ? 1.8 : 1.7,
                                            fontWeight: isTextOnly
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                StatefulBuilder(
                                  builder: (statsContext, setStatsState) {
                                    final liked = story['liked'] == true;
                                    final likes = int.tryParse(
                                          (story['likes'] ?? 0).toString(),
                                        ) ??
                                        0;
                                    final comments = int.tryParse(
                                          (story['comments'] ?? 0).toString(),
                                        ) ??
                                        0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141B26),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            tooltip: t('إعجاب', 'Like'),
                                            onPressed: () async {
                                              final storyId =
                                                  (story['id'] ?? '')
                                                      .toString();
                                              final result =
                                                  await StoryService.toggleLike(
                                                storyId,
                                              );
                                              if (result != null) {
                                                story['liked'] =
                                                    result['liked'] == true;
                                                story['likes'] =
                                                    result['likes'] ?? likes;
                                                setStatsState(() {});
                                                if (mounted) setState(() {});
                                              }
                                            },
                                            icon: Icon(
                                              liked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 20,
                                              color: liked
                                                  ? Colors.redAccent
                                                  : Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            '$likes',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: t('تعليقات', 'Comments'),
                                            onPressed: () async {
                                              await _showDashboardStoryComments(
                                                story,
                                              );
                                              setStatsState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            '$comments',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const Spacer(),
                                          Flexible(
                                            child: Text(
                                              isArabic
                                                  ? (story['timeAr'] ?? '')
                                                      .toString()
                                                  : (story['timeEn'] ?? '')
                                                      .toString(),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final storyId =
                                        (story['id'] ?? '').toString().trim();
                                    if (storyId.isEmpty) return;

                                    final confirmed = await showDialog<bool>(
                                      context: dialogContext,
                                      builder: (confirmContext) => AlertDialog(
                                        backgroundColor:
                                            const Color(0xFF1C2431),
                                        title: Text(
                                          t('حذف القصة', 'Delete Story'),
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: Text(
                                          t(
                                            'هل أنت متأكد من حذف هذه القصة؟',
                                            'Are you sure you want to delete this story?',
                                          ),
                                          style: GoogleFonts.cairo(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                confirmContext, false),
                                            child: Text(t('إلغاء', 'Cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                confirmContext, true),
                                            child: Text(
                                              t('حذف', 'Delete'),
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    final deleted =
                                        await StoryService.deleteStory(storyId);
                                    if (!mounted) return;
                                    if (!dialogContext.mounted) return;

                                    if (deleted) {
                                      Navigator.pop(dialogContext);
                                      setState(() {
                                        _dashboardStories.removeWhere(
                                          (item) =>
                                              item['id']?.toString() == storyId,
                                        );
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            t('تم حذف القصة', 'Story deleted'),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            t(
                                              'فشل حذف القصة',
                                              'Failed to delete story',
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    t('حذف القصة', 'Delete Story'),
                                    style: GoogleFonts.cairo(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: IconButton.filled(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar() {
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

    List<Widget> dayWidgets = [];
    for (int i = 0; i < offset; i++) {
      dayWidgets.add(Container());
    }

    final eventDates = _eventDates;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
      final hasEvent = eventDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);
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
              _selectedDayEvents = getEventsForDate(date);
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
                      color: isSelected ? Colors.black : primaryTextColor,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (hasEvent)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
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

    return Column(
      children: [
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
                color: primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
        if (_selectedDate != null && _selectedDayEvents.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(_selectedDate!),
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedDayEvents.map((event) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: event['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: event['color'].withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 30,
                            color: event['color'],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic
                                      ? event['titleAr']
                                      : event['titleEn'],
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  event['time'],
                                  style: TextStyle(
                                      color: secondaryTextColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _getEventIcon(event['type']),
                            color: event['color'],
                            size: 18,
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'exhibition':
        return Icons.event;
      case 'deadline':
        return Icons.alarm;
      case 'onsite':
        return Icons.work;
      default:
        return Icons.circle;
    }
  }

  Widget _buildDashboardExhibitionsSection() {
    const pageSize = 3;
    final pageCount = (_exhibitions.length / pageSize).ceil();
    final start = _exhibitionPage * pageSize;
    final pageItems = _exhibitions.skip(start).take(pageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('معارض قريبة', 'Nearby Exhibitions'),
              style: GoogleFonts.cairo(
                color: primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_blockPendingAction()) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExploreExhibitionsScreen(),
                  ),
                );
              },
              child: Text(
                t('استكشف الكل', 'Explore All'),
                style: TextStyle(color: accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingExhibitions)
          const Center(child: CircularProgressIndicator())
        else if (_exhibitions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            child: Center(
              child: Text(
                t('لا توجد معارض قريبة حالياً', 'No nearby exhibitions'),
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
          )
        else ...[
          ...pageItems.map((ex) => _buildExhibitionCard(ex)),
          if (pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: t('المعارض السابقة', 'Previous exhibitions'),
                  onPressed: _exhibitionPage > 0
                      ? () => setState(() => _exhibitionPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_exhibitionPage + 1} / $pageCount'),
                IconButton(
                  tooltip: t('المعارض التالية', 'Next exhibitions'),
                  onPressed: _exhibitionPage < pageCount - 1
                      ? () => setState(() => _exhibitionPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildMapSection() {
    if (!_isMobile) return _buildDashboardExhibitionsSection();

    if (_isMobile) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('الموقع', 'Location'),
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _openLocationPicker,
                child: Text(
                  t('فتح الخريطة', 'Open Map'),
                  style: TextStyle(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _defaultLocation,
                    initialZoom: 12.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'craftgo',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _defaultLocation,
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: t('عمان، الأردن', 'Amman, Jordan'),
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFD4A017),
                              size: 42,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildDashboardExhibitionsSection(),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('معارض قريبة', 'Nearby Exhibitions'),
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  if (_blockPendingAction()) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CraftsmanExhibitionsScreen(
                        isArabic: isArabic,
                        isDarkMode: isDarkMode,
                        craftsmanId: widget.craftsmanId,
                      ),
                    ),
                  );
                },
                child: Text(
                  t('استكشف الكل', 'Explore All'),
                  style: TextStyle(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingExhibitions)
            const Center(child: CircularProgressIndicator())
          else if (_exhibitions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: Center(
                child: Text(
                  t('لا توجد معارض قريبة حالياً', 'No nearby exhibitions'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            )
          else
            ..._exhibitions.map((ex) => _buildExhibitionCard(ex)),
        ],
      );
    }
  }

  List<Color> _parseGradientColors(dynamic gradientData) {
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

  Widget _buildExhibitionCard(Map<String, dynamic> ex) {
    final name = isArabic ? ex['name'] : ex['nameEn'];
    final location = isArabic ? ex['location'] : ex['locationEn'];
    final startDate = ex['startDate'] ?? '';
    final endDate = ex['endDate'] ?? '';
    final gradient = _parseGradientColors(ex['gradient']);

    // ── Check if already registered ──────────────────────────────
    final registration = _registrations.firstWhere(
      (r) => r['exhibitionId']?.toString() == ex['id']?.toString(),
      orElse: () => <String, dynamic>{},
    );
    final isRegistered = registration.isNotEmpty;
    final regStatus = registration['status'] ?? '';
    final isConfirmed = regStatus == 'confirmed';
    final isStandby = regStatus == 'standby';
    final isPending = regStatus == 'pending' || regStatus == 'invited';

    return GestureDetector(
      onTap: () {
        if (_blockPendingAction()) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CraftsmanExhibitionDetailScreen(
              exhibition: ex,
              craftsmanId: widget.craftsmanId,
              isArabic: isArabic,
              isDarkMode: isDarkMode,
              registration: isRegistered ? registration : null,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ── Registration status badge ──────────────
                          if (isRegistered)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? Colors.green
                                    : isStandby
                                        ? Colors.amber
                                        : Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isConfirmed
                                    ? t('مسجل', 'Registered')
                                    : isStandby
                                        ? t('احتياط', 'Standby')
                                        : t('قيد الانتظار', 'Pending'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Date row
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: secondaryTextColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Builder(builder: (_) {
                              DateTime? s;
                              DateTime? e;
                              try {
                                s = startDate is String
                                    ? DateTime.tryParse(startDate)
                                    : null;
                              } catch (_) {
                                s = null;
                              }
                              try {
                                e = endDate is String
                                    ? DateTime.tryParse(endDate)
                                    : null;
                              } catch (_) {
                                e = null;
                              }

                              final df = isArabic
                                  ? DateFormat('d MMM y', 'ar')
                                  : DateFormat('MMM d, y', 'en_US');

                              String dateLabel;
                              if (s != null && e != null) {
                                dateLabel = '${df.format(s)} - ${df.format(e)}';
                              } else if (s != null) {
                                dateLabel = df.format(s);
                              } else if (startDate is String &&
                                  startDate.contains('T')) {
                                dateLabel = startDate.split('T').first;
                              } else {
                                dateLabel = '$startDate - $endDate';
                              }

                              return Text(
                                dateLabel,
                                style: TextStyle(
                                    color: secondaryTextColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                          ),
                        ],
                      ),
                      // Location row
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: secondaryTextColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              location,
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Builder(builder: (_) {
                  // Compute confirmed artisan count from ExhibitionCraftsmen list
                  final craftsmen = ex['ExhibitionCraftsmen'];
                  int confirmedCount = 0;
                  if (craftsmen is List) {
                    confirmedCount = craftsmen
                        .where((c) => c is Map && c['status'] == 'confirmed')
                        .length;
                  }
                  // Fall back to backend-pre-computed confirmedCount or artisans key
                  confirmedCount = confirmedCount > 0
                      ? confirmedCount
                      : (ex['confirmedCount'] ?? ex['artisans'] ?? 0) as int;
                  final maxCap = ex['capacity'] ?? ex['maxCapacity'] ?? 0;
                  return Text(
                    t('$confirmedCount / $maxCap حرفي',
                        '$confirmedCount / $maxCap artisans'),
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  );
                }),
                const Spacer(),
                if (!isRegistered)
                  ElevatedButton(
                    onPressed: () {
                      if (_blockPendingAction()) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExhibitionRegistrationScreen(
                            isArabic: isArabic,
                            isDarkMode: isDarkMode,
                            exhibition: ex,
                            craftsmanId: widget.craftsmanId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      t('سجل الآن', 'Register Now'),
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  )
                else
                  Text(
                    t('مسجل ✓', 'Registered ✓'),
                    style: TextStyle(
                        color: isConfirmed ? Colors.green : Colors.amber,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openLocationPicker() async {
    if (_blockPendingAction()) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          initialLocation: null,
          initialAddress: null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {});
    }
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('الدعوات والفعاليات', 'Invites & Events'),
          style: GoogleFonts.cairo(
            color: primaryTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingInvites)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Color(0xFFD4A017)),
            ),
          )
        else if (_exhibitionInvites.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  color: secondaryTextColor,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    'لا توجد دعوات أو فعاليات مرتبطة بحسابك حتى الآن',
                    'No invites or events are linked to your account yet',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        else
          ..._exhibitionInvites.map((invite) {
            final ex = invite['exhibition'] as Map<String, dynamic>;
            final title = isArabic ? invite['titleAr'] : invite['titleEn'];
            final body = isArabic ? invite['bodyAr'] : invite['bodyEn'];
            final gradientColors = _parseGradientColors(ex['gradient']);

            // Check if already registered for this exhibition
            final alreadyRegistered = _registrations.any(
              (r) => r['exhibitionId']?.toString() == ex['id']?.toString(),
            );

            return GestureDetector(
              onTap: alreadyRegistered
                  ? () {
                      // Navigate directly to detail screen if already registered
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CraftsmanExhibitionDetailScreen(
                            exhibition: ex,
                            craftsmanId: widget.craftsmanId,
                            isArabic: isArabic,
                            isDarkMode: isDarkMode,
                            registration: _registrations.firstWhere(
                              (r) =>
                                  r['exhibitionId']?.toString() ==
                                  ex['id']?.toString(),
                              orElse: () => <String, dynamic>{},
                            ),
                          ),
                        ),
                      );
                    }
                  : () {
                      if (_blockPendingAction()) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExhibitionRegistrationScreen(
                            isArabic: isArabic,
                            isDarkMode: isDarkMode,
                            exhibition: ex,
                            craftsmanId: widget.craftsmanId,
                            isInvited: true,
                          ),
                        ),
                      ).then((_) {
                        _fetchInvites();
                        _fetchRegistrations();
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: alreadyRegistered
                      ? surfaceColor.withValues(alpha: 0.5)
                      : surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: alreadyRegistered
                        ? Colors.grey.withValues(alpha: 0.3)
                        : cardBorderColor,
                  ),
                  // If already registered, add a subtle overlay
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        alreadyRegistered
                            ? Icons.check_circle
                            : Icons.mail_outline,
                        color: alreadyRegistered ? Colors.green : Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title ?? '',
                                  style: TextStyle(
                                    color: alreadyRegistered
                                        ? secondaryTextColor
                                        : primaryTextColor,
                                    fontWeight: alreadyRegistered
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (alreadyRegistered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    t('مسجل', 'Registered'),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4A017)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    t('دعوة', 'Invite'),
                                    style: const TextStyle(
                                      color: Color(0xFFD4A017),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body ?? '',
                            style: TextStyle(
                              color: alreadyRegistered
                                  ? secondaryTextColor.withValues(alpha: 0.7)
                                  : secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (!alreadyRegistered)
                                Text(
                                  t('اضغط للتفاصيل والتسجيل',
                                      'Tap for details & registration'),
                                  style: const TextStyle(
                                    color: Color(0xFFD4A017),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Text(
                                  t('مسجل مسبقاً - اضغط للتفاصيل',
                                      'Already registered - tap for details'),
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              if (!alreadyRegistered)
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Color(0xFFD4A017),
                                  size: 14,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Delete/Dismiss button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color:
                            alreadyRegistered ? Colors.grey : Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () async {
                        // Dismiss the invite notification
                        final notificationId =
                            invite['notificationId']?.toString();
                        if (notificationId != null) {
                          await NotificationService.deleteNotification(
                              notificationId);
                          _fetchInvites();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t('تم حذف الدعوة', 'Invite dismissed'),
                                ),
                                backgroundColor: Colors.grey,
                              ),
                            );
                          }
                        }
                      },
                      tooltip: t('حذف الدعوة', 'Dismiss invite'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  List<Map<String, dynamic>> get _myStories => _dashboardStories;

  Widget _buildStoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('قصصي والتحديثات', 'My Stories & Feed'),
              style: GoogleFonts.cairo(
                color: primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: _openStoriesScreen,
              child: Text(
                t('عرض التحديثات', 'View Feed'),
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 94,
          child: _isLoadingStories
              ? Align(
                  alignment:
                      isArabic ? Alignment.centerRight : Alignment.centerLeft,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _storyCircle(
                      onTap: _openStoryCreator,
                      icon: Icons.add,
                      label: t('أضف', 'Add'),
                      isAdd: true,
                    ),
                    ..._myStories.map((story) => _storyCircle(
                          onTap: () => _showStoryViewer(story),
                          icon: Icons.person,
                          label: t('قصتي', 'My Story'),
                          isAdd: false,
                          image: story['image']?.toString(),
                          storyText:
                              (isArabic ? story['textAr'] : story['textEn'])
                                  ?.toString(),
                        )),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _storyCircle({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isAdd,
    String? image,
    String? storyText,
  }) {
    final imageUrl = (image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;
    final hasText = (storyText ?? '').trim().isNotEmpty;
    final profileImage = (_profile?['profileImage'] ?? '').toString().trim();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAdd ? accent : accent.withValues(alpha: 0.72),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: isAdd
                    ? Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: accent, size: 28),
                      )
                    : ClipOval(
                        child: hasImage
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildTextStoryCircle(
                                  profileImage: profileImage,
                                  hasText: hasText,
                                ),
                              )
                            : _buildTextStoryCircle(
                                profileImage: profileImage,
                                hasText: hasText,
                              ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isAdd ? accent : secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextStoryCircle({
    required String profileImage,
    required bool hasText,
  }) {
    if (profileImage.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            profileImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1C2431),
              alignment: Alignment.center,
              child: Icon(
                hasText ? Icons.format_quote_rounded : Icons.person_outline,
                color: accent,
                size: 25,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(3),
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2431),
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1),
              ),
              child: Icon(
                Icons.format_quote_rounded,
                color: accent,
                size: 12,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: const Color(0xFF1C2431),
      alignment: Alignment.center,
      child: Icon(
        hasText ? Icons.format_quote_rounded : Icons.person_outline,
        color: accent,
        size: 26,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadUnifiedDashboardData();
    _fetchDashboardExhibitions();
    _fetchDashboardStories();
    _fetchInvites();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr;
    final activeCategory = _activeCategory;

    return Directionality(
      textDirection: direction,
      child: Container(
        color: backgroundColor,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                // ── Pending banner (shared) ─────────────────────────────────
                final pendingBanner = widget.isPending
                    ? GestureDetector(
                        onTap: _showPendingActionSheet,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t(
                                    'أنت الآن في وضع الاستكشاف. يمكنك مشاهدة الواجهات، وسيُفتح التفاعل بعد تفعيل الحساب.',
                                    'You are in preview mode. You can explore the screens, and actions will unlock after account approval.',
                                  ),
                                  style: GoogleFonts.cairo(
                                    color: primaryTextColor,
                                    fontSize: 12.5,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.lock_outline, color: accent, size: 20),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink();

                // ── Profile header ───────────────────────────────────────────
                final profileHeader = Row(
                  children: [
                    Container(
                      width: isDesktop ? 90 : 70,
                      height: isDesktop ? 90 : 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF1C2431),
                        backgroundImage: ((_profile?['profileImage'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                            ? NetworkImage(
                                (_profile!['profileImage']).toString())
                            : null,
                        child: ((_profile?['profileImage'] ?? '')
                                .toString()
                                .trim()
                                .isEmpty)
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFFD4A017),
                                size: 32,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  context.watch<AppState>().userName ??
                                      widget.name,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: isDesktop ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.city.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14, color: secondaryTextColor),
                                const SizedBox(width: 4),
                                Text(widget.city,
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                          if (!widget.isPending &&
                              widget.experience.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.workspace_premium_outlined,
                                    size: 14, color: secondaryTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  localizeNumber(widget.experience),
                                  style: TextStyle(
                                      color: secondaryTextColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: 1),
                            ),
                            child: Text(
                              activeCategory,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                // ── Stats card ───────────────────────────────────────────────
                final statsCard = _isLoadingProfile
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: cardBorderColor, width: 1.5),
                          color: surfaceColor,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(color: accent),
                        ),
                      )
                    : _profileError != null
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.red.shade300, width: 1),
                              color: surfaceColor,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t('تعذر تحميل بيانات الملف الشخصي',
                                        'Failed to load profile data'),
                                    style: TextStyle(
                                        color: primaryTextColor, fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _fetchCraftsmanProfile,
                                  child: Text(t('إعادة المحاولة', 'Retry'),
                                      style: TextStyle(color: accent)),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: cardBorderColor, width: 1.5),
                              color: surfaceColor,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  t("الأرباح", "Earnings"),
                                  _earningsText,
                                  Icons.account_balance_wallet_outlined,
                                ),
                                _buildStatDivider(),
                                _buildStatItem(
                                  t("التقييم", "Rating"),
                                  _ratingText,
                                  Icons.star_outline,
                                ),
                                _buildStatDivider(),
                                _buildStatItem(
                                  t("مكتمل", "Completed"),
                                  _completedText,
                                  Icons.done_all_outlined,
                                ),
                                _buildStatDivider(),
                                _buildStatItem(
                                  t("مشاهدات", "Views"),
                                  _viewsText,
                                  Icons.remove_red_eye_outlined,
                                ),
                              ],
                            ),
                          );

                if (isDesktop) {
                  // ── Desktop 2-column layout (Max Width 1100px) ───────────────
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isPending) ...[
                              pendingBanner,
                              const SizedBox(height: 20),
                            ],
                            // Desktop Hero Profile Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: cardBorderColor, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  profileHeader,
                                  const SizedBox(height: 24),
                                  const Divider(height: 1),
                                  const SizedBox(height: 20),
                                  statsCard,
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Stories row
                            _buildStoriesSection(),
                            const SizedBox(height: 28),
                            // 2-column Grid: AI Insights | Map Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildAiInsightsCard(),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: _buildMapSection(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            // 2-column Grid: Calendar | Events Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildCalendar(),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: _buildEventsSection(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // ── Mobile single-column layout (width < 600px / mobile) ───
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isPending) ...[
                          pendingBanner,
                          const SizedBox(height: 16),
                        ],
                        profileHeader,
                        const SizedBox(height: 24),
                        statsCard,
                        const SizedBox(height: 24),
                        _buildAiInsightsCard(),
                        const SizedBox(height: 24),
                        _buildStoriesSection(),
                        const SizedBox(height: 24),
                        _buildMapSection(),
                        const SizedBox(height: 24),
                        _buildCalendar(),
                        const SizedBox(height: 24),
                        _buildEventsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    final data = _aiInsights;
    final summary = (data?['summary'] ?? '').toString().trim();
    final label = (data?['performanceLabel'] ?? '').toString().trim();

    final highlights = data?['highlights'] is List
        ? List<dynamic>.from(data!['highlights'])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .take(3)
            .toList()
        : <String>[];

    final recommendations = data?['recommendations'] is List
        ? List<dynamic>.from(data!['recommendations'])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .take(3)
            .toList()
        : <String>[];

    final metrics = data?['metrics'] is Map
        ? Map<String, dynamic>.from(data!['metrics'])
        : <String, dynamic>{};

    final source = (data?['source'] ?? '').toString();
    final isGroq = source == 'groq';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('رؤى الذكاء الاصطناعي', 'AI Insights'),
                  style: GoogleFonts.cairo(
                    color: primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoadingAiInsights && data != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isGroq ? Colors.green : accent)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isGroq ? 'Groq AI' : t('بيانات حقيقية', 'Real Data'),
                    style: GoogleFonts.cairo(
                      color: isGroq ? Colors.green : accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingAiInsights)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child:
                    CircularProgressIndicator(color: accent, strokeWidth: 2.5),
              ),
            )
          else if (_aiInsightsError != null)
            Column(
              children: [
                Center(
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: secondaryTextColor,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    t(
                      'تعذر تحميل التحليل حالياً',
                      'Could not load AI insights right now',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _fetchAiInsights,
                    icon: Icon(Icons.refresh_rounded, color: accent),
                    label: Text(
                      t('إعادة المحاولة', 'Retry'),
                      style: GoogleFonts.cairo(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (data == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  t(
                    'ستظهر الرؤى بعد تفعيل الحساب وبدء استقبال بيانات حقيقية.',
                    'Insights will appear after the account is active and real data is collected.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: secondaryTextColor,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
            )
          else ...[
            if (label.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                summary,
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      t('المشاهدات', 'Views'),
                      _viewsText,
                      accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      t('الطلبات', 'Completed'),
                      _completedText,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      t('الأرباح', 'Earnings'),
                      _earningsText,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                t('أبرز النتائج', 'Highlights'),
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...highlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_graph_rounded, color: accent, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.cairo(
                            color: secondaryTextColor,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t('اقتراحات لتحسين الأداء', 'Recommended Actions'),
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...recommendations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: accent,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.cairo(
                            color: secondaryTextColor,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment:
                  isArabic ? Alignment.centerLeft : Alignment.centerRight,
              child: IconButton(
                tooltip: t('تحديث التحليل', 'Refresh insights'),
                onPressed: _fetchAiInsights,
                icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
              color: primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: cardBorderColor);
  }

  Widget _buildMetricTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              color: secondaryTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
