import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import '../../services/payment_service.dart';

class ExhibitionRegistrationScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic> exhibition;
  final String? craftCategory;
  final bool isInvited;

  const ExhibitionRegistrationScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.exhibition,
    this.craftCategory,
    this.isInvited = false,
  });

  @override
  State<ExhibitionRegistrationScreen> createState() =>
      _ExhibitionRegistrationScreenState();
}

class _ExhibitionRegistrationScreenState
    extends State<ExhibitionRegistrationScreen> {
  int _currentStep = 0;
  int _selectedBoothIndex = 0;
  bool _agreeTerms = false;
  bool _isSubmitting = false;
  String _craftCategory = 'Handicrafts';

  List<Map<String, dynamic>> get _booths {
    final layout = widget.exhibition['boothLayout'];
    if (layout != null && layout is List && layout.isNotEmpty) {
      return layout.map<Map<String, dynamic>>((b) {
        return {
          'id': b['id']?.toString() ?? 'A1',
          'price': (b['price'] is num) ? (b['price'] as num).toDouble() : 25.0,
          'available': b['available'] ?? true,
        };
      }).toList();
    }
    // Fallback if no boothLayout provided
    return [
      {'id': 'A1', 'price': 25.0, 'available': true},
      {'id': 'A2', 'price': 25.0, 'available': true},
    ];
  }

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
    if (_booths.isNotEmpty) {
      final firstAvailable = _booths.indexWhere((b) => b['available'] == true);
      if (firstAvailable != -1) {
        _selectedBoothIndex = firstAvailable;
      } else {
        _selectedBoothIndex = 0;
      }
    }
    _loadCraftCategory();
  }

  Future<void> _loadCraftCategory() async {
    if (widget.craftCategory != null) {
      setState(() {
        _craftCategory = widget.craftCategory!;
      });
      return;
    }

    // Fetch from current user's artisan profile
    try {
      final appState = context.read<AppState>();
      final userId = appState.userId;
      if (userId != null) {
        final profile = await ExhibitionsService.getCraftsmanProfile(userId);
        if (profile != null && mounted) {
          final artisanProfile =
              profile['ArtisanProfile'] as Map<String, dynamic>?;
          final specialty = artisanProfile?['specialty'] ?? 'Handicrafts';
          setState(() {
            _craftCategory = specialty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading craft category: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exhibitionName = widget.isArabic
        ? widget.exhibition['name']
        : widget.exhibition['nameEn'];
    final boothsList = _booths;
    final validIndex = (_selectedBoothIndex >= 0 && _selectedBoothIndex < boothsList.length)
        ? _selectedBoothIndex
        : 0;
    final selectedBooth =
        boothsList.isNotEmpty ? boothsList[validIndex] : null;

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
          index: _currentStep == 0 ? 0 : 1,
          children: [
            _buildBoothSelectionStep(exhibitionName, selectedBooth),
            _buildConfirmationStep(selectedBooth),
          ],
        ),
        bottomNavigationBar: _currentStep == 1
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_canProceedStep0 && !_isSubmitting)
                        ? _processPayment
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_canProceedStep0 && !_isSubmitting) ? accent : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            t('الدفع والتسجيل عبر Stripe', 'Pay & Register via Stripe'),
                            style: TextStyle(
                              color: (_canProceedStep0 && !_isSubmitting)
                                  ? Colors.black
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  bool get _canProceedStep0 {
    final boothsList = _booths;
    return _agreeTerms &&
        boothsList.isNotEmpty &&
        _selectedBoothIndex >= 0 &&
        _selectedBoothIndex < boothsList.length &&
        boothsList[_selectedBoothIndex]['available'] == true;
  }

  Widget _buildBoothSelectionStep(String exhibitionName, Map<String, dynamic>? selectedBooth) {
    final boothsList = _booths;
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
            t('اختر كشكك وسجل حضورك في هذا المعرض',
                'Choose your booth and register for this exhibition'),
            style: TextStyle(color: dim, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Text(
            t('اختر كشكك', 'Choose Your Booth'),
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
            children: List.generate(boothsList.length, (index) {
              final booth = boothsList[index];
              final isAvailable = booth['available'] == true;
              final isSelected = _selectedBoothIndex == index;
              return GestureDetector(
                onTap: isAvailable
                    ? () => setState(() => _selectedBoothIndex = index)
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent
                        : isAvailable
                            ? surface
                            : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : isAvailable
                              ? border
                              : Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        booth['id']?.toString() ?? 'A1',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : isAvailable
                                  ? text
                                  : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booth['price']} JOD',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : isAvailable
                                  ? dim
                                  : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (!isAvailable)
                        Text(
                          t('محجوز', 'Taken'),
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              );
            }),
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
                  t('المبلغ المطلوب', 'Total Amount'),
                  style: TextStyle(
                      color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${selectedBooth != null ? selectedBooth['price'] : 0} JOD',
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



  Widget _buildConfirmationStep(Map<String, dynamic>? booth) {
    final boothId = booth != null ? booth['id'] : 'N/A';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            Text(
              t('تم التسجيل بنجاح!', 'Registration Successful!'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('تم تأكيد حجز كشك $boothId. يمكنك الاطلاع على التفاصيل من صفحة معارضي.',
                  'Booth $boothId confirmed. Check your exhibitions for details.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: dim, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                t('العودة إلى المعارض', 'Back to Exhibitions'),
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _processPayment() async {
    final appState = context.read<AppState>();
    final userId = appState.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى تسجيل الدخول أولاً', 'Please login first')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final boothsList = _booths;
    final validIndex = (_selectedBoothIndex >= 0 && _selectedBoothIndex < boothsList.length)
        ? _selectedBoothIndex
        : 0;
    final selectedBooth = boothsList.isNotEmpty ? boothsList[validIndex] : {'id': 'A1', 'price': 25.0};
    String txnRef = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    try {
      txnRef = await PaymentService.payExhibitionBooth(
        exhibitionId: widget.exhibition['id']?.toString() ?? '',
        boothPrice: (selectedBooth['price'] as num?)?.toDouble() ?? 50.0,
        boothId: selectedBooth['id'],
        darkMode: appState.isDarkMode,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل الدفع: ', 'Payment failed: ') + e.toString()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await ExhibitionsService.registerForExhibition(
      exhibitionId: widget.exhibition['id']?.toString() ?? '',
      craftsmanId: userId,
      craftCategory: _craftCategory,
      boothId: selectedBooth['id'],
      boothPrice: selectedBooth['price'],
      hasPaid: true,
      paymentReference: txnRef,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      setState(() => _currentStep = 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(t('فشل الدفع، حاول مجدداً', 'Payment failed, try again')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
