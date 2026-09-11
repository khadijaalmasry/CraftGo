// ============================================================
// BrowseTemplatesScreen — Customer browses artisan's templates
// Called from: ArtisanProfilePage (tap "Custom Order" button)
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'custom_order_provider.dart';
import 'custom_order_template.dart';
import 'custom_order_form_screen.dart';

class BrowseTemplatesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String? artisanId;
  final String? artisanName;

  const BrowseTemplatesScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.artisanId,
    this.artisanName,
  });

  @override
  State<BrowseTemplatesScreen> createState() =>
      _BrowseTemplatesScreenState();
}

class _BrowseTemplatesScreenState extends State<BrowseTemplatesScreen> {
  String t(String ar, String en) => widget.isArabic ? ar : en;

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get surf =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color get text =>
      widget.isDarkMode ? Colors.white : Colors.black87;

  Color get sub =>
      widget.isDarkMode ? Colors.white60 : Colors.black54;

  Color get gold => const Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.artisanId;

      if (id != null && id.trim().isNotEmpty) {
        context
            .read<CustomOrderProvider>()
            .loadTemplatesForArtisan(id);
      }
    });
  }

  Future<void> _reload() async {
    final id = widget.artisanId;

    if (id != null && id.trim().isNotEmpty) {
      await context
          .read<CustomOrderProvider>()
          .loadTemplatesForArtisan(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CustomOrderProvider>();

    final templates = widget.artisanId != null
        ? prov.templatesFor(widget.artisanId!)
        : prov.templates;

    return Directionality(
      textDirection:
      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic
                  ? Icons.arrow_forward_ios
                  : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.artisanName != null
                ? t(
              'قوالب ${widget.artisanName}',
              "${widget.artisanName}'s Templates",
            )
                : t(
              'الطلبات المخصصة',
              'Custom Order Templates',
            ),
            style: GoogleFonts.arefRuqaa(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: prov.isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4A017),
          ),
        )
            : RefreshIndicator(
          onRefresh: _reload,
          color: gold,
          child: templates.isEmpty
              ? ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height:
                MediaQuery.of(context).size.height * 0.68,
                child: _emptyState(),
              ),
            ],
          )
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            physics:
            const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: templates.length,
            itemBuilder: (_, i) => _TemplateCard(
              template: templates[i],
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomOrderFormScreen(
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                        template: templates[i],
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.palette_outlined,
          size: 64,
          color: sub,
        ),
        const SizedBox(height: 16),
        Text(
          t(
            'لا توجد قوالب متاحة',
            'No templates available',
          ),
          style: TextStyle(
            color: sub,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'لم ينشئ هذا الحرفي أي قوالب بعد',
            "This artisan hasn't created any templates yet",
          ),
          style: TextStyle(
            color: sub,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  final CustomOrderTemplate template;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isArabic,
    required this.isDarkMode,
    required this.onTap,
  });

  String t(String ar, String en) => isArabic ? ar : en;
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bord),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.palette_outlined, color: gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? template.titleAr : template.titleEn,
                        style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isArabic ? template.categoryAr : template.categoryEn,
                        style: GoogleFonts.cairo(
                          color: gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isArabic ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                  color: sub,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? template.descriptionAr : template.descriptionEn,
              style: GoogleFonts.cairo(color: sub, fontSize: 13, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _chip(Icons.attach_money, '${t('من', 'From')} ${template.basePrice.toStringAsFixed(0)} JOD'),
                const SizedBox(width: 10),
                _chip(Icons.schedule_outlined, '${template.estimatedDays} ${t('أيام', 'days')}'),
                const SizedBox(width: 10),
                _chip(Icons.list_alt_outlined, '${template.fields.length} ${t('حقل', 'fields')}'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                t('اطلب الآن', 'Request Now'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: gold),
      const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.cairo(color: sub, fontSize: 11.5),
      ),
    ],
  );
}

