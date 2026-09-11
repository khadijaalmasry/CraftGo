import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart'; // ✅ single import
import '../customer/artisan_profile_page.dart';

class CustomerExhibitionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exhibition;

  const CustomerExhibitionDetailScreen({
    super.key,
    required this.exhibition,
  });

  @override
  State<CustomerExhibitionDetailScreen> createState() =>
      _CustomerExhibitionDetailScreenState();
}

class _CustomerExhibitionDetailScreenState
    extends State<CustomerExhibitionDetailScreen> {
  Map<String, dynamic>? _exhibitionData;
  bool _isInterested = false;
  bool _isLoading = true;
  bool _isTogglingInterest = false;
  String _error = '';

  // ── Theme Helpers ──────────────────────────────────────────────────────────
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
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => context.read<AppState>().isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _exhibitionData = Map<String, dynamic>.from(widget.exhibition);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final exhibId = widget.exhibition['id']?.toString();
    if (exhibId == null || exhibId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No exhibition ID provided';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ExhibitionsService.getExhibitionById(exhibId);
      if (res != null) {
        setState(() {
          _exhibitionData = Map<String, dynamic>.from(res);
          _isLoading = false;
          _error = '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load exhibition details';
        });
      }

      // Check if already interested
      final interestStatus =
          await ExhibitionsService.isInterested(exhibId); // ✅ corrected
      if (mounted) {
        setState(() => _isInterested = interestStatus);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _toggleInterest() async {
    if (_isTogglingInterest) return;
    setState(() => _isTogglingInterest = true);

    final exhibId = _exhibitionData?['id']?.toString() ?? '';
    final result = await ExhibitionsService.toggleInterest(exhibId);

    if (mounted) {
      setState(() {
        _isInterested = result;
        _isTogglingInterest = false;
      });

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تمت إضافة المعرض إلى المفضلة',
                'Exhibition added to favorites',
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Schedule reminder notification
        await _scheduleReminder();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تمت إزالة المعرض من المفضلة',
                'Exhibition removed from favorites',
              ),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _scheduleReminder() async {
    final startDate = _exhibitionData?['startDate'];
    if (startDate == null) return;

    try {
      final date = DateTime.parse(startDate.toString());
      // For now we just print – you can implement actual scheduling later
      debugPrint('Reminder scheduled for $date: ${_exhibitionData?['name']}');
    } catch (e) {
      debugPrint('Failed to schedule reminder: $e');
    }
  }

  List<Color> _parseGradient(dynamic gradientData) {
    const defaultGradient = [Color(0xFF1976D2), Color(0xFF009688)];
    if (gradientData is List && gradientData.isNotEmpty) {
      try {
        return gradientData.map<Color>((c) {
          final hex = c.toString().replaceAll('#', '');
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          } else if (hex.length == 8) {
            return Color(int.parse(hex, radix: 16));
          }
          return defaultGradient.first;
        }).toList();
      } catch (_) {
        return defaultGradient;
      }
    }
    return defaultGradient;
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
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppState>().isArabic;

    if (_isLoading) {
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
              Text(
                t('حدث خطأ', 'Something went wrong'),
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
                onPressed: _loadDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
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

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
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
                    // Gradient background (always present as fallback)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Banner image (if available) – placed on top
                    if (bannerImageUrl != null &&
                        bannerImageUrl.toString().isNotEmpty)
                      Image.network(
                        bannerImageUrl.toString(),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          // Show a subtle loading indicator (or just the gradient)
                          return Container(); // gradient is visible underneath
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // On error, just show the gradient (already visible)
                          return Container();
                        },
                      ),
                    // Dark overlay for text readability
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
                    // ── Interested Button ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isTogglingInterest ? null : _toggleInterest,
                              icon: _isTogglingInterest
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      _isInterested
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _isInterested
                                          ? Colors.red
                                          : Colors.black,
                                    ),
                              label: Text(
                                _isInterested
                                    ? t('مهتم', 'Interested')
                                    : t('مهتم / تذكير', 'Interested / Remind'),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isInterested
                                    ? Colors.red.shade100
                                    : accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Info Card ───────────────────────────────────────────
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Use Expanded to give the location text space to wrap
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        color: accent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? exhibition['location'] ?? ''
                                            : exhibition['locationEn'] ?? '',
                                        style: GoogleFonts.cairo(
                                          color: text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        softWrap: true,
                                        maxLines: null, // allow wrapping
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
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
                              color: dim,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Booth Layout ────────────────────────────────────────
                    _buildBoothLayout(participants),
                    const SizedBox(height: 24),

                    // ── Participating Artisans ─────────────────────────────
                    _buildParticipatingArtisans(participants),
                    const SizedBox(height: 24),

                    // ── Location Details ────────────────────────────────────
                    _buildLocationDetails(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Booth Layout ─────────────────────────────────────────────────────────
  Widget _buildBoothLayout(List<Map<String, dynamic>> participants) {
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
                  color: text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${rows}x$columns',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
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

              return Container(
                decoration: BoxDecoration(
                  color: isOccupied ? accent.withValues(alpha: 0.1) : surface,
                  borderRadius: BorderRadius.circular(10),
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
                        fontSize: 14,
                      ),
                    ),
                    if (isOccupied) ...[
                      const SizedBox(height: 2),
                      Text(
                        participant['name'] as String,
                        style: TextStyle(
                          color: text,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                    if (!isOccupied)
                      Text(
                        t('متاح', 'Available'),
                        style: TextStyle(color: dim, fontSize: 9),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(accent, t('محجوز', 'Taken')),
              _legendItem(Colors.transparent, t('متاح', 'Available')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
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
        Text(
          label,
          style: TextStyle(color: dim, fontSize: 10),
        ),
      ],
    );
  }

  // ─── Participating Artisans ──────────────────────────────────────────────
  Widget _buildParticipatingArtisans(List<Map<String, dynamic>> participants) {
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
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
              'available': true,
            };

            return GestureDetector(
              onTap: () {
                // ── Navigate to ArtisanProfilePage ─────────────────────────
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtisanProfilePage(
                      artisan: artisanMap,
                      isArabic: context.read<AppState>().isArabic,
                      isDarkMode: context.read<AppState>().isDarkMode,
                      isGuest: false,
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
                      child: Text(
                        name[0],
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      t('كشك $boothId', 'Booth $boothId'),
                      style: GoogleFonts.cairo(color: dim, fontSize: 8),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Location Details ─────────────────────────────────────────────────────
  Widget _buildLocationDetails() {
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
        Text(
          t('تفاصيل الموقع', 'Location Details'),
          style: GoogleFonts.cairo(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                        value: country,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (city.isNotEmpty) ...[
                      _locationRow(
                        icon: Icons.location_city,
                        label: t('المدينة', 'City'),
                        value: city,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (street.isNotEmpty) ...[
                      _locationRow(
                        icon: Icons.streetview,
                        label: t('الشارع', 'Street'),
                        value: street,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (building.isNotEmpty) ...[
                      _locationRow(
                        icon: Icons.home,
                        label: t('المبنى / الوحدة', 'Building / Unit'),
                        value: building,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (extraDetails.isNotEmpty) ...[
                      _locationRow(
                        icon: Icons.info_outline,
                        label: t('تفاصيل إضافية', 'Additional Details'),
                        value: extraDetails,
                      ),
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

  Widget _locationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(color: text, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
