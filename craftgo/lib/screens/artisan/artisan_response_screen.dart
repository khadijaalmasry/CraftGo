// lib/features/custom_order/screens/artisan_response_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../custom_order/custom_order_provider.dart';
import '../custom_order/custom_order_request.dart';
import '../../services/custom_order_service.dart';

class ArtisanResponseScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final CustomOrderRequest request;
  final String artisanId;

  const ArtisanResponseScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.request,
    required this.artisanId,
  });

  @override
  State<ArtisanResponseScreen> createState() => _ArtisanResponseScreenState();
}

class _ArtisanResponseScreenState extends State<ArtisanResponseScreen> {
  // ── Price Breakdown ──────────────────────────────────────────────────────
  final List<PriceRow> _priceRows = [];
  final TextEditingController _priceLabelController = TextEditingController();
  final TextEditingController _priceAmountController = TextEditingController();

  // ── Tasks ──────────────────────────────────────────────────────────────────
  final List<String> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  // ── Delivery Date ──────────────────────────────────────────────────────────
  DateTime? _deliveryDate;

  // ── Notes ──────────────────────────────────────────────────────────────────
  final TextEditingController _notesController = TextEditingController();

  // ── UI State ──────────────────────────────────────────────────────────────
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // ── Pre-fill example price rows ──────────────────────────────────────
    _priceRows.addAll([
      PriceRow(
        labelAr: 'المواد الخام',
        labelEn: 'Materials',
        amount: 30.0,
      ),
      PriceRow(
        labelAr: 'الأيدي العاملة',
        labelEn: 'Labor',
        amount: 40.0,
      ),
      PriceRow(
        labelAr: 'التوصيل',
        labelEn: 'Delivery',
        amount: 5.0,
      ),
    ]);

    // ── Pre-fill example tasks based on template title ──────────────────
    final templateTitle = widget.request.templateTitleAr;
    _tasks.addAll([
      t('تجهيز المواد اللازمة', 'Prepare required materials'),
      t('تنفيذ العمل حسب التفاصيل', 'Execute work according to details'),
      t('مراجعة الجودة النهائية', 'Final quality check'),
    ]);

    // ── Default delivery date: 7 days from now ──────────────────────────
    _deliveryDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _priceLabelController.dispose();
    _priceAmountController.dispose();
    _taskController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;

  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg => isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  double get _totalPrice => _priceRows.fold(0, (sum, row) => sum + row.amount);

