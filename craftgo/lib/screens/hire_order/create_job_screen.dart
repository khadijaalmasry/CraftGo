// lib/features/hire_order/screens/create_job_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'hire_order_provider.dart';
import '../../services/session_service.dart';
import '../../widgets/location_picker_screen.dart';

class CreateJobScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId;
  final String artisanName;

  const CreateJobScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
    required this.artisanName,
  });

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController(); // For extra details
  final TextEditingController _materialsController = TextEditingController();
  final TextEditingController _toolsController = TextEditingController();

  // ── Dates ──────────────────────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;

  // ── Daily hours ──────────────────────────────────────────────────────
  int _dailyHours = 8;

  // ── Materials list ────────────────────────────────────────────────────
  final List<MaterialItem> _materials = [];

  // ── Tools list ────────────────────────────────────────────────────────
  final List<String> _tools = [];

  // ── Location state ──────────────────────────────────────────────────────
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // ── UI state ──────────────────────────────────────────────────────────
  bool _isSubmitting = false;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isArabic => widget.isArabic;
  bool get isDarkMode => widget.isDarkMode;

  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg => isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get sub => isDarkMode ? Colors.white60 : Colors.black54;
  Color get bord => isDarkMode ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

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
            t('طلب عمل في الموقع', 'On-Site Job Request'),
            style: GoogleFonts.arefRuqaa(color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake_outlined, color: gold, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t('اطلب من الحرفي العمل في موقعك', 'Request the artisan to work at your location'),
                      style: TextStyle(color: text, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Job Description ──────────────────────────────────────────
            _buildSection(t('وصف العمل', 'Job Description')),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              style: GoogleFonts.cairo(color: text),
              decoration: InputDecoration(
                hintText: t('صف العمل الذي تريد تنفيذه بالتفصيل...', 'Describe the work in detail...'),
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
            const SizedBox(height: 20),

            // ── Location Section ──────────────────────────────────────────
            _buildSection(t('الموقع', 'Location')),
            const SizedBox(height: 8),

            // ── Map Preview ──────────────────────────────────────────────
            GestureDetector(
              onTap: _openLocationPicker,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bord),
                ),
                child: _selectedLocation == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 40, color: sub),
                      const SizedBox(height: 8),
                      Text(
                        t('اضغط لتحديد الموقع على الخريطة', 'Tap to pick location on map'),
                        style: TextStyle(color: sub, fontSize: 13),
                      ),
                    ],
                  ),
                )
                    : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Static map preview
                    Image.network(
                      'https://maps.googleapis.com/maps/api/staticmap?'
                          'center=${_selectedLocation!.latitude},${_selectedLocation!.longitude}&'
                          'zoom=15&'
                          'size=400x200&'
                          'markers=color:red%7C${_selectedLocation!.latitude},${_selectedLocation!.longitude}&'
                          'key=AIzaSyD4rIkm2EbnEXFWrkB9TsFUoNdhOgGh3AQ',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: gold.withValues(alpha: 0.08),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: Colors.red, size: 40),
                              const SizedBox(height: 4),
                              Text(
                                _selectedAddress ?? t('موقع محدد', 'Location selected'),
                                style: TextStyle(color: text, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Overlay with address and change button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedAddress ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t('تغيير', 'Change'),
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Landmark / Additional Details ──────────────────────────
            TextField(
              controller: _landmarkController,
              style: GoogleFonts.cairo(color: text),
              decoration: InputDecoration(
                hintText: t('تفاصيل إضافية (مثال: بجانب مغسلة محمود، الطابق الثالث، الشقة ٥)', 'Extra details (e.g. near Mahmoud\'s car wash, 3rd floor, apt 5)'),
                hintStyle: GoogleFonts.cairo(color: sub.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.location_city_outlined, color: gold),
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
            ),
            const SizedBox(height: 8),
            Text(
              t('أضف أي معلومات إضافية تساعد الحرفي في العثور على الموقع', 'Add any extra info to help the artisan find the location'),
              style: GoogleFonts.cairo(color: sub, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // ── Dates ──────────────────────────────────────────────────────
            _buildSection(t('التواريخ', 'Dates')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: t('تاريخ البدء', 'Start Date'),
                    date: _startDate,
                    onTap: () async {
                      final d = await _selectDate(_startDate);
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDatePicker(
                    label: t('تاريخ الانتهاء', 'End Date'),
                    date: _endDate,
                    onTap: () async {
                      final d = await _selectDate(_endDate);
                      if (d != null) setState(() => _endDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Daily Hours ──────────────────────────────────────────────
            _buildSection(t('ساعات العمل اليومية', 'Daily Working Hours')),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _dailyHours.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 10,
                    activeColor: gold,
                    inactiveColor: bord,
                    onChanged: (v) => setState(() => _dailyHours = v.round()),
                  ),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: bord),
                  ),
                  child: Center(
                    child: Text(
                      '$_dailyHours',
                      style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Materials ──────────────────────────────────────────────────
            _buildSection(t('المواد المطلوبة', 'Required Materials')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _materialsController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      hintText: t('أضف مادة (مثال: خشب - 10 - متر)', 'Add material (e.g. Wood - 10 - meter)'),
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
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: _addMaterial,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _materials.map((m) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${m.name} (${m.quantity} ${m.unit})', style: TextStyle(color: text)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _materials.remove(m)),
                      child: Icon(Icons.close, size: 14, color: Colors.redAccent),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),

            // ── Tools ──────────────────────────────────────────────────────
            _buildSection(t('الأدوات المطلوبة', 'Required Tools')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toolsController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      hintText: t('أضف أداة (مثال: مطرقة)', 'Add tool (e.g. Hammer)'),
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
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: _addTool,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tools.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t, style: TextStyle(color: text)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _tools.remove(t)),
                      child: Icon(Icons.close, size: 14, color: Colors.redAccent),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),

            // ── Submit Button ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isSubmitting ? null : _submitJob,
                child: _isSubmitting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                )
                    : Text(
                  t('إرسال الطلب', 'Submit Request'),
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

  // ── Helper Methods ──────────────────────────────────────────────────────────

  Widget _buildSection(String title) => Text(
    title,
    style: GoogleFonts.arefRuqaa(color: text, fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bord),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : label,
                style: TextStyle(
                  color: date != null ? text : sub,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: sub),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDate(DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD4A017)),
        ),
        child: child!,
      ),
    );
  }

  void _addMaterial() {
    final parts = _materialsController.text.trim().split('-');
    if (parts.length >= 2) {
      final name = parts[0].trim();
      final quantity = int.tryParse(parts[1].trim()) ?? 1;
      final unit = parts.length > 2 ? parts[2].trim() : '';
      setState(() {
        _materials.add(MaterialItem(name: name, quantity: quantity, unit: unit));
        _materialsController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('استخدم التنسيق: المادة - الكمية - الوحدة', 'Use format: Material - Quantity - Unit')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _addTool() {
    final tool = _toolsController.text.trim();
    if (tool.isNotEmpty) {
      setState(() {
        _tools.add(tool);
        _toolsController.clear();
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          initialLocation: _selectedLocation,
          initialAddress: _selectedAddress,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(result['latitude'], result['longitude']);
        _selectedAddress = result['address'];
      });
    }
  }

  Future<void> _submitJob() async {
    // Validate
    if (_descController.text.trim().isEmpty) {
      _showError(t('يرجى كتابة وصف العمل', 'Please write a job description'));
      return;
    }
    if (_selectedLocation == null) {
      _showError(t('يرجى تحديد الموقع على الخريطة', 'Please pick a location on the map'));
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError(t('يرجى اختيار تواريخ البدء والانتهاء', 'Please select start and end dates'));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showError(t('تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء', 'End date must be after the start date'));
      return;
    }

    // Combine address and landmark
    final fullAddress = _selectedAddress != null
        ? '$_selectedAddress, ${_landmarkController.text.trim()}'
        : _landmarkController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final session = await SessionService.getSession();
      final customerId = (session['userId'] ?? '').toString();
      final customerName = (session['name'] ?? '').toString();

      if (customerId.isEmpty) {
        throw Exception(t('يرجى تسجيل الدخول مجدداً', 'Please sign in again'));
      }

      final prov = context.read<HireOrderProvider>();
      await prov.createJob(
        customerId: customerId,
        customerName: customerName,
        artisanId: widget.artisanId,
        artisanName: widget.artisanName,
        jobDescription: _descController.text.trim(),
        location: fullAddress,
        locationLat: _selectedLocation!.latitude,
        locationLng: _selectedLocation!.longitude,
        startDate: _startDate!,
        endDate: _endDate!,
        dailyHours: _dailyHours,
        materials: List<MaterialItem>.from(_materials),
        toolsRequired: List<String>.from(_tools),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('✅ تم إرسال طلبك بنجاح!', '✅ Your request was sent successfully!')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _showError(message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
}
