import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown when a craftsman adds a new craft from their profile.
/// Collects craft-specific details, then fires [onConfirmed] with the category.
class AddCraftDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCategory;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final void Function(Map<String, dynamic> category) onConfirmed;

  const AddCraftDetailsScreen({
    super.key,
    required this.selectedCategory,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.onConfirmed,
  });

  @override
  State<AddCraftDetailsScreen> createState() => _AddCraftDetailsScreenState();
}

class _AddCraftDetailsScreenState extends State<AddCraftDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();
  final _specificController = TextEditingController();

  late bool _isArabic;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.isArabic;
    _isDarkMode = widget.isDarkMode;
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _bioController.dispose();
    _specificController.dispose();
    super.dispose();
  }

  // ── Theme helpers ──────────────────────────────────────────────────────────
  Color get bg => _isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => _isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => _isDarkMode ? Colors.white : Colors.black87;
  Color get dim => _isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => _isDarkMode ? Colors.white12 : Colors.black12;
  static const Color gold = Color(0xFFD4A017);

  String t(String ar, String en) => _isArabic ? ar : en;

  String get _categoryTitleEn =>
      widget.selectedCategory['titleEn'] as String? ?? '';

  // The category-specific question (null if none)
  ({String labelAr, String labelEn, IconData icon})? get _specificQuestion {
    switch (_categoryTitleEn) {
      case 'Pottery & Ceramics':
        return (
          labelAr: 'ما هي أنواع الطين المستخدمة؟',
          labelEn: 'Types of clay used?',
          icon: Icons.layers_outlined,
        );
      case 'Jewelry & Accessories':
        return (
          labelAr: 'ما هي المعادن التي تعمل بها؟',
          labelEn: 'Metals you work with?',
          icon: Icons.diamond_outlined,
        );
      case 'Crochet & Knitting':
        return (
          labelAr: 'هل توفر خدمة التفصيل حسب المقاس؟',
          labelEn: 'Do you offer custom sizing?',
          icon: Icons.straighten,
        );
      case 'Woodworking':
        return (
          labelAr: 'ما هي أنواع الخشب التي تعمل بها؟',
          labelEn: 'What types of wood do you work with?',
          icon: Icons.forest_outlined,
        );
      case 'Weaving & Baskets':
        return (
          labelAr: 'ما هي المواد التي تستخدمها للنسج؟',
          labelEn: 'What materials do you weave with?',
          icon: Icons.texture,
        );
      case 'Painting & Decoration':
        return (
          labelAr: 'ما هي أسلوبك الفني المفضل؟',
          labelEn: 'What is your preferred art style?',
          icon: Icons.palette_outlined,
        );
      default:
        return null;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Attach the answers to the category map so caller can store them
      final enriched = Map<String, dynamic>.from(widget.selectedCategory);
      enriched['addedExperience'] = _experienceController.text.trim();
      enriched['addedBio'] = _bioController.text.trim();
      if (_specificQuestion != null) {
        enriched['addedSpecificAnswer'] = _specificController.text.trim();
      }
      widget.onConfirmed(enriched);
      Navigator.pop(context); // back to profile
    }
  }

  @override
  Widget build(BuildContext context) {
    final catTitleAr = widget.selectedCategory['titleAr'] as String? ?? '';
    final catTitleEn = widget.selectedCategory['titleEn'] as String? ?? '';
    final catIcon = widget.selectedCategory['icon'] as IconData? ?? Icons.handyman;
    final catTitle = _isArabic ? catTitleAr : catTitleEn;

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              _isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('تفاصيل الحرفة الجديدة', 'New Craft Details'),
            style: GoogleFonts.cairo(
                color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isArabic = !_isArabic);
                widget.onToggleLanguage();
              },
              child: Text(
                _isArabic ? 'EN' : 'عربي',
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Craft header card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gold.withValues(alpha: 0.12),
                        border: Border.all(color: gold.withValues(alpha: 0.4)),
                      ),
                      child: Icon(catIcon, color: gold, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catTitle,
                            style: GoogleFonts.cairo(
                                color: text,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            t('أجب على الأسئلة أدناه لإضافة هذه الحرفة لملفك',
                                'Answer the questions below to add this craft'),
                            style: GoogleFonts.cairo(color: dim, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section title ──────────────────────────────────────────────
              _sectionTitle(t('تفاصيل خبرتك', 'Your Experience')),
              const SizedBox(height: 16),

              // Years of experience
              _buildField(
                controller: _experienceController,
                label: t('سنوات الخبرة في هذه الحرفة', 'Years of experience in this craft'),
                icon: Icons.history,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t('الرجاء إدخال سنوات الخبرة', 'Please enter years of experience')
                    : null,
              ),
              const SizedBox(height: 16),

              // Bio / description
              _buildField(
                controller: _bioController,
                label: t('نبذة عن أعمالك في هذه الحرفة', 'Describe your work in this craft'),
                icon: Icons.info_outline,
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t('الرجاء إضافة وصف مختصر', 'Please add a brief description')
                    : null,
              ),

              // ── Category-specific question ─────────────────────────────────
              if (_specificQuestion != null) ...[
                const SizedBox(height: 28),
                _sectionTitle(t('سؤال خاص بالحرفة', 'Craft-Specific Question')),
                const SizedBox(height: 16),
                _buildField(
                  controller: _specificController,
                  label: _isArabic
                      ? _specificQuestion!.labelAr
                      : _specificQuestion!.labelEn,
                  icon: _specificQuestion!.icon,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t('الرجاء الإجابة على هذا السؤال', 'Please answer this question')
                      : null,
                ),
              ],

              const SizedBox(height: 40),

              // ── Confirm button ─────────────────────────────────────────────
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _submit,
                  child: Text(
                    t('إضافة الحرفة', 'Add Craft'),
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: gold, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
              color: text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: text),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dim, fontSize: 14),
        prefixIcon: Icon(icon, color: dim, size: 20),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
