import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/exhibitions_service.dart';
import '../../services/payment_service.dart';
import '../../app_state.dart';

class ExhibitionRegistrationScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic> exhibition;
  final String? craftsmanId;
  final bool isInvited;

  const ExhibitionRegistrationScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.exhibition,
    required this.craftsmanId,
    this.isInvited = false,
  });

  @override
  State<ExhibitionRegistrationScreen> createState() =>
      _ExhibitionRegistrationScreenState();
}

class _ExhibitionRegistrationScreenState
    extends State<ExhibitionRegistrationScreen> {
  int _currentStep = 0;
  bool _agreeTerms = false;
  bool _isSubmitting = false;
  bool _isLoading = true;

  // Reserve mode: all booths are taken, craftsman is joining the standby queue
  bool _isReserveMode = false;

  late List<Map<String, dynamic>> _booths;
  int _selectedBoothIndex = 0;

  // Track if we've fetched the latest exhibition details
  Map<String, dynamic>? _exhibitionData;

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadExhibitionDetails();
  }

  Future<void> _loadExhibitionDetails() async {
    setState(() => _isLoading = true);
    final id = widget.exhibition['id']?.toString();
    if (id != null && id.isNotEmpty) {
      final data = await ExhibitionsService.getExhibitionById(id);
      if (data != null && mounted) {
        setState(() {
          _exhibitionData = data;
          _loadBoothsFromData(data);
          _isLoading = false;
        });
        return;
      }
    }
    // Fallback: use the passed exhibition data
    setState(() {
      _exhibitionData = widget.exhibition;
      _loadBoothsFromData(widget.exhibition);
      _isLoading = false;
    });
  }

  void _loadBoothsFromData(Map<String, dynamic> exhibition) {
    // Get existing participants (confirmed) with booth IDs
    final participants = exhibition['ExhibitionCraftsmen'] as List? ?? [];
    final takenBoothIds = participants
        .where((p) => p['status'] == 'confirmed' && p['boothId'] != null)
        .map((p) => p['boothId'].toString())
        .toSet();

    final layout = exhibition['boothLayout'];
    if (layout is List && layout.isNotEmpty) {
      _booths = layout.map<Map<String, dynamic>>((item) {
        final id = item['id']?.toString() ?? 'Booth';
        final price = (item['price'] ?? 0).toDouble();
        final available = !takenBoothIds.contains(id);
        return {
          'id': id,
          'price': price,
          'available': available,
        };
      }).toList();
    } else {
      final rows = exhibition['boothRows'] ?? 2;
      final cols = exhibition['boothColumns'] ?? 3;
      final basePrice = (exhibition['boothPrice'] ?? 25.0).toDouble();
      _booths = [];
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final id = String.fromCharCode(65 + r) + (c + 1).toString();
          final available = !takenBoothIds.contains(id);
          _booths.add({
            'id': id,
            'price': basePrice,
            'available': available,
          });
        }
      }
    }

    if (_booths.isEmpty) {
      _booths = [
        {'id': 'A1', 'price': 25.0, 'available': true}
      ];
    }

    // Detect reserve mode: isFull from server OR all booths are taken locally
    final serverIsFull = exhibition['isFull'] == true;
    final allTaken =
        _booths.isNotEmpty && _booths.every((b) => b['available'] == false);
    _isReserveMode = serverIsFull || allTaken;

    _ensureValidBooth();
  }

  void _ensureValidBooth() {
    if (_booths.isEmpty) {
      _selectedBoothIndex = -1;
      return;
    }
    if (_selectedBoothIndex < 0 || _selectedBoothIndex >= _booths.length) {
      // In reserve mode any booth can be picked; default to first
      int firstAvailable = _booths.indexWhere((b) => b['available'] == true);
      _selectedBoothIndex = firstAvailable != -1 ? firstAvailable : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureValidBooth();

    final exhibitionName = widget.isArabic
        ? widget.exhibition['name']
        : widget.exhibition['nameEn'];

    final selectedBooth = (_booths.isNotEmpty &&
            _selectedBoothIndex >= 0 &&
            _selectedBoothIndex < _booths.length)
        ? _booths[_selectedBoothIndex]
        : null;

    final boothPrice = selectedBooth != null ? selectedBooth['price'] : 0.0;
    final isFree = boothPrice == 0;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('التسجيل في المعرض', 'Register for Exhibition'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Note: when _isReserveMode is true we DON'T bail out here —
    // we fall through to the normal scaffold which now shows the reserve banner.

    return Directionality(
      textDirection:
          widget.isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('التسجيل في المعرض', 'Register for Exhibition'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: border,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 4,
            ),
          ),
        ),
        body: IndexedStack(
          index: _currentStep,
          children: [
            _buildBoothSelectionStep(exhibitionName, selectedBooth),
            // Skip payment step if free
            isFree ? const SizedBox.shrink() : _buildPaymentStep(selectedBooth),
            _buildConfirmationStep(selectedBooth),
          ],
        ),
        bottomNavigationBar: _currentStep == 2
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          child: Text(t('رجوع', 'Back')),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _currentStep == 0
                            ? _canProceedStep0
                                ? () => _handleNext()
                                : null
                            : _canProceedStep1 && !_isSubmitting
                                ? _processPayment
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (_currentStep == 0 && _canProceedStep0) ||
                                      (_currentStep == 1 && _canProceedStep1)
                                  ? accent
                                  : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                _currentStep == 0
                                    ? (_isReserveMode
                                        ? t('الانضمام لقائمة الاحتياط',
                                            'Join Reserve List')
                                        : (isFree && !widget.isInvited
                                            ? t('إرسال طلب مشاركة',
                                                'Send Participation Request')
                                            : t('التالي', 'Next')))
                                    : (isFree
                                        ? (widget.isInvited
                                            ? t('تسجيل', 'Register')
                                            : t('إرسال طلب مشاركة',
                                                'Send Participation Request'))
                                        : t('فتح الدفع في Stripe',
                                            'Open Stripe Checkout')),
                                style: TextStyle(
                                  color:
                                      (_currentStep == 0 && _canProceedStep0) ||
                                              (_currentStep == 1 &&
                                                  _canProceedStep1)
                                          ? Colors.black
                                          : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  bool get _canProceedStep0 {
    if (_booths.isEmpty ||
        _selectedBoothIndex < 0 ||
        _selectedBoothIndex >= _booths.length) {
      return false;
    }
    if (!_agreeTerms) return false;
    // In reserve mode any booth (even taken) can be selected
    if (_isReserveMode) return true;
    final selected = _booths[_selectedBoothIndex];
    return selected['available'] == true;
  }

  bool get _canProceedStep1 {
    // If free, no need for card details
    final selectedBooth = (_booths.isNotEmpty &&
            _selectedBoothIndex >= 0 &&
            _selectedBoothIndex < _booths.length)
        ? _booths[_selectedBoothIndex]
        : null;
    if (selectedBooth == null) return false;
    return true;
  }

  void _handleNext() {
    final selectedBooth = (_booths.isNotEmpty &&
            _selectedBoothIndex >= 0 &&
            _selectedBoothIndex < _booths.length)
        ? _booths[_selectedBoothIndex]
        : null;
    if (selectedBooth == null) return;

    // If booth is free, skip payment step and go directly to registration
    if (selectedBooth['price'] == 0) {
      _registerForExhibition(selectedBooth);
    } else {
      setState(() => _currentStep = 1);
    }
  }

  Widget _buildBoothSelectionStep(
      String exhibitionName, Map<String, dynamic>? selectedBooth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exhibitionName,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isReserveMode
                ? t('المعرض ممتلئ حالياً — اختر كشكاً للانضمام لقائمة الاحتياط',
                    'Exhibition is fully booked — pick a booth to join the reserve list')
                : t('اختر كشكك وسجل في هذا المعرض',
                    'Choose your booth and register for this exhibition'),
            style: TextStyle(color: dim, fontSize: 14),
          ),
          // Reserve mode banner
          if (_isReserveMode) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('قائمة الاحتياط', 'Reserve List'),
                          style: GoogleFonts.cairo(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                            'جميع الأكشاك محجوزة. يمكنك الانضمام لقائمة الاحتياط وسيتم إخطارك تلقائياً إذا أُلغي أحد الحجوزات.',
                            'All booths are taken. You can join the reserve list and will be automatically notified if a spot opens up.',
                          ),
                          style: TextStyle(
                              color: Colors.orange.shade200, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            _isReserveMode
                ? t('اختر كشكاً مفضلاً (احتياطي)',
                    'Choose a preferred booth (reserve)')
                : t('اختر كشكك', 'Choose Your Booth'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _booths.asMap().entries.map((entry) {
              final index = entry.key;
              final booth = entry.value;
              final isAvailable = booth['available'] == true;
              // In reserve mode all booths are tappable
              final isTappable = isAvailable || _isReserveMode;
              final isSelected = _selectedBoothIndex == index;
              return GestureDetector(
                onTap: isTappable
                    ? () {
                        setState(() {
                          _selectedBoothIndex = index;
                        });
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.orange
                        : isAvailable
                            ? surface
                            : _isReserveMode
                                ? Colors.orange.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.orange
                          : isAvailable
                              ? border
                              : _isReserveMode
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        booth['id'].toString(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : isAvailable
                                  ? text
                                  : _isReserveMode
                                      ? Colors.orange.shade300
                                      : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booth['price'] == 0
                            ? t('مجاني', 'Free')
                            : '${booth['price']} JOD',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : isAvailable
                                  ? dim
                                  : _isReserveMode
                                      ? Colors.orange.shade200
                                      : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _isReserveMode && !isAvailable
                            ? t('احتياطي', 'Reserve')
                            : !isAvailable
                                ? t('محجوز', 'Taken')
                                : '',
                        style: TextStyle(
                          color: _isReserveMode
                              ? Colors.orange.shade300
                              : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Checkbox(
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                activeColor: accent,
              ),
              Expanded(
                child: Text(
                  t('أوافق على شروط المشاركة في المعرض',
                      'I agree to the exhibition participation terms'),
                  style: TextStyle(color: text, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('المبلغ الإجمالي', 'Total Amount'),
                  style: TextStyle(
                      color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  selectedBooth != null
                      ? (selectedBooth['price'] == 0
                          ? t('مجاني', 'Free')
                          : '${selectedBooth['price']} JOD')
                      : '0.0 JOD',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep(Map<String, dynamic>? booth) {
    if (booth == null) {
      return Center(
        child: Text(t('لا توجد أكشاك متاحة', 'No booths available')),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('الدفع', 'Checkout'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('سيتم فتح صفحة Stripe الآمنة لإتمام الدفع',
                'A secure Stripe Checkout page will open to complete payment'),
            style: TextStyle(color: dim, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.open_in_browser, color: accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('بيانات البطاقة ستدخل في Stripe فقط',
                        'Your card details will be entered securely in Stripe'),
                    style: TextStyle(color: text, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('المبلغ', 'Amount'),
                  style: TextStyle(color: text, fontSize: 16),
                ),
                Text(
                  '${booth['price']} JOD',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('سيتم خصم المبلغ فوراً', 'Amount will be charged immediately'),
            style: TextStyle(
                color: dim, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep(Map<String, dynamic>? booth) {
    final boothId = booth != null ? booth['id'] : 'N/A';
    final boothPrice = booth != null ? (booth['price'] ?? 0.0) : 0.0;
    final isPendingRequest =
        boothPrice == 0 && !widget.isInvited && !_isReserveMode;

    IconData icon;
    Color iconColor;
    String title;
    String body;

    if (_isReserveMode) {
      icon = Icons.schedule_rounded;
      iconColor = Colors.orange;
      title = t('تم التسجيل في قائمة الاحتياط!', 'Added to Reserve List!');
      body = t(
        'تم تسجيلك في قائمة الاحتياط للكشك $boothId. ستتلقى إشعاراً فور توفر مكان.',
        'You have been added to the reserve list for booth $boothId. You will be notified as soon as a spot opens up.',
      );
    } else if (isPendingRequest) {
      icon = Icons.hourglass_top_rounded;
      iconColor = Colors.amber;
      title = t('تم إرسال طلب المشاركة بنجاح!', 'Participation Request Sent!');
      body = t(
        'تم إرسال طلب المشاركة لكشك $boothId. سينظر منظم المعرض في طلبك وسوف تتلقى إشعاراً عند القبول أو الرفض.',
        'Participation request for booth $boothId sent! The exhibition owner will review your request and you will be notified.',
      );
    } else {
      icon = Icons.check_circle;
      iconColor = Colors.green;
      title = t('تم التسجيل بنجاح!', 'Registration Successful!');
      body = t(
        'تم تأكيد كشك $boothId. تفقد معارضك للاطلاع على التفاصيل.',
        'Booth $boothId confirmed. Check your exhibitions for details.',
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 80),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: dim, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isReserveMode ? Colors.orange : accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                t('العودة إلى المعارض', 'Back to Exhibitions'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerForExhibition(Map<String, dynamic> booth) async {
    setState(() => _isSubmitting = true);

    final boothId = booth['id'].toString();
    final boothPrice = booth['price'] ?? 0.0;

    String craftsmanId;
    if (widget.craftsmanId != null && widget.craftsmanId!.isNotEmpty) {
      craftsmanId = widget.craftsmanId!;
    } else {
      final appState = context.read<AppState>();
      craftsmanId = appState.userId ?? '';
    }

    if (craftsmanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لم يتم التعرف على الحرفي، يرجى تسجيل الدخول',
              'Craftsman not identified, please log in')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      // If boothPrice == 0, skip payment
      String? paymentRef;
      if (boothPrice > 0) {
        paymentRef = await PaymentService.payExhibitionBooth(
          exhibitionId: widget.exhibition['id'].toString(),
          boothPrice: boothPrice,
          boothId: boothId,
          darkMode: widget.isDarkMode,
        );
      } else {
        // Free booth: generate a mock reference
        paymentRef = 'FREE-${DateTime.now().millisecondsSinceEpoch}';
      }

      final craftsList = widget.exhibition['crafts'];
      String? craftCategory;
      if (craftsList is List && craftsList.isNotEmpty) {
        craftCategory = craftsList.first.toString();
      }

      // Determine initial status:
      // - Reserve mode (all booths taken): 'standby'
      // - Invited craftsman:               'confirmed' (direct registration)
      // - Free booth, not invited:         'pending'  (owner must approve)
      // - Paid booth:                      'confirmed' (payment processed)
      final result = await ExhibitionsService.registerForExhibition(
        exhibitionId: widget.exhibition['id'].toString(),
        craftsmanId: craftsmanId,
        craftCategory: craftCategory,
        boothId: boothId,
        boothPrice: boothPrice,
        hasPaid: boothPrice > 0,
        paymentReference: paymentRef,
        isInvited: widget.isInvited,
        isReserve: _isReserveMode,
      );

      if (result != null) {
        setState(() => _currentStep = 2);
      } else {
        throw Exception('Registration failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(
                'فشل التسجيل، حاول مجدداً', 'Registration failed, try again')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _processPayment() async {
    setState(() => _isSubmitting = true);

    if (_selectedBoothIndex < 0 || _selectedBoothIndex >= _booths.length) {
      setState(() => _isSubmitting = false);
      return;
    }

    final selectedBooth = _booths[_selectedBoothIndex];
    final boothId = selectedBooth['id'].toString();
    final boothPrice = (selectedBooth['price'] ?? 0).toDouble();

    // If boothPrice is 0, skip payment and register directly
    if (boothPrice == 0) {
      await _registerForExhibition(selectedBooth);
      setState(() => _isSubmitting = false);
      return;
    }

    String craftsmanId;
    if (widget.craftsmanId != null && widget.craftsmanId!.isNotEmpty) {
      craftsmanId = widget.craftsmanId!;
    } else {
      final appState = context.read<AppState>();
      craftsmanId = appState.userId ?? '';
    }

    if (craftsmanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لم يتم التعرف على الحرفي، يرجى تسجيل الدخول',
              'Craftsman not identified, please log in')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final paymentRef = await PaymentService.payExhibitionBooth(
        exhibitionId: widget.exhibition['id'].toString(),
        boothPrice: boothPrice,
        boothId: boothId,
        darkMode: widget.isDarkMode,
      );

      final craftsList = widget.exhibition['crafts'];
      String? craftCategory;
      if (craftsList is List && craftsList.isNotEmpty) {
        craftCategory = craftsList.first.toString();
      }

      final result = await ExhibitionsService.registerForExhibition(
        exhibitionId: widget.exhibition['id'].toString(),
        craftsmanId: craftsmanId,
        craftCategory: craftCategory,
        boothId: boothId,
        boothPrice: boothPrice,
        hasPaid: true,
        paymentReference: paymentRef,
      );

      if (result != null) {
        setState(() => _currentStep = 2);
      } else {
        throw Exception('Registration failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('فشل الدفع أو التسجيل، حاول مجدداً',
                'Payment or registration failed, try again')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }
}
