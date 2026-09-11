import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'hire_order_provider.dart';

class HireResponseScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final HireRequest request;

  const HireResponseScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.request,
  });

  @override
  State<HireResponseScreen> createState() => _HireResponseScreenState();
}

class _HireResponseScreenState extends State<HireResponseScreen> {
  final _dailyRateController = TextEditingController();
  final _materialCostController = TextEditingController();
  final _generalPlanController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_ScheduleDraft> _schedule = [];
  int _defaultHours = 8;
  bool _customizeDays = false;
  bool _submitting = false;

  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;
  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();
    final days = widget.request.endDate
        .difference(widget.request.startDate)
        .inDays +
        1;
    final count = days.clamp(1, 30);
    _defaultHours = widget.request.dailyHours.clamp(1, 12).toInt();
    for (var i = 1; i <= count; i++) {
      _schedule.add(
        _ScheduleDraft(
          day: i,
          hours: _defaultHours,
          taskController: TextEditingController(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _dailyRateController.dispose();
    _materialCostController.dispose();
    _generalPlanController.dispose();
    _notesController.dispose();
    for (final day in _schedule) {
      day.taskController.dispose();
    }
    super.dispose();
  }

  double get _dailyRate =>
      double.tryParse(_dailyRateController.text.trim()) ?? 0;
  double get _materialCost =>
      double.tryParse(_materialCostController.text.trim()) ?? 0;
  double get _total => (_dailyRate * _schedule.length) + _materialCost;

  InputDecoration _inputDecoration(
      String hint, {
        IconData? icon,
        String? label,
        String? suffix,
      }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cairo(color: dim),
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: dim, fontSize: 12),
      floatingLabelStyle: GoogleFonts.cairo(
        color: gold,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixText: suffix,
      suffixStyle: GoogleFonts.cairo(
        color: gold,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: icon == null ? null : Icon(icon, color: gold),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold, width: 1.5),
      ),
    );
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

  Future<void> _submit() async {
    if (_dailyRate <= 0) {
      _showError(t('أدخل السعر اليومي', 'Enter a valid daily rate'));
      return;
    }
    if (_materialCost < 0) {
      _showError(t('تكلفة المواد غير صحيحة', 'Invalid material cost'));
      return;
    }

    final generalTasks = _generalPlanController.text
        .split(',')
        .map((task) => task.trim())
        .where((task) => task.isNotEmpty)
        .toList();
    if (generalTasks.isEmpty) {
      _showError(t('أضف خطة العمل العامة', 'Add a general work plan'));
      return;
    }

    final schedule = <DailySchedule>[];
    for (final day in _schedule) {
      final customTasks = day.taskController.text
          .split(',')
          .map((task) => task.trim())
          .where((task) => task.isNotEmpty)
          .toList();
      schedule.add(
        DailySchedule(
          day: day.day,
          tasks: customTasks.isEmpty ? generalTasks : customTasks,
          hours: _customizeDays ? day.hours : _defaultHours,
        ),
      );
    }

    setState(() => _submitting = true);
    try {
      await context.read<HireOrderProvider>().artisanRespond(
        requestId: widget.request.id,
        dailyRate: _dailyRate,
        materialCost: _materialCost,
        schedule: schedule,
        notesAr: _notesController.text.trim(),
        notesEn: _notesController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('✅ تم إرسال العرض بنجاح!',
              '✅ Proposal sent successfully!')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('إرسال عرض', 'Send Proposal'),
            style: GoogleFonts.arefRuqaa(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            _requestSummary(),
            const SizedBox(height: 22),
            _sectionTitle(t('التكلفة', 'Pricing')),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dailyRateController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.cairo(color: text),
                    decoration: _inputDecoration(
                      '0.00',
                      icon: Icons.payments_outlined,
                      label: t('السعر اليومي', 'Daily rate'),
                      suffix: 'JOD',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _materialCostController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.cairo(color: text),
                    decoration: _inputDecoration(
                      '0.00',
                      icon: Icons.inventory_2_outlined,
                      label: t('تكلفة المواد', 'Material cost'),
                      suffix: 'JOD',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('السعر الإجمالي', 'Total price'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_total.toStringAsFixed(2)} JOD',
                    style: GoogleFonts.cairo(
                      color: gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(t('جدول العمل', 'Work Schedule')),
            const SizedBox(height: 9),
            _scheduleSummary(),
            const SizedBox(height: 10),
            TextField(
              controller: _generalPlanController,
              maxLines: 4,
              style: GoogleFonts.cairo(color: text, fontSize: 13),
              decoration: _inputDecoration(
                t(
                  'خطة العمل العامة (افصل المهام بفاصلة)',
                  'General work plan (separate tasks with commas)',
                ),
                icon: Icons.assignment_outlined,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _customizeDays,
              onChanged: (value) => setState(() => _customizeDays = value),
              activeThumbColor: gold,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: border),
              ),
              title: Text(
                t('تخصيص أيام معينة', 'Customize specific days'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                t(
                  'اختياري: غيّر مهام أو ساعات يوم معين',
                  'Optional: change tasks or hours for a specific day',
                ),
                style: GoogleFonts.cairo(color: dim, fontSize: 10),
              ),
            ),
            if (_customizeDays) ...[
              const SizedBox(height: 10),
              ..._schedule.map(_scheduleCard),
            ],
            const SizedBox(height: 14),
            _sectionTitle(t('ملاحظات للزبون', 'Notes to Customer')),
            const SizedBox(height: 9),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: GoogleFonts.cairo(color: text),
              decoration: _inputDecoration(
                t('أضف أي ملاحظات عن العرض...',
                    'Add any notes about your proposal...'),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: gold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.black,
                  ),
                )
                    : Text(
                  t('إرسال العرض', 'Send Proposal'),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestSummary() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.request.customerName,
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.request.jobDescription,
            style: GoogleFonts.cairo(color: dim, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '${_date(widget.request.startDate)}  →  ${_date(widget.request.endDate)}',
            style: GoogleFonts.cairo(color: gold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(_ScheduleDraft day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('اليوم ${day.day}', 'Day ${day.day}'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('تقليل الساعات', 'Decrease hours'),
                onPressed: day.hours > 1
                    ? () => setState(() => day.hours--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: gold,
              ),
              Text(
                t('${day.hours} س', '${day.hours} h'),
                style: GoogleFonts.cairo(color: text),
              ),
              IconButton(
                tooltip: t('زيادة الساعات', 'Increase hours'),
                onPressed: day.hours < 12
                    ? () => setState(() => day.hours++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: gold,
              ),
            ],
          ),
          TextField(
            controller: day.taskController,
            style: GoogleFonts.cairo(color: text, fontSize: 13),
            decoration: _inputDecoration(
              t('اتركها فارغة لاستخدام الخطة العامة',
                  'Leave empty to use the general plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: GoogleFonts.arefRuqaa(
      color: text,
      fontWeight: FontWeight.bold,
      fontSize: 17,
    ),
  );

  Widget _scheduleSummary() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, color: gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('مدة العمل: ${_schedule.length} يوم',
                      'Duration: ${_schedule.length} days'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  t('تطبّق الخطة العامة على جميع الأيام',
                      'The general plan applies to every day'),
                  style: GoogleFonts.cairo(color: dim, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _defaultHours > 1
                ? () => setState(() {
              _defaultHours--;
              for (final day in _schedule) {
                day.hours = _defaultHours;
              }
            })
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: gold,
          ),
          Text(
            t('$_defaultHours س', '$_defaultHours h'),
            style: GoogleFonts.cairo(color: text),
          ),
          IconButton(
            onPressed: _defaultHours < 12
                ? () => setState(() {
              _defaultHours++;
              for (final day in _schedule) {
                day.hours = _defaultHours;
              }
            })
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: gold,
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class _ScheduleDraft {
  final int day;
  int hours;
  final TextEditingController taskController;

  _ScheduleDraft({
    required this.day,
    required this.hours,
    required this.taskController,
  });
}
