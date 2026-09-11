import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/delivery_service.dart';

class CreateDeliveryScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String orderId; // For ready‑made orders
  final String productId; // For ready‑made orders
  final String productName; // For ready‑made orders
  final String? customOrderId; // for custom orders
  final List<String>? groupedOrderIds;
  final List<String>? groupedCustomOrderIds;
  final String? customerName;

  const CreateDeliveryScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.customOrderId,
    this.groupedOrderIds,
    this.groupedCustomOrderIds,
    this.customerName,
  });

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isFragile = false;
  double _earningAmount = 0;
  String? _selectedDriverId;
  List<Map<String, dynamic>> _drivers = [];
  bool _loadingDrivers = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    // Try ready‑made order first
    if (widget.orderId.isNotEmpty) {
      var res = await ApiService.get('/orders/${widget.orderId}');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final orderObj = data['order'] ?? data;
        final address =
            orderObj['shippingAddress'] ?? orderObj['deliveryAddress'] ?? '';
        final phone = orderObj['customerPhone'] ?? '';
        if (mounted) {
          setState(() {
            if (address.toString().isNotEmpty &&
                _dropoffController.text.isEmpty) {
              _dropoffController.text = address.toString();
            }
            if (phone.toString().isNotEmpty &&
                _customerPhoneController.text.isEmpty) {
              _customerPhoneController.text = phone.toString();
            }
          });
        }
        return;
      }
    }

    // Then try custom order
    if (widget.customOrderId != null && widget.customOrderId!.isNotEmpty) {
      final res = await ApiService.get(
          '/custom-orders/requests/${widget.customOrderId}');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final request = data['request'] ?? data;
        final address = request['deliveryAddress'] ??
            request['filledFields']?['deliveryAddress'] ??
            '';
        final phone = request['customerPhone'] ??
            request['filledFields']?['customerPhone'] ??
            '';
        if (mounted) {
          setState(() {
            if (address.toString().isNotEmpty &&
                _dropoffController.text.isEmpty) {
              _dropoffController.text = address.toString();
            }
            if (phone.toString().isNotEmpty &&
                _customerPhoneController.text.isEmpty) {
              _customerPhoneController.text = phone.toString();
            }
          });
        }
      }
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _loadingDrivers = true);
    final drivers = await DeliveryService.getAvailableDrivers();
    if (mounted) {
      setState(() {
        _drivers = drivers.map((d) => Map<String, dynamic>.from(d)).toList();
        _loadingDrivers = false;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final payload = {
      if (widget.orderId.isNotEmpty) 'orderId': widget.orderId,
      if (widget.customOrderId != null && widget.customOrderId!.isNotEmpty)
        'customOrderId': widget.customOrderId,
      if (widget.groupedOrderIds != null && widget.groupedOrderIds!.isNotEmpty)
        'orderIds': widget.groupedOrderIds,
      if (widget.groupedCustomOrderIds != null &&
          widget.groupedCustomOrderIds!.isNotEmpty)
        'customOrderIds': widget.groupedCustomOrderIds,
      'productId': widget.productId,
      'pickupAddress': _pickupController.text.trim(),
      'dropoffAddress': _dropoffController.text.trim(),
      'customerPhone': _customerPhoneController.text.trim(),
      'pickupPhone': _pickupPhoneController.text.trim(),
      'weightKg': double.tryParse(_weightController.text) ?? 0,
      'isFragile': _isFragile,
      'earningAmount': _earningAmount,
      if (_selectedDriverId != null) 'driverId': _selectedDriverId,
    };

    try {
      final response = await ApiService.post('/delivery/orders', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  t('تم حفظ طلب التوصيل بنجاح', 'Delivery order saved')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to create delivery');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(t('فشل إنشاء طلب التوصيل', 'Failed to create delivery')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String t(String ar, String en) => widget.isArabic ? ar : en;
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);

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
            t('إنشاء طلب توصيل', 'Create Delivery'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildField(
                controller: _pickupController,
                label: t('عنوان الاستلام', 'Pickup Address'),
                hint: t('مثال: ورشة الحرفي في عمّان',
                    'e.g. Artisan workshop in Amman'),
              ),
              _buildField(
                controller: _dropoffController,
                label: t('عنوان التسليم', 'Dropoff Address'),
                hint: t('عنوان العميل', 'Customer address'),
              ),
              _buildField(
                controller: _customerPhoneController,
                label: t('هاتف العميل', 'Customer Phone'),
                hint: t('رقم هاتف العميل', 'Customer phone number'),
                keyboardType: TextInputType.phone,
              ),
              _buildField(
                controller: _pickupPhoneController,
                label: t('هاتف الاستلام', 'Pickup Phone'),
                hint: t('رقم هاتف لجهة الاستلام', 'Pickup contact phone'),
                keyboardType: TextInputType.phone,
              ),
              _buildField(
                controller: _weightController,
                label: t('الوزن (كجم)', 'Weight (kg)'),
                hint: '0.0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isFragile,
                    onChanged: (v) => setState(() => _isFragile = v ?? false),
                    activeColor: accent,
                  ),
                  Text(
                    t('هش / قابل للكسر', 'Fragile'),
                    style: TextStyle(color: text),
                  ),
                  const Spacer(),
                  Text(
                    t('أجر التوصيل', 'Delivery Fee'),
                    style: TextStyle(color: dim),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: _earningAmount.toString(),
                      onChanged: (v) =>
                          _earningAmount = double.tryParse(v) ?? 0,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        suffixText: 'JOD',
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingDrivers)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String?>(
                  value: _selectedDriverId,
                  hint: Text(t('اختر سائق أو اتركها عامة (الفراغ)',
                      'Select driver or release to void (public pool)')),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        t('🌌 إطلاق في الفراغ (لجميع السائقين المتاحين)',
                            '🌌 Release to Void (All Available Drivers)'),
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._drivers.map((d) {
                      final id = d['id']?.toString() ?? '';
                      final name = d['name']?.toString() ?? 'Driver';
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text('$name (${d['phone'] ?? ''})',
                            style: TextStyle(color: text)),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedDriverId = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        t('إنشاء طلب التوصيل', 'Create Delivery'),
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: dim),
          hintText: hint,
          hintStyle: TextStyle(color: dim.withValues(alpha: 0.6)),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? t('هذا الحقل مطلوب', 'This field is required')
            : null,
      ),
    );
  }
}
