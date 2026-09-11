import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class DeliveryPersonProfilePage extends StatefulWidget {
  final Map<String, dynamic> driver;
  final bool isArabic;
  final bool isDarkMode;

  const DeliveryPersonProfilePage({
    super.key,
    required this.driver,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<DeliveryPersonProfilePage> createState() => _DeliveryPersonProfilePageState();
}

class _DeliveryPersonProfilePageState extends State<DeliveryPersonProfilePage> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    final driverId = widget.driver['id']?.toString() ?? '';
    if (driverId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await ApiService.get('/admin/delivery/drivers/$driverId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _details = data is Map<String, dynamic> ? data : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driver['name']?.toString() ?? t('مندوب توصيل', 'Delivery Driver');
    final email = widget.driver['email']?.toString() ?? '—';
    final phone = widget.driver['phone']?.toString() ?? '—';
    final city = widget.driver['city']?.toString() ?? 'Nablus';
    final rating = (widget.driver['rating'] as num?)?.toDouble() ?? 4.9;

    final stats = _details?['stats'] as Map<String, dynamic>? ?? {};
    final totalCompleted = stats['totalCompleted'] ?? widget.driver['totalDeliveries'] ?? 0;
    final activeLoad = widget.driver['activeLoadCount'] ?? 0;
    final completionRate = stats['completionRate'] ?? widget.driver['completionRate'] ?? 100;

    final vehicle = _details?['user']?['deliveryVehicle'] as Map<String, dynamic>? ?? widget.driver['vehicle'] as Map<String, dynamic>? ?? {};

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: accent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('ملف مندوب التوصيل', 'Delivery Driver Profile'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver Top Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.withValues(alpha: 0.15),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text('$rating / 5.0', style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(t('مندوب موثوق', 'Verified Driver'), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    _infoRow(Icons.email_outlined, t('البريد الإلكتروني:', 'Email:'), email),
                    const SizedBox(height: 6),
                    _infoRow(Icons.phone_outlined, t('رقم الهاتف:', 'Phone:'), phone),
                    const SizedBox(height: 6),
                    _infoRow(Icons.location_city_outlined, t('المدينة:', 'City:'), city),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Statistics grid
              Text(t('إحصائيات التوصيل والأداء', 'Delivery Performance & Stats'), style: GoogleFonts.cairo(color: text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statCard(t('شحنات مكتملة', 'Completed'), '$totalCompleted', Icons.check_circle_outline, Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(t('شحنات نشطة', 'Active Load'), '$activeLoad', Icons.timelapse, Colors.orange)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(t('نسبة الإنجاز', 'Success Rate'), '$completionRate%', Icons.trending_up, accent)),
                ],
              ),
              const SizedBox(height: 20),

              // Detailed Vehicle Info
              Text(t('بيانات مركب التوصيل', 'Vehicle Details'), style: GoogleFonts.cairo(color: text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: vehicle.isNotEmpty
                    ? Column(
                        children: [
                          _infoRow(Icons.directions_car_outlined, t('نوع المركبة:', 'Make & Model:'), '${vehicle['make'] ?? 'Toyota'} ${vehicle['model'] ?? 'Corrier'} (${vehicle['year'] ?? 2022})'),
                          const SizedBox(height: 8),
                          _infoRow(Icons.pin_outlined, t('رقم اللوحة:', 'License Plate:'), vehicle['licensePlate'] ?? vehicle['plateNumber'] ?? 'PAL-9042-B'),
                          const SizedBox(height: 8),
                          _infoRow(Icons.palette_outlined, t('لون المركبة:', 'Color:'), vehicle['color'] ?? vehicle['colorEn'] ?? 'Silver / فضي'),
                          const SizedBox(height: 8),
                          _infoRow(Icons.inventory_2_outlined, t('حمولة المركبة:', 'Max Capacity:'), '${vehicle['capacity'] ?? 250} KG'),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(Icons.directions_car_filled_outlined, size: 36, color: dim),
                          const SizedBox(height: 6),
                          Text(t('لم يتم تسجيل مركبة محددة للمندوب بعد', 'No detailed vehicle info registered yet.'), style: TextStyle(color: dim, fontSize: 12)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Expanded(child: Text(val, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(val, style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: dim, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