// // lib/browse_templates_screen.dart
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import '../../providers/custom_order_provider.dart';
// import 'models/custom_order_template.dart';
// import 'custom_order_form_screen.dart';
//
// class BrowseTemplatesScreen extends StatelessWidget {
//   final bool isArabic;
//   final bool isDarkMode;
//   // If supplied, only show templates from this artisan
//   final String? artisanId;
//   final String? artisanName;
//
//   const BrowseTemplatesScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//     this.artisanId,
//     this.artisanName,
//   });
//
//   String t(String ar, String en) => isArabic ? ar : en;
//
//   Color get bg    => isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get surf  => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text  => isDarkMode ? Colors.white : Colors.black87;
//   Color get sub   => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get bord  => isDarkMode ? Colors.white12 : Colors.black12;
//   Color get gold  => const Color(0xFFD4A017);
//
//   @override
//   Widget build(BuildContext context) {
//     final prov = context.watch<CustomOrderProvider>();
//     final templates = artisanId != null
//         ? prov.templatesFor(artisanId!)
//         : prov.templates;
//
//     return Directionality(
//       textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: bg,
//           elevation: 0,
//           title: Text(
//             artisanName != null
//                 ? t('قوالب $artisanName', '$artisanName\'s Templates')
//                 : t('الطلبات المخصصة', 'Custom Order Templates'),
//             style: GoogleFonts.arefRuqaa(color: text, fontWeight: FontWeight.bold, fontSize: 18),
//           ),
//           leading: IconButton(
//             icon: Icon(isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text),
//             onPressed: () => Navigator.pop(context),
//           ),
//         ),
//         body: prov.isLoading
//             ? Center(child: CircularProgressIndicator(color: gold))
//             : templates.isEmpty
//                 ? _emptyState(context)
//                 : ListView.builder(
//                     padding: const EdgeInsets.all(20),
//                     physics: const BouncingScrollPhysics(),
//                     itemCount: templates.length,
//                     itemBuilder: (_, i) => _TemplateCard(
//                       template: templates[i],
//                       isArabic: isArabic,
//                       isDarkMode: isDarkMode,
//                       onTap: () => Navigator.push(context, MaterialPageRoute(
//                         builder: (_) => CustomOrderFormScreen(
//                           isArabic: isArabic,
//                           isDarkMode: isDarkMode,
//                           template: templates[i],
//                         ),
//                       )),
//                     ),
//                   ),
//       ),
//     );
//   }
//
//   Widget _emptyState(BuildContext context) => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(Icons.palette_outlined, size: 64, color: sub),
//         const SizedBox(height: 16),
//         Text(t('لا توجد قوالب متاحة', 'No templates available'),
//             style: TextStyle(color: sub, fontSize: 16)),
//       ],
//     ),
//   );
// }
//
// class _TemplateCard extends StatelessWidget {
//   final CustomOrderTemplate template;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onTap;
//
//   const _TemplateCard({
//     required this.template,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onTap,
//   });
//
//   String t(String ar, String en) => isArabic ? ar : en;
//   Color get surf  => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text  => isDarkMode ? Colors.white : Colors.black87;
//   Color get sub   => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get bord  => isDarkMode ? Colors.white12 : Colors.black12;
//   Color get gold  => const Color(0xFFD4A017);
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 16),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: surf,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: bord),
//           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: gold.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(Icons.palette_outlined, color: gold, size: 22),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(isArabic ? template.titleAr : template.titleEn,
//                           style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 15)),
//                       Text(isArabic ? template.categoryAr : template.categoryEn,
//                           style: GoogleFonts.cairo(color: gold, fontSize: 12, fontWeight: FontWeight.w600)),
//                     ],
//                   ),
//                 ),
//                 Icon(isArabic ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
//                     color: sub, size: 16),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Text(isArabic ? template.descriptionAr : template.descriptionEn,
//                 style: GoogleFonts.cairo(color: sub, fontSize: 13, height: 1.5), maxLines: 2,
//                 overflow: TextOverflow.ellipsis),
//             const SizedBox(height: 14),
//             Row(
//               children: [
//                 _chip(Icons.attach_money, '${t('من', 'From')} ${template.basePrice.toStringAsFixed(0)} JOD'),
//                 const SizedBox(width: 10),
//                 _chip(Icons.schedule_outlined, '${template.estimatedDays} ${t('أيام', 'days')}'),
//                 const SizedBox(width: 10),
//                 _chip(Icons.list_alt_outlined, '${template.fields.length} ${t('حقل', 'fields')}'),
//               ],
//             ),
//             const SizedBox(height: 14),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               child: Text(t('اطلب الآن', 'Request Now'),
//                   textAlign: TextAlign.center,
//                   style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _chip(IconData icon, String label) => Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       Icon(icon, size: 13, color: gold),
//       const SizedBox(width: 4),
//       Text(label, style: GoogleFonts.cairo(color: sub, fontSize: 11.5)),
//     ],
//   );
// }
