// lib/features/custom_order/screens/create_edit_template_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'custom_order_provider.dart';
import 'custom_order_template.dart';
import '../../services/custom_order_service.dart';

class CreateEditTemplateScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId;
  final String artisanName;
  final CustomOrderTemplate? existingTemplate;

  const CreateEditTemplateScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
    required this.artisanName,
    this.existingTemplate,
  });

  @override
  State<CreateEditTemplateScreen> createState() => _CreateEditTemplateScreenState();
}

class _CreateEditTemplateScreenState extends State<CreateEditTemplateScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _estimatedDaysController = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────
  String _selectedCategory = 'Woodwork';
  bool _isActive = true;
  List<TemplateField> _fields = [];
  bool _isSaving = false;

  // Available categories (matching the seeder)
  final List<Map<String, String>> _categories = [
    {'name': 'Textile', 'nameAr': 'منسوجات'},
    {'name': 'Woodwork', 'nameAr': 'أعمال خشبية'},
    {'name': 'Calligraphy', 'nameAr': 'خط عربي'},
    {'name': 'Jewelry', 'nameAr': 'مجوهرات'},
    {'name': 'Ceramics', 'nameAr': 'سيراميك'},
    {'name': 'Painting', 'nameAr': 'رسم'},
    {'name': 'Macrame', 'nameAr': 'ماكراميه'},
  ];

  // ── Field types for dropdown ────────────────────────────────────────────
  final List<Map<String, String>> _fieldTypes = const [
    {'type': 'text', 'labelAr': 'نص', 'labelEn': 'Text'},
    {'type': 'textarea', 'labelAr': 'نص طويل', 'labelEn': 'Text Area'},
    {'type': 'number', 'labelAr': 'رقم', 'labelEn': 'Number'},
    {'type': 'dropdown', 'labelAr': 'قائمة منسدلة', 'labelEn': 'Dropdown'},
    {'type': 'dimensions', 'labelAr': 'أبعاد (ط×ع×ار)', 'labelEn': 'Dimensions (L×W×H)'},
    {'type': 'color_picker', 'labelAr': 'اختيار لون', 'labelEn': 'Color Picker'},
    {'type': 'multi_color_picker', 'labelAr': 'ألوان متعددة', 'labelEn': 'Multi Color Picker'},
    {'type': 'checkbox_list', 'labelAr': 'قائمة خيارات', 'labelEn': 'Checklist'},
    {'type': 'range_slider', 'labelAr': 'شريط تمرير', 'labelEn': 'Range Slider'},
    {'type': 'date_picker', 'labelAr': 'اختيار تاريخ', 'labelEn': 'Date Picker'},
    {'type': 'time_picker', 'labelAr': 'اختيار وقت', 'labelEn': 'Time Picker'},
    {'type': 'file_upload', 'labelAr': 'رفع ملفات', 'labelEn': 'File Upload'},
    {'type': 'toggle', 'labelAr': 'زر تشغيل/إيقاف', 'labelEn': 'Toggle'},
    {'type': 'checkbox', 'labelAr': 'خانة اختيار', 'labelEn': 'Checkbox'},
    {'type': 'image_upload', 'labelAr': 'رفع صور', 'labelEn': 'Image Upload'},
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.existingTemplate != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final t = widget.existingTemplate!;
    _titleController.text = widget.isArabic ? t.titleAr : t.titleEn;
    _descriptionController.text = widget.isArabic ? t.descriptionAr : t.descriptionEn;
    _basePriceController.text = t.basePrice.toString();
    _estimatedDaysController.text = t.estimatedDays.toString();
    _selectedCategory = t.categoryEn;
    _isActive = t.isActive;
    _fields = List.from(t.fields);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;
  bool get isEditing => widget.existingTemplate != null;

  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg => isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  // ── Field Management ─────────────────────────────────────────────────────
  void _addField() {
    setState(() {
      _fields.add(TemplateField(
        id: 'field_${DateTime.now().millisecondsSinceEpoch}',
        type: 'text',
        labelAr: 'حقل جديد',
        labelEn: 'New Field',
        required: false,
        options: const [],
        maxImages: 3,
        maxItems: 10,
        minValue: 0,
        maxValue: 100,
        defaultValue: 50,
        checklistItems: const [],
        unit: 'cm',
      ));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  void _updateField(int index, TemplateField updated) {
    setState(() {
      _fields[index] = updated;
    });
  }

  void _moveField(int index, int direction) {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(index);
      _fields.insert(newIndex, item);
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _saveTemplate() async {
    // Validate
    if (_titleController.text.trim().isEmpty) {
      _showError(t('يرجى إدخال عنوان للقالب', 'Please enter a template title'));
      return;
    }
    if (_basePriceController.text.trim().isEmpty) {
      _showError(t('يرجى إدخال السعر الأساسي', 'Please enter the base price'));
      return;
    }
    if (_estimatedDaysController.text.trim().isEmpty) {
      _showError(t('يرجى إدخال عدد الأيام التقديرية', 'Please enter estimated days'));
      return;
    }

    final basePrice = double.tryParse(_basePriceController.text.trim());
    if (basePrice == null || basePrice < 0) {
      _showError(t('يرجى إدخال سعر صحيح', 'Please enter a valid price'));
      return;
    }
    final days = int.tryParse(_estimatedDaysController.text.trim());
    if (days == null || days < 1) {
      _showError(t('يرجى إدخال عدد أيام صحيح', 'Please enter a valid number of days'));
      return;
    }

    if (_fields.isEmpty) {
      _showError(t('يرجى إضافة حقل واحد على الأقل', 'Please add at least one field'));
      return;
    }

    setState(() => _isSaving = true);

    final category = _categories.firstWhere((c) => c['name'] == _selectedCategory);
    final categoryAr = category['nameAr'] ?? _selectedCategory;
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final fieldsJson = _fields.map((f) => f.toJson()).toList();

    bool ok = false;
    final prov = context.read<CustomOrderProvider>();

    if (isEditing) {
      ok = await CustomOrderService.updateTemplate(widget.existingTemplate!.id, {
        'titleAr': title,
        'titleEn': title,
        'descriptionAr': desc,
        'descriptionEn': desc,
        'basePrice': basePrice,
        'estimatedDays': days,
        'fields': fieldsJson,
      });
      if (ok) {
        final updated = widget.existingTemplate!.copyWith(
          titleAr: title,
          titleEn: title,
          descriptionAr: desc,
          descriptionEn: desc,
          basePrice: basePrice,
          estimatedDays: days,
          fields: _fields,
        );
        await prov.updateTemplate(updated);
      }
    } else {
      final result = await CustomOrderService.createTemplate(
        titleAr: title,
        titleEn: title,
        categoryAr: categoryAr,
        categoryEn: _selectedCategory,
        descriptionAr: desc,
        descriptionEn: desc,
        basePrice: basePrice,
        estimatedDays: days,
        fields: fieldsJson,
      );
      ok = result != null;
      if (ok) {
        final newTemplate = CustomOrderTemplate(
          id: result['id'],
          artisanId: widget.artisanId,
          artisanName: widget.artisanName,
          titleAr: title,
          titleEn: title,
          categoryAr: categoryAr,
          categoryEn: _selectedCategory,
          descriptionAr: desc,
          descriptionEn: desc,
          basePrice: basePrice,
          estimatedDays: days,
          fields: _fields,
          createdAt: DateTime.now(),
        );
        await prov.addTemplate(newTemplate);
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (isEditing
                ? t('✅ تم تحديث القالب بنجاح!', '✅ Template updated successfully!')
                : t('✅ تم إنشاء القالب بنجاح!', '✅ Template created successfully!'))
            : t('❌ فشل الحفظ، حاول مجدداً', '❌ Save failed, please try again')),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEditing ? t('تعديل القالب', 'Edit Template') : t('إنشاء قالب جديد', 'Create New Template'),
            style: GoogleFonts.arefRuqaa(color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveTemplate,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
                  : Text(
                t('حفظ', 'Save'),
                style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Basic Info ────────────────────────────────────────────────
            _buildSection(t('المعلومات الأساسية', 'Basic Information')),
            const SizedBox(height: 12),

            // Title
            _buildTextField(
              controller: _titleController,
              label: t('عنوان القالب', 'Template Title'),
              hint: t('مثال: قطعة خشبية مخصصة', 'Example: Custom Woodwork Piece'),
              required: true,
            ),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: t('الوصف', 'Description'),
              hint: t('وصف مختصر للخدمة المقدمة', 'Brief description of the service'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Category
            _buildCategoryDropdown(),
            const SizedBox(height: 16),

            // Row: Price + Days
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _basePriceController,
                    label: t('السعر الأساسي (JOD)', 'Base Price (JOD)'),
                    hint: '60',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _estimatedDaysController,
                    label: t('الأيام التقديرية', 'Estimated Days'),
                    hint: '7',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('القالب نشط', 'Template Active'),
                  style: GoogleFonts.cairo(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeThumbColor: gold,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: bord),
            const SizedBox(height: 24),

            // ── Fields Builder ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('حقول النموذج', 'Form Fields'),
                  style: GoogleFonts.arefRuqaa(color: text, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addField,
                  icon: Icon(Icons.add_circle_outline, color: gold),
                  label: Text(
                    t('إضافة حقل', 'Add Field'),
                    style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t('اسحب الحقل لترتيبه (قريباً)', 'Drag to reorder (coming soon)'),
              style: GoogleFonts.cairo(color: sub, fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bord, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_circle_outline, size: 48, color: sub),
                    const SizedBox(height: 12),
                    Text(
                      t('لا توجد حقول بعد', 'No fields yet'),
                      style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      t('اضغط على "إضافة حقل" لبدء بناء النموذج', 'Tap "Add Field" to start building your form'),
                      style: GoogleFonts.cairo(color: sub, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._fields.asMap().entries.map((entry) => _FieldBuilder(
                index: entry.key,
                field: entry.value,
                total: _fields.length,
                isArabic: isArabic,
                isDarkMode: isDarkMode,
                onUpdate: (updated) => _updateField(entry.key, updated),
                onDelete: () => _removeField(entry.key),
                onMoveUp: () => _moveField(entry.key, -1),
                onMoveDown: () => _moveField(entry.key, 1),
              )),

            const SizedBox(height: 32),

            // ── Save Button (Bottom) ──────────────────────────────────────
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isSaving ? null : _saveTemplate,
                child: _isSaving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                )
                    : Text(
                  isEditing ? t('تحديث القالب', 'Update Template') : t('إنشاء القالب', 'Create Template'),
                  style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildSection(String title) => Text(
    title,
    style: GoogleFonts.arefRuqaa(color: text, fontSize: 18, fontWeight: FontWeight.bold),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: GoogleFonts.cairo(color: sub, fontSize: 12, fontWeight: FontWeight.w600)),
              if (required) Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.cairo(color: text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
              filled: true,
              fillColor: surf,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: bord),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: gold, width: 2),
              ),
            ),
          ),
        ],
      );

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('الفئة', 'Category'), style: GoogleFonts.cairo(color: sub, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bord),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: surf,
              style: GoogleFonts.cairo(color: text),
              items: _categories.map((cat) {
                final label = isArabic ? cat['nameAr']! : cat['name']!;
                return DropdownMenuItem(value: cat['name'], child: Text(label));
              }).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Builder Widget (with all new field types)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldBuilder extends StatefulWidget {
  final int index;
  final TemplateField field;
  final int total;
  final bool isArabic;
  final bool isDarkMode;
  final Function(TemplateField) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _FieldBuilder({
    required this.index,
    required this.field,
    required this.total,
    required this.isArabic,
    required this.isDarkMode,
    required this.onUpdate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_FieldBuilder> createState() => _FieldBuilderState();
}

class _FieldBuilderState extends State<_FieldBuilder> {
  late TextEditingController _labelController;
  late TextEditingController _optionsController;
  late TextEditingController _checklistController;
  late TextEditingController _unitController;
  late String _selectedType;
  late bool _isRequired;
  late int _maxImages;
  late int _maxItems;
  late double _minValue;
  late double _maxValue;
  late double _defaultValue;
  late List<String> _checklistItems;

  final List<String> _fieldTypes = [
    'text', 'textarea', 'number', 'dropdown', 'dimensions', 'color_picker',
    'multi_color_picker', 'checkbox_list', 'range_slider', 'date_picker',
    'time_picker', 'file_upload', 'toggle', 'checkbox', 'image_upload'
  ];

  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;

  String t(String ar, String en) => isArabic ? ar : en;

  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: isArabic ? widget.field.labelAr : widget.field.labelEn);
    _selectedType = widget.field.type;
    _isRequired = widget.field.required;
    _maxImages = widget.field.maxImages;
    _maxItems = widget.field.maxItems;
    _minValue = widget.field.minValue;
    _maxValue = widget.field.maxValue;
    _defaultValue = widget.field.defaultValue;
    _checklistItems = List.from(widget.field.checklistItems);
    _optionsController = TextEditingController(text: widget.field.options.join(', '));
    _checklistController = TextEditingController(text: _checklistItems.join(', '));
    _unitController = TextEditingController(text: widget.field.unit);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _optionsController.dispose();
    _checklistController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _updateChecklistItems() {
    _checklistItems = _checklistController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _notifyUpdate();
  }

  void _notifyUpdate() {
    final label = _labelController.text.trim();
    widget.onUpdate(TemplateField(
      id: widget.field.id,
      type: _selectedType,
      labelAr: isArabic ? label : widget.field.labelAr,
      labelEn: isArabic ? widget.field.labelEn : label,
      required: _isRequired,
      options: _optionsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      maxImages: _maxImages,
      maxItems: _maxItems,
      minValue: _minValue,
      maxValue: _maxValue,
      defaultValue: _defaultValue,
      checklistItems: _checklistItems,
      unit: _unitController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _fieldTypeDisplay(_selectedType);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Field number + controls ────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${widget.index + 1}',
                  style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sub.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ),
              const Spacer(),
              // Move buttons
              IconButton(
                icon: Icon(Icons.arrow_upward, size: 16, color: sub),
                onPressed: widget.index > 0 ? widget.onMoveUp : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.arrow_downward, size: 16, color: sub),
                onPressed: widget.index < widget.total - 1 ? widget.onMoveDown : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.redAccent),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Field Label ─────────────────────────────────────────────────
          TextField(
            controller: _labelController,
            onChanged: (_) => _notifyUpdate(),
            style: GoogleFonts.cairo(color: text),
            decoration: InputDecoration(
              hintText: t('اسم الحقل', 'Field Label'),
              hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.5)),
              filled: true,
              fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: bord),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: gold, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Row: Type dropdown + Required checkbox ─────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bord),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      dropdownColor: surf,
                      style: GoogleFonts.cairo(color: text, fontSize: 13),
                      items: _fieldTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_fieldTypeDisplay(type)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedType = v!;
                          // Reset options if switching away from dropdown
                          if (v != 'dropdown') _optionsController.text = '';
                        });
                        _notifyUpdate();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  Checkbox(
                    value: _isRequired,
                    onChanged: (v) {
                      setState(() => _isRequired = v!);
                      _notifyUpdate();
                    },
                    activeColor: gold,
                    checkColor: Colors.black,
                  ),
                  Text(
                    t('إلزامي', 'Required'),
                    style: GoogleFonts.cairo(color: sub, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Options (if dropdown) ──────────────────────────────────────
          if (_selectedType == 'dropdown')
            TextField(
              controller: _optionsController,
              onChanged: (_) => _notifyUpdate(),
              style: GoogleFonts.cairo(color: text),
              decoration: InputDecoration(
                hintText: t('خيارات (مفصولة بفاصلة)', 'Options (comma separated)'),
                hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.5)),
                filled: true,
                fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: bord),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: gold, width: 2),
                ),
              ),
            ),

          // ── Checklist Items (if checkbox_list) ──────────────────────
          if (_selectedType == 'checkbox_list')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _checklistController,
                  onChanged: (_) => _updateChecklistItems(),
                  style: GoogleFonts.cairo(color: text),
                  decoration: InputDecoration(
                    hintText: t('عناصر (مفصولة بفاصلة)', 'Items (comma separated)'),
                    hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: bord),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: gold, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _checklistItems.map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gold.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.cairo(color: gold, fontSize: 11),
                    ),
                  )).toList(),
                ),
              ],
            ),

          // ── Max Items (if multi_color_picker) ──────────────────────
          if (_selectedType == 'multi_color_picker')
            Row(
              children: [
                Text(
                  t('الحد الأقصى للألوان:', 'Max colors:'),
                  style: GoogleFonts.cairo(color: sub, fontSize: 13),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _maxItems,
                      dropdownColor: surf,
                      style: GoogleFonts.cairo(color: text),
                      items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) {
                        return DropdownMenuItem(value: i, child: Text('$i'));
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _maxItems = v!);
                        _notifyUpdate();
                      },
                    ),
                  ),
                ),
              ],
            ),

          // ── Range Slider Config ──────────────────────────────────────
          if (_selectedType == 'range_slider')
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildRangeInput(
                        label: t('الحد الأدنى', 'Min'),
                        value: _minValue,
                        onChanged: (v) { setState(() => _minValue = v); _notifyUpdate(); },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRangeInput(
                        label: t('الحد الأقصى', 'Max'),
                        value: _maxValue,
                        onChanged: (v) { setState(() => _maxValue = v); _notifyUpdate(); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildRangeInput(
                  label: t('القيمة الافتراضية', 'Default'),
                  value: _defaultValue,
                  onChanged: (v) { setState(() => _defaultValue = v); _notifyUpdate(); },
                ),
              ],
            ),

          // ── Unit (for dimensions) ───────────────────────────────────
          if (_selectedType == 'dimensions')
            Row(
              children: [
                Text(
                  t('وحدة القياس:', 'Unit:'),
                  style: GoogleFonts.cairo(color: sub, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unitController.text,
                      dropdownColor: surf,
                      style: GoogleFonts.cairo(color: text),
                      items: ['cm', 'mm', 'inches', 'meter'].map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _unitController.text = v!);
                        _notifyUpdate();
                      },
                    ),
                  ),
                ),
              ],
            ),

          // ── Max Images (if image_upload) ──────────────────────────────
          if (_selectedType == 'image_upload')
            Row(
              children: [
                Text(
                  t('الحد الأقصى للصور:', 'Max images:'),
                  style: GoogleFonts.cairo(color: sub, fontSize: 13),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _maxImages,
                      dropdownColor: surf,
                      style: GoogleFonts.cairo(color: text),
                      items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) {
                        return DropdownMenuItem(value: i, child: Text('$i'));
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _maxImages = v!);
                        _notifyUpdate();
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRangeInput({
    required String label,
    required double value,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: sub, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0,
                max: 1000,
                divisions: 100,
                activeColor: gold,
                inactiveColor: bord,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: bord),
              ),
              child: Text(
                value.toInt().toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: text, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fieldTypeDisplay(String type) {
    final map = {
      'text': isArabic ? 'نص' : 'Text',
      'textarea': isArabic ? 'نص طويل' : 'Text Area',
      'number': isArabic ? 'رقم' : 'Number',
      'dropdown': isArabic ? 'قائمة' : 'Dropdown',
      'dimensions': isArabic ? 'أبعاد' : 'Dimensions',
      'color_picker': isArabic ? 'لون' : 'Color',
      'multi_color_picker': isArabic ? 'ألوان متعددة' : 'Multi Color',
      'checkbox_list': isArabic ? 'قائمة خيارات' : 'Checklist',
      'range_slider': isArabic ? 'شريط تمرير' : 'Range Slider',
      'date_picker': isArabic ? 'تاريخ' : 'Date',
      'time_picker': isArabic ? 'وقت' : 'Time',
      'file_upload': isArabic ? 'ملفات' : 'Files',
      'toggle': isArabic ? 'تشغيل/إيقاف' : 'Toggle',
      'checkbox': isArabic ? 'خانة' : 'Checkbox',
      'image_upload': isArabic ? 'صور' : 'Images',
    };
    return map[type] ?? type;
  }
}
