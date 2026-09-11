// lib/features/custom_order/screens/custom_order_form_screen.dart
// ============================================================
// CustomOrderFormScreen — Customer fills the template
// Called from: BrowseTemplatesScreen (tap a template)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_order_template.dart';
import 'review_send_screen.dart';

class CustomOrderFormScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final CustomOrderTemplate template;

  const CustomOrderFormScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.template,
  });

  @override
  State<CustomOrderFormScreen> createState() => _CustomOrderFormScreenState();
}

class _CustomOrderFormScreenState extends State<CustomOrderFormScreen> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;
  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg => isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  TextEditingController _ctrl(String id) {
    return _controllers.putIfAbsent(id, () => TextEditingController());
  }

  bool _validate() {
    for (final field in widget.template.fields) {
      if (!field.required) continue;
      final val = _values[field.id];
      if (val == null || val.toString().trim().isEmpty) return false;
      // For multi_color_picker, check if list is not empty
      if (field.type == 'multi_color_picker' && val is List && val.isEmpty) return false;
      // For checkbox_list, check if any item selected
      if (field.type == 'checkbox_list' && val is Map && val.isEmpty) return false;
    }
    return true;
  }

  void _proceed() {
    // Sync text controllers into _values
    for (final entry in _controllers.entries) {
      if (_controllers[entry.key]!.text.trim().isNotEmpty) {
        _values[entry.key] = entry.value.text.trim();
      }
    }
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى ملء الحقول الإلزامية', 'Please fill all required fields')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSendScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          template: widget.template,
          filledFields: Map<String, dynamic>.from(_values),
        ),
      ),
    );
  }

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
            isArabic ? widget.template.titleAr : widget.template.titleEn,
            style: GoogleFonts.arefRuqaa(color: text, fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          physics: const BouncingScrollPhysics(),
          children: [
            _headerCard(),
            const SizedBox(height: 24),
            Text(
              t('تفاصيل الطلب', 'Order Details'),
              style: GoogleFonts.arefRuqaa(color: text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              t('الحقول المميزة بـ * إلزامية', 'Fields marked * are required'),
              style: GoogleFonts.cairo(color: sub, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...widget.template.fields.map((f) => _buildField(f)),
          ],
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _headerCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gold.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: gold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('الحرفي:', 'Artisan:'),
                style: GoogleFonts.cairo(color: sub, fontSize: 11),
              ),
              Text(
                widget.template.artisanName,
                style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '${t('من', 'From')} ${widget.template.basePrice.toStringAsFixed(0)} JOD • '
                    '${widget.template.estimatedDays} ${t('أيام تقريباً', 'days estimate')}',
                style: GoogleFonts.cairo(color: gold, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildField(TemplateField field) {
    final label = isArabic ? field.labelAr : field.labelEn;
    final required = field.required;

    Widget fieldWidget;
    switch (field.type) {
      case 'text':
        fieldWidget = _textField(field.id, label, maxLines: 1);
        break;
      case 'textarea':
        fieldWidget = _textField(field.id, label, maxLines: 4);
        break;
      case 'number':
        fieldWidget = _textField(field.id, label, maxLines: 1, inputType: TextInputType.number);
        break;
      case 'dropdown':
        fieldWidget = _dropdownField(field.id, label, field.options);
        break;
      case 'dimensions':
        fieldWidget = _dimensionsField(field.id, label, unit: field.unit);
        break;
      case 'color_picker':
        fieldWidget = _colorField(field.id, label, maxColors: 1);
        break;
      case 'multi_color_picker':
        fieldWidget = _multiColorPicker(field.id, label, maxColors: field.maxItems);
        break;
      case 'checkbox_list':
        fieldWidget = _checkboxListField(field.id, label, field.checklistItems);
        break;
      case 'range_slider':
        fieldWidget = _rangeSliderField(field.id, label, field.minValue, field.maxValue, field.defaultValue);
        break;
      case 'date_picker':
        fieldWidget = _datePickerField(field.id, label);
        break;
      case 'time_picker':
        fieldWidget = _timePickerField(field.id, label);
        break;
      case 'file_upload':
        fieldWidget = _fileUploadField(field.id, label);
        break;
      case 'toggle':
        fieldWidget = _toggleField(field.id, label);
        break;
      case 'checkbox':
        fieldWidget = _checkboxField(field.id, label);
        break;
      case 'image_upload':
        fieldWidget = _imageUploadField(field.id, label, field.maxImages);
        break;
      default:
        fieldWidget = _textField(field.id, label, maxLines: 1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (required) Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          fieldWidget,
        ],
      ),
    );
  }

  // ── Basic Text Field ──────────────────────────────────────────────────────
  Widget _textField(String id, String hint, {int maxLines = 1, TextInputType? inputType}) =>
      TextFormField(
        controller: _ctrl(id),
        maxLines: maxLines,
        keyboardType: inputType,
        style: GoogleFonts.cairo(color: text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
          filled: true,
          fillColor: surf,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: bord),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: gold, width: 2),
          ),
        ),
      );

  // ── Dropdown ──────────────────────────────────────────────────────────────
  Widget _dropdownField(String id, String label, List<String> options) {
    final current = _values[id] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bord),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(current) ? current : null,
          hint: Text(label, style: GoogleFonts.cairo(color: sub)),
          dropdownColor: surf,
          isExpanded: true,
          style: GoogleFonts.cairo(color: text),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o, style: GoogleFonts.cairo(color: text, fontSize: 14)),
          )).toList(),
          onChanged: (v) => setState(() => _values[id] = v),
        ),
      ),
    );
  }

  // ── Dimensions (with unit) ──────────────────────────────────────────────
  Widget _dimensionsField(String id, String label, {String unit = 'cm'}) {
    final parts = (_values[id] as String? ?? '').split('×');
    final l = _controllers.putIfAbsent('${id}_l', () => TextEditingController(text: parts.isNotEmpty ? parts[0].trim() : ''));
    final w = _controllers.putIfAbsent('${id}_w', () => TextEditingController(text: parts.length > 1 ? parts[1].trim() : ''));
    final h = _controllers.putIfAbsent('${id}_h', () => TextEditingController(text: parts.length > 2 ? parts[2].trim() : ''));

    void update() {
      _values[id] = '${l.text} × ${w.text} × ${h.text} $unit';
    }

    InputDecoration dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cairo(color: sub),
      filled: true,
      fillColor: surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bord),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold, width: 2),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: TextFormField(
              controller: l,
              onChanged: (_) => update(),
              style: GoogleFonts.cairo(color: text),
              keyboardType: TextInputType.number,
              decoration: dec(t('ط (سم)', 'L (cm)')),
            )),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('×', style: TextStyle(color: sub, fontSize: 18))),
            Expanded(child: TextFormField(
              controller: w,
              onChanged: (_) => update(),
              style: GoogleFonts.cairo(color: text),
              keyboardType: TextInputType.number,
              decoration: dec(t('ع (سم)', 'W (cm)')),
            )),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('×', style: TextStyle(color: sub, fontSize: 18))),
            Expanded(child: TextFormField(
              controller: h,
              onChanged: (_) => update(),
              style: GoogleFonts.cairo(color: text),
              keyboardType: TextInputType.number,
              decoration: dec(t('ار (سم)', 'H (cm)')),
            )),
          ],
        ),
        Text(
          '${t('وحدة القياس:', 'Unit:')} $unit',
          style: GoogleFonts.cairo(color: sub, fontSize: 11),
        ),
      ],
    );
  }

  // ── Single Color Picker ──────────────────────────────────────────────────
  // ── Single Color Picker ──────────────────────────────────────────────────
  Widget _colorField(String id, String label, {int maxColors = 1}) {
    final selected = _values[id] as Color?;
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: surf,
            title: Text(t('اختر لوناً', 'Pick a color'), style: TextStyle(color: text)),
            content: ColorPicker(
              pickerColor: selected ?? Colors.amber,
              onColorChanged: (color) => setState(() => _values[id] = color),
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: sub)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('اختيار', 'Select'), style: TextStyle(color: gold)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ?? Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bord),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              selected != null ? t('تم اختيار لون', 'Color selected') : t('اختر لوناً', 'Pick a color'),
              style: TextStyle(color: selected != null ? text : sub),
            ),
          ],
        ),
      ),
    );
  }

  // ── Multi Color Picker ───────────────────────────────────────────────────
  // ── Multi Color Picker ───────────────────────────────────────────────────
  Widget _multiColorPicker(String id, String label, {int maxColors = 10}) {
    final selectedColors = (_values[id] as List<String>?) ?? [];

    void addColor() {
      if (selectedColors.length >= maxColors) {
        _showSnack(t('الحد الأقصى $maxColors ألوان', 'Maximum $maxColors colors'));
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surf,
          title: Text(t('اختر لوناً', 'Pick a color'), style: TextStyle(color: text)),
          content: ColorPicker(
            pickerColor: Colors.amber,
            onColorChanged: (color) {
              final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
              setState(() {
                _values[id] = [...selectedColors, hex];
              });
              Navigator.pop(ctx);
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: sub)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...selectedColors.map((hex) => Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      final list = List<String>.from(selectedColors)..remove(hex);
                      _values[id] = list;
                    }),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            )),
            if (selectedColors.length < maxColors)
              GestureDetector(
                onTap: addColor,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord, style: BorderStyle.solid),
                  ),
                  child: Icon(Icons.add, color: gold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${selectedColors.length}/$maxColors ${t('لون', 'colors')}',
          style: GoogleFonts.cairo(color: sub, fontSize: 11),
        ),
      ],
    );
  }

  // ── Checklist Field ─────────────────────────────────────────────────────
  Widget _checkboxListField(String id, String label, List<String> items) {
    final selected = (_values[id] as Map<String, int>?) ?? {};

    return Column(
      children: items.map((item) {
        final quantity = selected[item] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bord),
          ),
          child: Row(
            children: [
              Checkbox(
                value: quantity > 0,
                onChanged: (v) {
                  setState(() {
                    final copy = Map<String, int>.from(selected);
                    if (v == true) {
                      copy[item] = (copy[item] ?? 0) + 1;
                    } else {
                      copy.remove(item);
                    }
                    _values[id] = copy;
                  });
                },
                activeColor: gold,
                checkColor: Colors.black,
              ),
              Expanded(
                child: Text(item, style: GoogleFonts.cairo(color: text, fontSize: 13)),
              ),
              if (quantity > 0)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: 16, color: sub),
                      onPressed: () {
                        setState(() {
                          final copy = Map<String, int>.from(selected);
                          if (copy[item]! > 1) {
                            copy[item] = copy[item]! - 1;
                          } else {
                            copy.remove(item);
                          }
                          _values[id] = copy;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    Text('$quantity', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add, size: 16, color: sub),
                      onPressed: () {
                        setState(() {
                          final copy = Map<String, int>.from(selected);
                          copy[item] = (copy[item] ?? 0) + 1;
                          _values[id] = copy;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Range Slider Field ─────────────────────────────────────────────────
  Widget _rangeSliderField(String id, String label, double min, double max, double defaultValue) {
    final value = (_values[id] as double?) ?? defaultValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$min', style: TextStyle(color: sub, fontSize: 12)),
            Text(
              value.toInt().toString(),
              style: TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('$max', style: TextStyle(color: sub, fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 100,
          activeColor: gold,
          inactiveColor: bord,
          onChanged: (v) => setState(() => _values[id] = v),
        ),
      ],
    );
  }

  // ── Date Picker Field ──────────────────────────────────────────────────
  Widget _datePickerField(String id, String label) {
    final selected = _values[id] as DateTime?;

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xFFD4A017)),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _values[id] = date);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected != null
                    ? '${selected.day}/${selected.month}/${selected.year}'
                    : t('اختر تاريخاً', 'Select date'),
                style: TextStyle(
                  color: selected != null ? text : sub,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Time Picker Field ──────────────────────────────────────────────────
  Widget _timePickerField(String id, String label) {
    final selected = _values[id] as TimeOfDay?;

    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: selected ?? TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xFFD4A017)),
            ),
            child: child!,
          ),
        );
        if (time != null) setState(() => _values[id] = time);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected != null
                    ? selected.format(context)
                    : t('اختر وقتاً', 'Select time'),
                style: TextStyle(
                  color: selected != null ? text : sub,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── File Upload Field ──────────────────────────────────────────────────
  Widget _fileUploadField(String id, String label) {
    final files = (_values[id] as List<String>?) ?? [];

    return GestureDetector(
      onTap: () {
        // Mock file upload (replace with actual file picker)
        setState(() {
          _values[id] = [...files, 'file_${files.length + 1}.pdf'];
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            if (files.isEmpty)
              Column(
                children: [
                  Icon(Icons.attach_file, color: gold, size: 36),
                  const SizedBox(height: 8),
                  Text(t('اضغط لرفع ملف', 'Tap to upload file'), style: TextStyle(color: sub)),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: files.map((file) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: Color(0xFFD4A017), size: 16),
                      const SizedBox(width: 6),
                      Text(file, style: TextStyle(color: text, fontSize: 12)),
                      GestureDetector(
                        onTap: () {
                          final list = List<String>.from(files)..remove(file);
                          setState(() => _values[id] = list);
                        },
                        child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                      ),
                    ],
                  ),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ── Toggle Field ──────────────────────────────────────────────────────
  Widget _toggleField(String id, String label) {
    final value = _values[id] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bord),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: text, fontSize: 14)),
          Switch(
            value: value,
            onChanged: (v) => setState(() => _values[id] = v),
            activeThumbColor: gold,
          ),
        ],
      ),
    );
  }

  // ── Checkbox (single) ──────────────────────────────────────────────────
  Widget _checkboxField(String id, String label) {
    final val = _values[id] as bool? ?? false;
    return GestureDetector(
      onTap: () => setState(() => _values[id] = !val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: val ? gold : bord),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: val ? gold : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: val ? gold : sub, width: 2),
              ),
              child: val ? const Icon(Icons.check, color: Colors.black, size: 14) : null,
            ),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.cairo(color: text, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Image Upload Field + Canvas Sketch Option ────────────────────────────
  Widget _imageUploadField(String id, String label, int max) {
    final images = _values[id] as List<String>? ?? [];
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (images.length < max) {
                _values[id] = [...images, 'reference_photo_${images.length + 1}.jpg'];
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: bord, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                if (images.isEmpty) ...[
                  Icon(Icons.add_photo_alternate_outlined, color: gold, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    t('اضغط لإضافة صورة مرجعية', 'Tap to add reference image'),
                    style: GoogleFonts.cairo(color: sub, fontSize: 13),
                  ),
                  Text(
                    t('(حتى $max صور)', '(up to $max images)'),
                    style: GoogleFonts.cairo(color: sub, fontSize: 11),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...images.map((img) => Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: gold.withValues(alpha: 0.3)),
                            ),
                            child: Icon(
                              img.contains('sketch') ? Icons.brush : Icons.image_outlined,
                              color: const Color(0xFFD4A017),
                              size: 30,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                final list = List<String>.from(images)..remove(img);
                                setState(() => _values[id] = list);
                              },
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      )),
                      if (images.length < max)
                        GestureDetector(
                          onTap: () => setState(() => _values[id] = [...images, 'photo_${images.length + 1}.jpg']),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: surf,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: bord),
                            ),
                            child: Icon(Icons.add, color: gold),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Optional Sketch Canvas Quick Attachment Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                if (images.length < max) {
                  _values[id] = [...images, 'canvas_sketch_${images.length + 1}.png'];
                  _showSnack(t('تم إرفاق رسمة توضيحية بنجاح', 'Canvas sketch attached successfully'));
                }
              });
            },
            icon: Icon(Icons.gesture, color: gold, size: 18),
            label: Text(
              t('إرفاق رسمة توضيحية بيدك (Canvas Sketch)', 'Attach Hand-Drawn Canvas Sketch'),
              style: GoogleFonts.cairo(color: text, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: gold.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom Bar ──────────────────────────────────────────────────────────
  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    decoration: BoxDecoration(
      color: bg,
      border: Border(top: BorderSide(color: bord)),
    ),
    child: GestureDetector(
      onTap: _proceed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
          borderRadius: BorderRadius.circular(27),
          boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            t('مراجعة وإرسال', 'Review & Send'),
            style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    ),
  );
}
