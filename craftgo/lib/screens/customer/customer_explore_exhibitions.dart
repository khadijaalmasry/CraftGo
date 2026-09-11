import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import 'customer_exhibition_detail_screen.dart';

class CustomerExploreExhibitionsScreen extends StatefulWidget {
  const CustomerExploreExhibitionsScreen({super.key});

  @override
  State<CustomerExploreExhibitionsScreen> createState() =>
      _CustomerExploreExhibitionsScreenState();
}

class _CustomerExploreExhibitionsScreenState
    extends State<CustomerExploreExhibitionsScreen> {
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadExhibitions();
  }

  Future<void> _loadExhibitions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await ExhibitionsService.getAllExhibitions();
      if (data.isNotEmpty) {
        final now = DateTime.now();
        // Filter active/upcoming exhibitions
        final filtered = data.where((item) {
          final start = DateTime.tryParse(item['startDate']?.toString() ?? '');
          final end = DateTime.tryParse(item['endDate']?.toString() ?? '');
          if (start == null || end == null) return false;
          return end.isAfter(now) || end.isAtSameMomentAs(now);
        }).toList();

        // Build the mapped list with computed fields
        final mapped = filtered.map<Map<String, dynamic>>((item) {
          // Build gradient for the card (if needed)
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

          final artisansCount =
              (item['ExhibitionCraftsmen'] as List?)?.length ?? 0;
          final maxCap = item['capacity'] ?? 20;
          final isFull = item['isFull'] ?? (artisansCount >= maxCap);

          // Compute status from dates if not provided
          String status = item['status'] ?? 'upcoming';
          if (status == 'upcoming') {
            try {
              final start = DateTime.parse(item['startDate']);
              final end = DateTime.parse(item['endDate']);
              final now = DateTime.now();
              if (now.isAfter(end))
                status = 'past';
              else if (now.isAfter(start)) status = 'active';
            } catch (_) {}
          }

          return {
            // Keep all original fields for detail screen
            ...item,
            // Add computed fields
            'artisans': artisansCount,
            'maxCapacity': maxCap,
            'isFull': isFull,
            'gradient': gradientColors,
            'status': status,
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

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
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
            t('استكشاف المعارض', 'Explore Exhibitions', appState),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: text),
              onPressed: _loadExhibitions,
            ),
          ],
        ),
        body: RefreshIndicator(
          color: accent,
          onRefresh: _loadExhibitions,
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: accent))
              : _error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            t('حدث خطأ', 'Something went wrong', appState),
                            style: GoogleFonts.cairo(color: text, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error,
                            style: GoogleFonts.cairo(color: dim, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadExhibitions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                            ),
                            child: Text(t('إعادة المحاولة', 'Retry', appState)),
                          ),
                        ],
                      ),
                    )
                  : _exhibitions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 60, color: dim),
                              const SizedBox(height: 12),
                              Text(
                                t('لا توجد معارض حالياً',
                                    'No exhibitions right now', appState),
                                style:
                                    GoogleFonts.cairo(color: dim, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _exhibitions.length,
                          itemBuilder: (context, index) {
                            final ex = _exhibitions[index];
                            final isFull = ex['isFull'] ?? false;

                            return GestureDetector(
                              onTap: () {
                                // Navigate to CustomerExhibitionDetailScreen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerExhibitionDetailScreen(
                                      exhibition: ex,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: border),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Header with status
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? Colors.amber
                                                .withValues(alpha: 0.05)
                                            : Colors.green
                                                .withValues(alpha: 0.05),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                        border: Border(
                                            bottom: BorderSide(color: border)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isFull
                                                    ? Icons.hourglass_empty
                                                    : Icons
                                                        .check_circle_outline,
                                                color: isFull
                                                    ? Colors.amber.shade700
                                                    : Colors.green,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isFull
                                                    ? t(
                                                        'ممتلئ - متاح للاحتياط',
                                                        'Full - Standby Available',
                                                        appState)
                                                    : t(
                                                        'متاح للتسجيل الأساسي',
                                                        'Available for Registration',
                                                        appState),
                                                style: GoogleFonts.cairo(
                                                  color: isFull
                                                      ? Colors.amber.shade700
                                                      : Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isFull
                                                  ? Colors.amber
                                                      .withValues(alpha: 0.2)
                                                  : Colors.green
                                                      .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isFull
                                                  ? t('احتياط متاح',
                                                      'Standby Open', appState)
                                                  : t(
                                                      'مقاعد متاحة',
                                                      'Seats Available',
                                                      appState),
                                              style: GoogleFonts.cairo(
                                                color: isFull
                                                    ? Colors.amber.shade700
                                                    : Colors.green.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Content
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color:
                                                  accent.withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Icon(Icons.event,
                                                color: accent, size: 30),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isArabic
                                                      ? ex['name']
                                                      : ex['nameEn'],
                                                  style: GoogleFonts.cairo(
                                                    color: text,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_month,
                                                        color: dim, size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      ex['startDate'] != null
                                                          ? ex['startDate']
                                                              .toString()
                                                              .substring(0, 10)
                                                          : t('لم يحدد بعد',
                                                              'TBD', appState),
                                                      style: GoogleFonts.cairo(
                                                          color: dim,
                                                          fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on,
                                                        color: dim, size: 12),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        isArabic
                                                            ? ex['location']
                                                            : ex['locationEn'],
                                                        style:
                                                            GoogleFonts.cairo(
                                                                color: dim,
                                                                fontSize: 11),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                    // "View Details" button (optional) – but the whole card is tappable
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CustomerExhibitionDetailScreen(
                                                  exhibition: ex,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            t('عرض التفاصيل', 'View Details',
                                                appState),
                                            style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold),
                                          ),
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
      ),
    );
  }
}
