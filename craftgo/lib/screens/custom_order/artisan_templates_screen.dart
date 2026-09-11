// lib/features/custom_order/screens/artisan_templates_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'custom_order_provider.dart';
import 'custom_order_template.dart';
import 'create_edit_template_screen.dart';
import '../../services/custom_order_service.dart';

class ArtisanTemplatesScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId;
  final bool hideDeleteAll;

  const ArtisanTemplatesScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
    this.hideDeleteAll = false, // default false so it shows in other contexts
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CustomOrderProvider>();
    final templates = prov.templatesFor(artisanId);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            t('قوالب الطلبات المخصصة', 'Custom Order Templates'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Only show delete all if not hidden AND there are templates
            if (!hideDeleteAll && templates.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _showDeleteAllConfirmation(context, prov),
                tooltip: t('حذف الكل', 'Delete All'),
              ),
          ],
        ),
        body: templates.isEmpty
            ? _emptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: templates.length,
                itemBuilder: (_, i) => _TemplateCard(
                  template: templates[i],
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                  onEdit: () => _navigateToEdit(context, templates[i]),
                  onDelete: () =>
                      _showDeleteConfirmation(context, prov, templates[i].id),
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToCreate(context),
          backgroundColor: gold,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, size: 64, color: sub),
            const SizedBox(height: 16),
            Text(
              t('لا توجد قوالب', 'No templates'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('أنشئ قالباً جديداً لبدء استقبال الطلبات',
                  'Create a new template to start receiving orders'),
              style: GoogleFonts.cairo(color: sub, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreate(context),
              icon: const Icon(Icons.add, color: Colors.black),
              label: Text(
                t('إنشاء قالب', 'Create Template'),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: gold),
            ),
          ],
        ),
      );

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEditTemplateScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          artisanId: artisanId,
          artisanName: 'أمجد الخطيب', // TODO: Replace with actual artisan name
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, CustomOrderTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEditTemplateScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          artisanId: artisanId,
          artisanName: 'أمجد الخطيب',
          existingTemplate: template,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, CustomOrderProvider prov, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        title: Text(
          t('حذف القالب؟', 'Delete template?'),
          style: TextStyle(color: text),
        ),
        content: Text(
          t('هل أنت متأكد من رغبتك في حذف هذا القالب؟',
              'Are you sure you want to delete this template?'),
          style: TextStyle(color: sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: sub)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await CustomOrderService.deleteTemplate(id);
              if (ok) {
                prov.deleteTemplate(id);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t('❌ فشل الحذف', '❌ Delete failed')),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: Text(t('حذف', 'Delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation(
      BuildContext context, CustomOrderProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        title: Text(
          t('حذف جميع القوالب؟', 'Delete all templates?'),
          style: TextStyle(color: text),
        ),
        content: Text(
          t('سيتم حذف جميع القوالب نهائياً. هل أنت متأكد؟',
              'All templates will be permanently deleted. Are you sure?'),
          style: TextStyle(color: sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: sub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Delete all templates for this artisan
              final templates = prov.templatesFor(artisanId);
              for (final t in templates) {
                prov.deleteTemplate(t.id);
              }
            },
            child: Text(t('حذف الكل', 'Delete All'),
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Template Card Widget ────────────────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final CustomOrderTemplate template;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.isArabic,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  String t(String ar, String en) => isArabic ? ar : en;
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bord),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? template.titleAr : template.titleEn,
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: template.isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: template.isActive ? Colors.green : Colors.red,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  template.isActive
                      ? t('نشط', 'Active')
                      : t('غير نشط', 'Inactive'),
                  style: GoogleFonts.cairo(
                    color: template.isActive ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? template.descriptionAr : template.descriptionEn,
            style: GoogleFonts.cairo(color: sub, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _chip(Icons.attach_money,
                      '${template.basePrice.toStringAsFixed(0)} JOD'),
                  const SizedBox(width: 8),
                  _chip(Icons.schedule_outlined,
                      '${template.estimatedDays} ${t('أيام', 'days')}'),
                  const SizedBox(width: 8),
                  _chip(Icons.list_alt_outlined,
                      '${template.fields.length} ${t('حقل', 'fields')}'),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: gold, size: 18),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 18),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: gold),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(color: sub, fontSize: 11)),
        ],
      );
}