  void _addPriceRow() {
    final label = _priceLabelController.text.trim();
    final amount = double.tryParse(_priceAmountController.text.trim());
    if (label.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى إدخال اسم وصحيح للسعر', 'Please enter a valid label and amount')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _priceRows.add(PriceRow(
        labelAr: isArabic ? label : _priceLabelController.text.trim(),
        labelEn: isArabic ? _priceLabelController.text.trim() : label,
        amount: amount,
      ));
      _priceLabelController.clear();
      _priceAmountController.clear();
    });
  }

  void _removePriceRow(int index) {
    setState(() => _priceRows.removeAt(index));
  }

  void _addTask() {
    final task = _taskController.text.trim();
    if (task.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى إدخال مهمة', 'Please enter a task')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _tasks.add(task);
      _taskController.clear();
    });
  }

  void _removeTask(int index) {
    setState(() => _tasks.removeAt(index));
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD4A017)),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() => _deliveryDate = date);
    }
  }

  Future<void> _submitResponse() async {
    if (_priceRows.isEmpty) {
      _showError(t('أضف بند سعر واحد على الأقل', 'Add at least one price item'));
      return;
    }
    if (_tasks.isEmpty) {
      _showError(t('أضف مهمة واحدة على الأقل', 'Add at least one task'));
      return;
    }
    if (_deliveryDate == null) {
      _showError(t('اختر تاريخ تسليم', 'Select a delivery date'));
      return;
    }

    setState(() => _isSubmitting = true);

    // Send to backend
    final ok = await CustomOrderService.artisanRespond(
      requestId: widget.request.id,
      breakdown: _priceRows.map((r) => {
        'labelAr': r.labelAr,
        'labelEn': r.labelEn,
        'amount': r.amount,
      }).toList(),
      tasks: _tasks,
      deliveryDate: _deliveryDate!.toIso8601String(),
      notesAr: _notesController.text.trim(),
      notesEn: _notesController.text.trim(),
    );

    // Also update local provider state for immediate UI refresh
    if (ok && mounted) {
      final prov = context.read<CustomOrderProvider>();
      await prov.artisanRespond(
        requestId: widget.request.id,
        breakdown: _priceRows,
        tasks: _tasks,
        deliveryDate: _deliveryDate!,
        notesAr: _notesController.text.trim(),
        notesEn: _notesController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? t('✅ تم إرسال العرض بنجاح!', '✅ Bid sent successfully!')
            : t('❌ فشل الإرسال، حاول مجدداً', '❌ Send failed, try again')),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
            t('الرد على الطلب', 'Respond to Request'),
            style: GoogleFonts.arefRuqaa(color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Customer Request Summary ───────────────────────────────────
            _buildSection(t('طلب الزبون', 'Customer Request')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bord),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? widget.request.templateTitleAr : widget.request.templateTitleEn,
                    style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.request.customerName,
                    style: GoogleFonts.cairo(color: sub, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  // Show customer's filled fields in a nicely formatted way
                  ...widget.request.filledFields.entries.map((entry) {
                    final key = entry.key;
                    final value = entry.value.toString();
                    if (value.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
                          ),
                          Expanded(
                            child: Text(
                              '$key: $value',
                              style: GoogleFonts.cairo(color: text, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Price Breakdown ────────────────────────────────────────────
            _buildSection(t('توزيع السعر', 'Price Breakdown')),
            const SizedBox(height: 8),
            ..._priceRows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bord),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        isArabic ? row.labelAr : row.labelEn,
                        style: GoogleFonts.cairo(color: text, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${row.amount.toStringAsFixed(0)} JOD',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.cairo(color: gold, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => _removePriceRow(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Add Price Row Input
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceLabelController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      hintText: t('الاسم (مثال: مواد)', 'Label (e.g. Materials)'),
                      hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: surf,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _priceAmountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      hintText: t('السعر', 'Amount'),
                      hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: surf,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                ),
                const SizedBox(width: 8),
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: _addPriceRow,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('المجموع', 'Total'),
                  style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${_totalPrice.toStringAsFixed(0)} JOD',
                  style: GoogleFonts.cairo(color: gold, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Tasks ──────────────────────────────────────────────────────
            _buildSection(t('المهام', 'Tasks')),
            const SizedBox(height: 8),
            ..._tasks.asMap().entries.map((entry) {
              final idx = entry.key;
              final task = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: bord),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task,
                        style: GoogleFonts.cairo(color: text, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => _removeTask(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Add Task Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      hintText: t('أضف مهمة (مثال: تحضير المواد)', 'Add a task (e.g. Prepare materials)'),
                      hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: surf,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: bord),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: gold, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add_circle_outline, color: gold),
                        onPressed: _addTask,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Delivery Date ─────────────────────────────────────────────
            _buildSection(t('تاريخ التسليم', 'Delivery Date')),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
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
                        _deliveryDate != null
                            ? '${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}'
                            : t('اختر تاريخ التسليم', 'Select delivery date'),
                        style: TextStyle(
                          color: _deliveryDate != null ? text : sub,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: sub),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Notes ──────────────────────────────────────────────────────
            _buildSection(t('ملاحظات للحرفي', 'Notes to Customer')),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: GoogleFonts.cairo(color: text),
              decoration: InputDecoration(
                hintText: t('أضف أي ملاحظات إضافية...', 'Add any additional notes...'),
                hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
                filled: true,
                fillColor: surf,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: bord),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: gold, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit Button ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isSubmitting ? null : _submitResponse,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                )
                    : Text(
                  t('إرسال العرض', 'Send Bid'),
                  style: GoogleFonts.cairo(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) => Text(
    title,
    style: GoogleFonts.arefRuqaa(color: text, fontSize: 16, fontWeight: FontWeight.bold),
  );
}
