import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CraftsmanProjectsScreen — أعمال ومشاريع الحرفي (البورتفوليو)
// ─────────────────────────────────────────────────────────────────────────────

class CraftsmanProjectsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const CraftsmanProjectsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<CraftsmanProjectsScreen> createState() => _CraftsmanProjectsScreenState();
}

class _CraftsmanProjectsScreenState extends State<CraftsmanProjectsScreen> {
  // Theme colors
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  /// Convert English digits to Eastern Arabic digits when isArabic is true
  String localizeNumber(String value) {
    if (!widget.isArabic) return value;
    const en = ['0','1','2','3','4','5','6','7','8','9'];
    const ar = ['\u0660','\u0661','\u0662','\u0663','\u0664','\u0665','\u0666','\u0667','\u0668','\u0669'];
    for (int i = 0; i < en.length; i++) {
      value = value.replaceAll(en[i], ar[i]);
    }
    return value;
  }

  final List<Map<String, dynamic>> _projects = [
    {
      'id': '1',
      'titleAr': 'تركيب مطبخ خشب بلوط',
      'titleEn': 'Oak Wood Kitchen Install',
      'date': 'نوفمبر 2026',
      'dateEn': 'Nov 2026',
      'image': 'assets/kitchen.png',
      'likes': 12,
    },
    {
      'id': '2',
      'titleAr': 'تفصيل طاولة طعام',
      'titleEn': 'Custom Dining Table',
      'date': 'أكتوبر 2026',
      'dateEn': 'Oct 2026',
      'image': 'assets/table.png',
      'likes': 8,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            t('مشاريعي', 'My Projects'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: accent, size: 28),
              onPressed: () {
                // Add new project
              },
            ),
          ],
        ),
        body: _projects.isEmpty ? _buildEmptyState() : _buildGrid(),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent,
          onPressed: () {},
          icon: Icon(Icons.add, color: widget.isDarkMode ? Colors.black : Colors.white),
          label: Text(
            t('مشروع جديد', 'New Project'),
            style: GoogleFonts.cairo(
              color: widget.isDarkMode ? Colors.black : Colors.white, 
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.1)),
            child: Icon(Icons.folder_special_outlined, size: 60, color: accent),
          ),
          const SizedBox(height: 16),
          Text(t('أضف أول عمل لك لتبهر زبائنك!', 'Add your first project to impress your clients!'), 
            style: GoogleFonts.cairo(color: dim, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final proj = _projects[index];
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: accent.withValues(alpha: 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 36, color: dim),
                      const SizedBox(height: 8),
                      Text(
                        t('أضف صورة لعملك', 'Add work photo'),
                        style: GoogleFonts.cairo(color: dim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(proj['titleAr'], proj['titleEn']),
                      style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(localizeNumber(t(proj['date'], proj['dateEn'])), style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(localizeNumber('${proj['likes']}'), style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
