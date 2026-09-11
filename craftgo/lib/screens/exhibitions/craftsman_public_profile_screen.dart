import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';

class CraftsmanPublicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> artisan;
  final bool isArabic;
  final bool isDarkMode;
  final bool showFavoriteButton;

  const CraftsmanPublicProfileScreen({
    super.key,
    required this.artisan,
    required this.isArabic,
    required this.isDarkMode,
    this.showFavoriteButton = true,
  });

  @override
  State<CraftsmanPublicProfileScreen> createState() =>
      _CraftsmanPublicProfileScreenState();
}

class _CraftsmanPublicProfileScreenState
    extends State<CraftsmanPublicProfileScreen> {
  late Map<String, dynamic> _artisan;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];

  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;
  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();
    _artisan = Map<String, dynamic>.from(widget.artisan);
    _fetchFullProfile();
  }

  Future<void> _fetchFullProfile() async {
    final id = _artisan['id']?.toString();
    if (id == null || id.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ExhibitionsService.getCraftsmanProfile(id);
      if (res != null && mounted) {
        final user = res;
        final profile = user['ArtisanProfile'] as Map<String, dynamic>? ?? {};
        final reviews = (user['artisanReviews'] as List?) ?? [];
        setState(() {
          _artisan = {
            ..._artisan,
            'name': user['name'] ?? _artisan['name'],
            'nameEn': user['name'] ?? _artisan['nameEn'],
            'city': user['city'] ?? _artisan['city'],
            'cityEn': user['city'] ?? _artisan['cityEn'],
            'phone': user['phone'] ?? _artisan['phone'],
            'craft': profile['specialty'] ?? _artisan['craft'],
            'craftEn': profile['specialtyEn'] ??
                profile['specialty'] ??
                _artisan['craftEn'],
            'bio': profile['bio'] ?? _artisan['bio'],
            'bioEn': profile['bioEn'] ?? profile['bio'] ?? _artisan['bioEn'],
            'rating': (profile['rating'] is num)
                ? (profile['rating'] as num).toDouble()
                : _artisan['rating'] ?? 0.0,
            'completedOrders':
                profile['completedOrders'] ?? _artisan['completedOrders'] ?? 0,
            'yearsExp':
                profile['yearsOfExperience'] ?? _artisan['yearsExp'] ?? 0,
            'specializations':
                profile['specializations'] ?? _artisan['specializations'] ?? [],
            'PortfolioItems': profile['PortfolioItems'] ?? [],
          };

          _reviews = reviews.map<Map<String, dynamic>>((r) {
            final customer = r['customer'] as Map<String, dynamic>? ?? {};
            return {
              'id': r['id']?.toString() ?? '',
              'customerName': customer['name'] ?? 'مستخدم',
              'customerNameEn': customer['name'] ?? 'User',
              'rating': r['rating'] ?? 5,
              'commentAr': r['commentAr'] ?? '',
              'commentEn': r['commentEn'] ?? '',
              'createdAt': r['createdAt'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching craftsman profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleStar() {
    final appState = context.read<AppState>();
    appState.toggleStarredArtisan(_artisan);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStarred =
        appState.isArtisanStarred(_artisan['id']?.toString() ?? '');

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    final name = isArabic ? _artisan['name'] : _artisan['nameEn'];
    final craft = isArabic ? _artisan['craft'] : _artisan['craftEn'];
    final city = isArabic ? _artisan['city'] : _artisan['cityEn'];
    final rating = _artisan['rating'] ?? 0.0;
    final completedOrders = _artisan['completedOrders'] ?? 0;
    final specializations = _artisan['specializations'] as List? ?? [];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('الملف الشخصي', 'Profile'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Text(
                      name != null && name.isNotEmpty ? name[0] : 'C',
                      style: TextStyle(
                        color: accent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? '',
                          style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          craft ?? '',
                          style: GoogleFonts.cairo(
                            color: accent,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: dim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              city ?? '',
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Stats ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(
                      value: rating.toStringAsFixed(1),
                      label: t('التقييم', 'Rating'),
                      accent: accent,
                      dim: dim,
                    ),
                    _StatDivider(color: border),
                    _Stat(
                      value: '$completedOrders',
                      label: t('طلبات مكتملة', 'Completed'),
                      accent: accent,
                      dim: dim,
                    ),
                    if (widget.showFavoriteButton) ...[
                      _StatDivider(color: border),
                      GestureDetector(
                        onTap: _toggleStar,
                        child: Column(
                          children: [
                            Icon(
                              isStarred
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isStarred ? Colors.amber : accent,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('المفضلة', 'Favorite'),
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Bio ────────────────────────────────────────────────────
              if (_artisan['bio'] != null &&
                  _artisan['bio'].toString().isNotEmpty) ...[
                Text(
                  t('نبذة', 'About'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? _artisan['bio']
                      : (_artisan['bioEn'] ?? _artisan['bio']),
                  style: GoogleFonts.cairo(
                    color: dim,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Specializations ──────────────────────────────────────
              if (specializations.isNotEmpty) ...[
                Text(
                  t('التخصصات', 'Specializations'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specializations.map((spec) {
                    return _Chip(
                      label: spec.toString(),
                      accent: accent,
                      surface: surface,
                      border: border,
                      text: text,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // ── Portfolio ──────────────────────────────────────────────
              if (_artisan['PortfolioItems'] != null &&
                  (_artisan['PortfolioItems'] as List).isNotEmpty) ...[
                Text(
                  t('أعماله', 'Portfolio'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_artisan['PortfolioItems'] as List).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final item = (_artisan['PortfolioItems'] as List)[i];
                      final title =
                          isArabic ? item['titleAr'] : item['titleEn'];
                      return Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: accent.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title ?? t('منتج', 'Item'),
                              style: GoogleFonts.cairo(
                                color: text,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Reviews ──────────────────────────────────────────────
              Text(
                t('التقييمات', 'Reviews'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Center(
                    child: Text(
                      t('لا توجد تقييمات حتى الآن', 'No reviews yet'),
                      style: GoogleFonts.cairo(color: dim, fontSize: 14),
                    ),
                  ),
                )
              else
                ..._reviews.take(5).map((review) {
                  final reviewerName = isArabic
                      ? review['customerName']
                      : review['customerNameEn'];
                  final comment =
                      isArabic ? review['commentAr'] : review['commentEn'];
                  final ratingVal = review['rating'] ?? 5;
                  return _ReviewCard(
                    name: reviewerName,
                    rating: ratingVal,
                    comment: comment,
                    isArabic: isArabic,
                    accent: accent,
                    surface: surface,
                    border: border,
                    text: text,
                    dim: dim,
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value, label;
  final Color accent, dim;

  const _Stat({
    required this.value,
    required this.label,
    required this.accent,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: dim,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: color);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color accent, surface, border, text;

  const _Chip({
    required this.label,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name;
  final int rating;
  final String comment;
  final bool isArabic;
  final Color accent, surface, border, text, dim;

  const _ReviewCard({
    required this.name,
    required this.rating,
    required this.comment,
    required this.isArabic,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0] : 'U',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: i < rating
                        ? const Color(0xFFF7B500)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            style: TextStyle(
              color: dim,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
