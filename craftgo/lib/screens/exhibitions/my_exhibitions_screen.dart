import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import 'exhibition_detail_screen.dart';
import 'exhibition_capacity_screen.dart';
import 'exhibition_add_screen.dart';

class MyExhibitionsScreen extends StatefulWidget {
  const MyExhibitionsScreen({super.key});

  @override
  State<MyExhibitionsScreen> createState() => _MyExhibitionsScreenState();
}

class _MyExhibitionsScreenState extends State<MyExhibitionsScreen> {
  int _selectedTabIndex = 0;
  String _searchQuery = '';
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoading = true;
  String _error = '';

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadExhibitions();
  }

  Future<void> _loadExhibitions() async {
    final appState = context.read<AppState>();
    final ownerId = appState.userId;
    if (ownerId == null || ownerId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'User not logged in';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await ExhibitionsService.getOwnerExhibitions(ownerId);
      setState(() {
        _exhibitions = data.map<Map<String, dynamic>>((item) {
          final statusMap = {
            'active': 'Active',
            'upcoming': 'Upcoming',
            'past': 'Past',
          };
          final status = item['status']?.toString().toLowerCase() ?? 'upcoming';
          final craftsmen = (item['ExhibitionCraftsmen'] as List?) ?? [];
          final interested = craftsmen.length;
          return {
            ...item,
            'status': statusMap[status] ?? 'Upcoming',
            'interested': interested,
          };
        }).toList();
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

  List<Color> _parseGradient(dynamic gradientData) {
    if (gradientData is List && gradientData.isNotEmpty) {
      try {
        return gradientData.map<Color>((c) {
          final hex = c.toString().replaceAll('#', '');
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
          return const Color(0xFFD4A017);
        }).toList();
      } catch (_) {
        return const [Color(0xFFD4A017), Color(0xFFB8860B)];
      }
    }
    return const [Color(0xFFD4A017), Color(0xFFB8860B)];
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    final dateStr = dateVal.toString().trim();
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final year = dt.year;
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    } catch (_) {
      if (dateStr.contains('T')) {
        return dateStr.split('T').first;
      }
      return dateStr;
    }
  }

  Future<void> _navigateToAddExhibition(
      [Map<String, dynamic>? existing]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExhibitionAddScreen(existingExhibition: existing),
      ),
    );

    if (result != null && result is Map) {
      // Instead of manual update, reload the whole list
      await _loadExhibitions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تم حفظ المعرض بنجاح', 'Exhibition saved successfully',
                context.read<AppState>()),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDelete(Map<String, dynamic> ex) {
    final appState = context.read<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final name = (isArabic ? ex['name'] : ex['nameEn'])?.toString() ?? '';

    String t(String ar, String en) => isArabic ? ar : en;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          title: Text(t('تأكيد الحذف', 'Confirm Delete'),
              style: GoogleFonts.cairo(color: text)),
          content: Text(
            isArabic
                ? 'هل أنت متأكد من حذف "$name"؟'
                : 'Are you sure you want to delete "$name"?',
            style: TextStyle(color: dim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'),
                  style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final exId = ex['id']?.toString();
                setState(() {
                  _exhibitions.removeWhere((e) => e['id'] == ex['id']);
                });
                Navigator.pop(ctx);
                if (exId != null && exId.isNotEmpty) {
                  await ExhibitionsService.deleteExhibition(exId);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تم حذف المعرض', 'Exhibition deleted')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(t('حذف', 'Delete'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredList {
    final query = _searchQuery.trim().toLowerCase();
    return _exhibitions.where((ex) {
      final nameAr = (ex['name'] ?? '').toString().toLowerCase();
      final nameEn = (ex['nameEn'] ?? nameAr).toString().toLowerCase();
      final nameMatches =
          query.isEmpty || nameAr.contains(query) || nameEn.contains(query);
      final statusMatches = _selectedTabIndex == 0 ||
          (_selectedTabIndex == 1 && ex['status'] == 'Active') ||
          (_selectedTabIndex == 2 && ex['status'] == 'Upcoming') ||
          (_selectedTabIndex == 3 && ex['status'] == 'Past');
      return nameMatches && statusMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final accent = const Color(0xFFD4A017);

    final filteredList = _filteredList;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            t('معارضي', 'My Exhibitions', appState),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAddExhibition(),
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text(
                  t('إضافة معرض', 'Add Exhibition', appState),
                  style: GoogleFonts.cairo(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: TextStyle(color: text),
                        decoration: InputDecoration(
                          hintText: t('ابحث عن معرض...',
                              'Search exhibitions...', appState),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildTab(0, t('الكل', 'All', appState), appState),
                          _buildTab(1, t('نشط', 'Active', appState), appState),
                          _buildTab(2, t('قادم', 'Upcoming', appState), appState),
                          _buildTab(3, t('منتهي', 'Past', appState), appState),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: accent))
                          : _error.isNotEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 48, color: Colors.red),
                                      const SizedBox(height: 12),
                                      Text(_error,
                                          style: GoogleFonts.cairo(color: dim),
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _loadExhibitions,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: Text(t(
                                            'إعادة المحاولة',
                                            'Retry',
                                            appState)),
                                      ),
                                    ],
                                  ),
                                )
                              : filteredList.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.museum_outlined,
                                              size: 60,
                                              color:
                                                  dim.withValues(alpha: 0.4)),
                                          const SizedBox(height: 16),
                                          Text(
                                            t(
                                                'لا توجد معارض',
                                                'No exhibitions found',
                                                appState),
                                            style: GoogleFonts.cairo(
                                                color: text,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            t(
                                                'اضغط زر + لإضافة معرض جديد',
                                                'Tap + to add your first exhibition',
                                                appState),
                                            style: GoogleFonts.cairo(
                                                color: dim, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isDesktop ? 3 : 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio:
                                            isDesktop ? 0.85 : 0.68,
                                      ),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final ex = filteredList[index];
                                        return _buildExhibitionCard(
                                            ex, appState);
                                      },
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

  Widget _buildTab(int index, String label, AppState appState) {
    final isSelected = _selectedTabIndex == index;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);
    final isArabic = appState.isArabic;

    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin:
            EdgeInsets.only(left: isArabic ? 8 : 0, right: isArabic ? 0 : 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? accent : border),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : text,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Banner helpers (pastel colors) ────────────────────────────────
  Map<String, dynamic> _getBannerData(String? eventType) {
    final type = eventType?.toLowerCase() ?? '';
    if (type.contains('art') || type == 'art exhibition') {
      return {
        'colors': [const Color(0xFFE3F0FE), const Color(0xFFC5D9F7)],
        'icon': Icons.palette,
      };
    } else if (type.contains('craft') || type.contains('fair')) {
      return {
        'colors': [const Color(0xFFFFF0E0), const Color(0xFFFFD9B3)],
        'icon': Icons.handyman,
      };
    } else if (type.contains('heritage') || type.contains('festival')) {
      return {
        'colors': [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
        'icon': Icons.history,
      };
    } else if (type.contains('workshop')) {
      return {
        'colors': [const Color(0xFFFFE8E8), const Color(0xFFFFCDD2)],
        'icon': Icons.build,
      };
    } else if (type.contains('pop-up') || type.contains('market')) {
      return {
        'colors': [const Color(0xFFFFF1E6), const Color(0xFFFFD6B3)],
        'icon': Icons.storefront,
      };
    } else if (type.contains('private')) {
      return {
        'colors': [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)],
        'icon': Icons.lock,
      };
    } else {
      return {
        'colors': [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
        'icon': Icons.museum,
      };
    }
  }

  Widget _buildExhibitionCard(Map<String, dynamic> ex, AppState appState) {
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final accent = const Color(0xFFD4A017);

    final name = (isArabic ? ex['name'] : ex['nameEn'])?.toString() ??
        t('بدون عنوان', 'Untitled', appState);
    final location =
        (isArabic ? ex['location'] : ex['locationEn'])?.toString() ??
            t('غير محدد', 'Not specified', appState);
    final status = ex['status']?.toString() ?? 'Upcoming';
    final type = ex['type']?.toString() ??
        (ex['isPublic'] == true ? 'Public' : 'Private');
    final eventType = ex['eventType']?.toString() ?? '';
    final interested = ex['interested'] ?? 0;
    final bannerData = _getBannerData(eventType);
    List<Color> gradientColors = _parseGradient(ex['gradient']);
    if (ex['imageUrl'] == null || ex['imageUrl'].toString().isEmpty) {
      gradientColors = bannerData['colors'] as List<Color>;
    }

    final bannerImageUrl = ex['bannerUrl'] ?? ex['imageUrl'];

    // ── Border color based on status ──────────────────────────────────
    Color borderColor;
    switch (status) {
      case 'Active':
        borderColor = Colors.green.shade600;
        break;
      case 'Past':
        borderColor = Colors.grey.shade600;
        break;
      case 'Upcoming':
      default:
        borderColor = accent;
        break;
    }

    // ── Status badge text and color ───────────────────────────────────
    Color statusColor = Colors.grey;
    String statusText = status;
    if (status == 'Active') {
      statusColor = Colors.green;
      statusText = t('نشط', 'Active', appState);
    } else if (status == 'Upcoming') {
      statusColor = Colors.amber;
      statusText = t('قادم', 'Upcoming', appState);
    } else if (status == 'Past') {
      statusText = t('منتهي', 'Past', appState);
    }

    return GestureDetector(
      onTap: () {
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExhibitionDetailScreen(
                exhibition: Map<String, dynamic>.from(ex),
              ),
            ),
          ).then((_) => _loadExhibitions());
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('حدث خطأ أثناء فتح المعرض',
                  'Error opening exhibition', appState)),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Container
            Container(
              height: 85,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                gradient: (bannerImageUrl == null ||
                        bannerImageUrl.toString().isEmpty)
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: (bannerImageUrl != null &&
                        bannerImageUrl.toString().isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(bannerImageUrl.toString()),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Dark overlay if image is loaded for legibility
                  if (bannerImageUrl != null &&
                      bannerImageUrl.toString().isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.black.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  // Event type icon
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Icon(
                      bannerData['icon'] as IconData,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 32,
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Public/Private icon
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Icon(
                      type == 'Public' ? Icons.public : Icons.lock,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          type == 'Public' ? Icons.public : Icons.lock,
                          color: type == 'Public'
                              ? accent
                              : const Color(0xFF9C27B0),
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: dim),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.cairo(color: dim, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: dim),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(ex['startDate']),
                            style: GoogleFonts.cairo(color: dim, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              '$interested',
                              style: GoogleFonts.cairo(
                                  color: text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        // ── FIX: Use a constrained Row with GestureDetector ──
                        SizedBox(
                          width: 90, // Fixed width for the 3 action icons
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: () => _navigateToAddExhibition(ex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final exName =
                                      (isArabic ? ex['name'] : ex['nameEn'])
                                              ?.toString() ??
                                          '';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExhibitionCapacityScreen(
                                        exhibitionName: exName,
                                        maxCapacity: ex['capacity'] ?? 10,
                                        exhibitionId: ex['id']?.toString(),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.people_alt,
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _confirmDelete(ex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}
