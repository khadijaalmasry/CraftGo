import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'pending_verification_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../services/upload_service.dart';
import 'id_camera_screen.dart';
import 'customer_login_screen.dart'; // ← Customer Login

class CraftsmanRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCategory;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const CraftsmanRegistrationScreen({
    super.key,
    required this.selectedCategory,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<CraftsmanRegistrationScreen> createState() =>
      _CraftsmanRegistrationScreenState();
}

class _CraftsmanRegistrationScreenState
    extends State<CraftsmanRegistrationScreen> with TickerProviderStateMixin {
  late bool isArabic;
  late bool isDarkMode;

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final int _totalSteps = 4;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  // Custom category controller
  final TextEditingController _customCategoryController =
      TextEditingController();
  bool _isCustomCategory = false;

  final List<String> _clayOptionsAr = [
    'خزف أحمر',
    'بورسلان',
    'Stoneware (طين حجري)',
    'طين أبيض',
    'فخار',
    'أخرى'
  ];
  final List<String> _clayOptionsEn = [
    'Red Clay',
    'Porcelain',
    'Stoneware',
    'White Clay',
    'Earthenware',
    'Other'
  ];
  final List<String> _selectedClays = [];
  final TextEditingController _otherClayController = TextEditingController();

  final List<String> _jewelryMaterialsEn = [
    'Gold',
    'Silver',
    'Stainless Steel',
    'Brass',
    'Copper',
    'Beads',
    'Resin',
    'Other',
  ];

  final List<String> _jewelryMaterialsAr = [
    'ذهب',
    'فضة',
    'ستانلس ستيل',
    'نحاس أصفر',
    'نحاس',
    'خرز',
    'ريزن',
    'أخرى',
  ];

  final List<String> _selectedJewelryMaterials = [];
  final TextEditingController _otherJewelryMaterialController =
      TextEditingController();

  final List<String> _priceRangesAr = [
    'أقل من 50',
    '50 - 150',
    '150 - 300',
    'أكثر من 300'
  ];
  final List<String> _priceRangesEn = [
    'Under 50',
    '50 - 150',
    '150 - 300',
    'Over 300'
  ];
  String? _selectedPriceRange;

  double _passwordStrength = 0.0;
  bool _isIdUploaded = false;
  bool _isPortfolioUploaded = false;
  bool _isGeneratingBio = false;
  final List<String> _bioSuggestions = [];
  int _currentBioIndex = -1;

  final ImagePicker _imagePicker = ImagePicker();
  String? _idImageUrl;
  String? _idImagePath;
  final List<String> _portfolioImageUrls = [];
  final List<String> _portfolioImagePaths = [];
  bool _isUploadingId = false;
  bool _isUploadingPortfolio = false;
  Map<String, dynamic>? _idVerificationDetails;
  String _idUploadStatus = '';
  String? _selectedCity;
  int _otpCountdown = 59;
  Timer? _otpTimer;

  // ─── Logo Animation Controllers ──────────────────────────────────
  late AnimationController _pulseController; // for scale pulse
  late AnimationController _shimmerController; // for shimmer

  // ─── Gold Colors (same as CustomerLoginScreen) ──────────────────
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);

  List<Color> get _logoShimmerColors => isDarkMode
      ? [goldBright, goldBrightLight, Colors.white, goldBrightLight, goldBright]
      : [goldDark, goldBright, Colors.white, goldBright, goldDark];

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;

    _isCustomCategory = widget.selectedCategory['titleEn'] == 'Other (Custom)';

    _passwordController.addListener(_checkPasswordStrength);

    // Pulse animation (slow scale)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Shimmer animation (continuous)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    _otherClayController.dispose();
    _otherJewelryMaterialController.dispose();
    _customCategoryController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _otpTimer?.cancel();
    super.dispose();
  }

  List<String>? _currentSpecializations() {
    final String category = widget.selectedCategory['titleEn'] ?? '';

    if (category == 'Pottery & Ceramics') {
      final values = List<String>.from(_selectedClays);
      if (values.contains('Other')) {
        values.remove('Other');
        final other = _otherClayController.text.trim();
        if (other.isNotEmpty) values.add(other);
      }
      return values.isEmpty ? null : values;
    }

    if (category == 'Jewelry & Accessories') {
      final values = List<String>.from(_selectedJewelryMaterials);
      if (values.contains('Other')) {
        values.remove('Other');
        final other = _otherJewelryMaterialController.text.trim();
        if (other.isNotEmpty) values.add(other);
      }
      return values.isEmpty ? null : values;
    }

    return null;
  }

  Future<void> _generateAIBio() async {
    setState(() => _isGeneratingBio = true);
    try {
      final String categoryEn = widget.selectedCategory['titleEn'];
      final String experience = _experienceController.text;

      final generatedBio = await AiService.generateBio(
        craftCategory: categoryEn,
        experience: experience,
        specializations: _currentSpecializations(),
        language: isArabic ? 'ar' : 'en',
      );

      if (generatedBio != null && generatedBio.isNotEmpty) {
        setState(() {
          _bioSuggestions.add(generatedBio);
          _currentBioIndex = _bioSuggestions.length - 1;
          _bioController.text = generatedBio;
        });
      } else {
        _showError(isArabic ? 'فشل توليد النبذة' : 'Failed to generate bio');
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingBio = false);
      }
    }
  }

  void _startOtpTimer() {
    setState(() => _otpCountdown = 59);
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpCountdown > 0) {
        setState(() => _otpCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _checkPasswordStrength() {
    String p = _passwordController.text;
    double strength = 0;
    if (p.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(p)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(p)) strength += 0.25;
    if (RegExp(r'[!@#\$&*~]').hasMatch(p)) strength += 0.25;
    setState(() {
      _passwordStrength = strength;
    });
  }

  Color _getPasswordStrengthColor() {
    if (_passwordStrength == 0) return Colors.transparent;
    if (_passwordStrength <= 0.25) return Colors.red;
    if (_passwordStrength <= 0.75) return Colors.orange;
    return Colors.green;
  }

  String _getPasswordStrengthText() {
    if (_passwordStrength == 0) return "";
    if (_passwordStrength <= 0.25) return isArabic ? "ضعيفة" : "Weak";
    if (_passwordStrength <= 0.75) return isArabic ? "متوسطة" : "Medium";
    return isArabic ? "قوية" : "Strong";
  }

  // Colors mapping
  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;
  Color get inputFillColor =>
      isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get borderColor => isDarkMode ? Colors.white12 : Colors.black12;
  Color get topIconColor => isDarkMode ? Colors.white : Colors.black87;
  Color get topButtonBackground =>
      isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get chipBorderColor => isDarkMode ? Colors.white12 : Colors.black12;

  void toggleLanguage() {
    setState(() {
      isArabic = !isArabic;
    });
    widget.onToggleLanguage();
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    widget.onToggleTheme();
  }

  Future<void> _nextStep() async {
    // Step 0: Basic Info
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError(isArabic
            ? 'الرجاء إدخال الاسم الكامل'
            : 'Please enter your full name');
        return;
      }
      if (_phoneController.text.trim().isEmpty ||
          _phoneController.text.trim().length < 9) {
        _showError(isArabic
            ? 'الرجاء إدخال رقم هاتف صحيح'
            : 'Please enter a valid phone number');
        return;
      }
      if (_emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@')) {
        _showError(isArabic
            ? 'الرجاء إدخال بريد إلكتروني صحيح'
            : 'Please enter a valid email');
        return;
      }
      if (_selectedCity == null) {
        _showError(
            isArabic ? 'الرجاء اختيار المدينة' : 'Please select your city');
        return;
      }
      // Validate custom category if it's "Other"
      if (_isCustomCategory) {
        final custom = _customCategoryController.text.trim();
        if (custom.isEmpty) {
          _showError(isArabic
              ? 'الرجاء كتابة اسم حرفتك'
              : 'Please enter your craft name');
          return;
        }
      }
      if (_passwordController.text.length < 8) {
        _showError(isArabic
            ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
            : 'Password must be at least 8 characters');
        return;
      }
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(_passwordController.text);
      final hasDigit = RegExp(r'[0-9]').hasMatch(_passwordController.text);
      if (!hasLetter || !hasDigit) {
        _showError(isArabic
            ? 'كلمة المرور يجب أن تحتوي على حروف وأرقام'
            : 'Password must contain both letters and numbers');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError(
            isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match');
        return;
      }

      _showAiCheckingDialog(
        title:
            isArabic ? 'جاري إرسال الرمز...' : 'Sending verification code...',
        subtitle: isArabic
            ? 'سيصل الرمز إلى بريدك الإلكتروني'
            : 'The code will be sent to your email',
      );

      bool success = false;
      try {
        success = await AuthService.sendOtp(
          _emailController.text.trim(),
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        success = false;
      } catch (_) {
        success = false;
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (!success) {
        _showError(
          isArabic
              ? 'تعذر إرسال رمز التحقق. تحققي من البريد والاتصال ثم حاولي مرة أخرى.'
              : 'Could not send the verification code. Check your email and connection, then try again.',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم إرسال رمز التحقق إلى ${_emailController.text.trim()}'
                : 'Verification code sent to ${_emailController.text.trim()}',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (_currentStep == 1) {
      // Step 1: Verify OTP
      final enteredOtp = _otpControllers.map((c) => c.text).join();
      if (enteredOtp.length < 4) {
        _showError(isArabic
            ? 'الرجاء إدخال رمز التحقق المكوّن من 4 أرقام'
            : 'Please enter the 4-digit OTP');
        return;
      }

      _showAiCheckingDialog(
        title: isArabic ? 'جاري التحقق...' : 'Verifying...',
        subtitle: '',
      );

      final success = await AuthService.verifyOtp(
        _emailController.text.trim(),
        enteredOtp,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (!success) {
        _showError(
          isArabic
              ? 'رمز التحقق غير صحيح أو منتهي الصلاحية'
              : 'Invalid or expired verification code',
        );
        return;
      }
    } else if (_currentStep == 2) {
      // Step 2: Craft Details
      if (_experienceController.text.trim().isEmpty) {
        _showError(isArabic
            ? 'الرجاء إدخال سنوات الخبرة'
            : 'Please enter years of experience');
        return;
      }
      if (_bioController.text.trim().length < 20) {
        _showError(isArabic
            ? 'الرجاء كتابة نبذة كافية (20 حرف على الأقل)'
            : 'Please write a sufficient bio (at least 20 characters)');
        return;
      }

      if (widget.selectedCategory['titleEn'] == 'Jewelry & Accessories' &&
          _selectedJewelryMaterials.isEmpty) {
        _showError(isArabic
            ? 'الرجاء اختيار مادة واحدة على الأقل'
            : 'Please select at least one material');
        return;
      }

      if (_selectedJewelryMaterials.contains('Other') &&
          _otherJewelryMaterialController.text.trim().isEmpty) {
        _showError(isArabic
            ? 'الرجاء كتابة المادة الأخرى'
            : 'Please specify the other material');
        return;
      }

      // AI Bio Validation
      _showAiCheckingDialog();
      final craftCategory = widget.selectedCategory['titleEn'] ?? 'Crafts';
      final result = await AiService.validateBio(
        bio: _bioController.text.trim(),
        craftCategory: craftCategory,
        language: isArabic ? 'ar' : 'en',
      );
      if (!mounted) return;
      Navigator.pop(context);

      final approved = result?['approved'] ?? true;
      final feedback = result?['feedback'] ?? '';

      if (!approved) {
        _showAiRejectionDialog(feedback);
        return;
      }
      if (feedback.isNotEmpty) {
        _showAiApprovedSnack(feedback);
      }
    } else if (_currentStep == 3) {
      // Step 3: Documents
      if (!_isPortfolioUploaded) {
        _showError(isArabic
            ? 'الرجاء تحميل صور نماذج من أعمالك (إلزامي)'
            : 'Please upload portfolio sample images (required)');
        return;
      }

      // Determine the category to send to backend
      String categoryToSend = widget.selectedCategory['titleEn'] ?? '';
      if (_isCustomCategory) {
        categoryToSend = _customCategoryController.text.trim();
      }

      // Save data to database
      _showAiCheckingDialog(
          title: isArabic ? 'جاري إنشاء الحساب...' : 'Creating account...',
          subtitle:
              isArabic ? 'نحفظ بياناتك بأمان' : 'Saving your data securely');
      final result = await AuthService.signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        roles: ['customer', 'artisan'],
        city: _selectedCity ?? 'Unknown',
        phone: _phoneController.text.trim(),
        category: categoryToSend,
        experienceYears: int.tryParse(_experienceController.text) ?? 0,
        bio: _bioController.text.trim(),
        priceRange: _selectedPriceRange,
        specializations: _currentSpecializations(),
        trustedHands: _isIdUploaded,
        idVerificationDetails: _idVerificationDetails,
        portfolioImageUrls: _portfolioImageUrls,
      );
      if (!mounted) return;
      Navigator.pop(context);

      if (result == null) {
        _showError(isArabic
            ? 'حدث خطأ أثناء إنشاء الحساب. الإيميل قد يكون مستخدماً.'
            : 'Error creating account. Email might be in use.');
        return;
      }
    }

    // Move to next step or submit
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      if (_currentStep == 1) {
        _startOtpTimer();
      }
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PendingVerificationScreen(
            isArabic: isArabic,
            isDarkMode: isDarkMode,
            onToggleLanguage: widget.onToggleLanguage,
            onToggleTheme: widget.onToggleTheme,
            selectedCategory: widget.selectedCategory,
          ),
        ),
        (route) => false,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAiCheckingDialog({String? title, String? subtitle}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: inputFillColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFD4A017)),
              const SizedBox(height: 20),
              Text(
                title ??
                    (isArabic
                        ? 'ذكاء اصطناعي يفحص نبذتك...'
                        : 'AI is reviewing your bio...'),
                style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ??
                    (isArabic
                        ? 'يتم التحقق من ملاءمة المحتوى واحترافيته'
                        : 'Checking content appropriateness and professionalism'),
                style: TextStyle(color: secondaryTextColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiRejectionDialog(String feedback) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: inputFillColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_outlined,
                  color: Color(0xFFD4A017), size: 48),
              const SizedBox(height: 12),
              Text(
                isArabic ? '🤖 تعليق الذكاء الاصطناعي' : '🤖 AI Feedback',
                style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  feedback,
                  style: TextStyle(
                      color: primaryTextColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A017),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  isArabic ? 'تعديل النبذة' : 'Edit Bio',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiApprovedSnack(String feedback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text('🤖 $feedback',
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
    String catTitle;
    if (_isCustomCategory) {
      catTitle = isArabic ? "حرفة مخصصة" : "Custom Craft";
    } else {
      catTitle = isArabic
          ? widget.selectedCategory['titleAr']
          : widget.selectedCategory['titleEn'];
    }

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topBarButton(
                      icon: isArabic
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios,
                      label: "",
                      onTap: _prevStep,
                    ),
                    Row(
                      children: [
                        _topBarButton(
                          icon: Icons.language,
                          label: isArabic ? "EN" : "عربي",
                          onTap: toggleLanguage,
                        ),
                        const SizedBox(width: 10),
                        _topBarButton(
                          icon: isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: "",
                          onTap: toggleTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Progress Indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: List.generate(_totalSteps, (index) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        decoration: BoxDecoration(
                          color: index <= _currentStep
                              ? const Color(0xFFD4A017)
                              : borderColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ─── Logo with Pulse + Shimmer ────────
                              Center(
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final scale = 1.0 +
                                        0.05 * (1.0 - _pulseController.value);
                                    return Transform.scale(
                                      scale: scale,
                                      child: AnimatedBuilder(
                                        animation: _shimmerController,
                                        builder: (context, child) {
                                          final dx = _shimmerController.value;
                                          return ShaderMask(
                                            blendMode: BlendMode.srcIn,
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                colors: _logoShimmerColors,
                                                stops: const [
                                                  0.0,
                                                  0.35,
                                                  0.5,
                                                  0.65,
                                                  1.0
                                                ],
                                                begin: Alignment(
                                                    -1.0 + dx * 3, -0.3),
                                                end: Alignment(
                                                    1.0 + dx * 3, 0.3),
                                                tileMode: TileMode.clamp,
                                              ).createShader(bounds);
                                            },
                                            child: Image.asset(
                                              'assets/images/logo.png',
                                              height: 150,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ─── Main Title (Cairo font) ──────────
                              Text(
                                isArabic ? "حساب جديد" : "Create Account",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: primaryTextColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),

                              // ─── Subtitle ──────────────────────────
                              Text(
                                isArabic
                                    ? "للانضمام كحرفي في مجال: $catTitle"
                                    : "Join as a craftsman in: $catTitle",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: const Color(0xFFD4A017),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Dynamic Steps
                              _buildCurrentStep(),

                              const SizedBox(height: 40),

                              // Action Buttons
                              Row(
                                children: [
                                  if (_currentStep > 0) ...[
                                    Expanded(
                                      flex: 1,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          side: BorderSide(color: borderColor),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        onPressed: _prevStep,
                                        child: Text(
                                          isArabic ? "السابق" : "Back",
                                          style: TextStyle(
                                              color: primaryTextColor),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF7B500),
                                            Color(0xFFD89A00),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF7B500)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        onPressed: _nextStep,
                                        child: Text(
                                          _currentStep == _totalSteps - 1
                                              ? (isArabic
                                                  ? "إنشاء الحساب"
                                                  : "Sign Up")
                                              : (isArabic ? "التالي" : "Next"),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ─── Already have an account? ──────────
                              if (_currentStep == 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isArabic
                                          ? "لديك حساب بالفعل؟"
                                          : "Already have an account?",
                                      style:
                                          TextStyle(color: secondaryTextColor),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Navigate to Customer Login Screen (no parameters)
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CustomerLoginScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        isArabic ? "تسجيل الدخول" : "Login",
                                        style: const TextStyle(
                                          color: Color(0xFFD4A017),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isArabic ? "البيانات الأساسية" : "Basic Info"),
        const SizedBox(height: 15),
        // If custom category, show text field for craft name
        if (_isCustomCategory)
          Column(
            children: [
              _buildTextField(
                label: isArabic ? "اسم حرفتك" : "Your Craft Name",
                icon: Icons.category_outlined,
                controller: _customCategoryController,
              ),
              const SizedBox(height: 15),
            ],
          ),
        _buildTextField(
          label: isArabic ? "الاسم الكامل" : "Full Name",
          icon: Icons.person_outline,
          controller: _nameController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          label: isArabic ? "رقم الهاتف" : "Phone Number",
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          controller: _phoneController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          label: isArabic ? "البريد الإلكتروني" : "Email",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),
        const SizedBox(height: 15),
        _buildCitySelector(),
        const SizedBox(height: 15),
        _buildTextField(
          label: isArabic ? "كلمة المرور" : "Password",
          icon: Icons.lock_outline,
          isPassword: true,
          controller: _passwordController,
        ),
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12, left: 12),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _getPasswordStrengthColor()),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _getPasswordStrengthText(),
                  style: TextStyle(
                    color: _getPasswordStrengthColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 15),
        _buildTextField(
          label: isArabic ? "تأكيد كلمة المرور" : "Confirm Password",
          icon: Icons.lock_reset_outlined,
          isPassword: true,
          controller: _confirmPasswordController,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            isArabic ? "تأكيد البريد الإلكتروني" : "Verify Email"),
        const SizedBox(height: 15),
        Text(
          isArabic
              ? "الرجاء إدخال رمز التحقق (OTP) المرسل إلى البريد\n${_emailController.text.isEmpty ? '****' : _emailController.text}"
              : "Please enter the OTP sent to\n${_emailController.text.isEmpty ? '****' : _emailController.text}",
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        const SizedBox(height: 25),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              return SizedBox(
                width: 60,
                height: 60,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFillColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Color(0xFFD4A017), width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      if (value.length > 1) {
                        _otpControllers[index].text = value[value.length - 1];
                        _otpControllers[index].selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: 1),
                        );
                      }
                      if (index < 3) {
                        FocusScope.of(context)
                            .requestFocus(_otpFocusNodes[index + 1]);
                      } else {
                        _otpFocusNodes[index].unfocus();
                      }
                    } else if (value.isEmpty && index > 0) {
                      FocusScope.of(context)
                          .requestFocus(_otpFocusNodes[index - 1]);
                    }
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _otpCountdown == 0
                ? () async {
                    _showAiCheckingDialog(
                        title: isArabic ? 'إعادة الإرسال...' : 'Resending...',
                        subtitle: '');
                    final success =
                        await AuthService.sendOtp(_emailController.text.trim());
                    if (!mounted) return;
                    Navigator.pop(context);
                    if (success) {
                      _startOtpTimer();
                    } else {
                      _showError(isArabic ? 'فشل الإرسال' : 'Failed to send');
                    }
                  }
                : null,
            child: Text(
              _otpCountdown > 0
                  ? (isArabic
                      ? "إعادة الإرسال بعد ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}"
                      : "Resend code in ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}")
                  : (isArabic ? "إعادة إرسال الرمز" : "Resend Code"),
              style: TextStyle(
                color: _otpCountdown > 0
                    ? secondaryTextColor
                    : const Color(0xFFD4A017),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    String titleEn = widget.selectedCategory['titleEn'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isArabic ? "تفاصيل الحرفة" : "Craft Details"),
        const SizedBox(height: 15),
        // Experience Stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: inputFillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: secondaryTextColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isArabic ? "سنوات الخبرة" : "Years of Experience",
                  style: TextStyle(color: secondaryTextColor, fontSize: 16),
                ),
              ),
              InkWell(
                onTap: () {
                  final current = int.tryParse(_experienceController.text) ?? 0;
                  if (current > 0) {
                    setState(() {
                      _experienceController.text = (current - 1).toString();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.remove, color: secondaryTextColor, size: 24),
                ),
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                child: Text(
                  _experienceController.text.isEmpty
                      ? '0'
                      : _experienceController.text,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  final current = int.tryParse(_experienceController.text) ?? 0;
                  setState(() {
                    _experienceController.text = (current + 1).toString();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.add, color: Color(0xFFD4A017), size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _bioController,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(color: primaryTextColor),
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            labelText:
                isArabic ? "نبذة عنك وعن أعمالك" : "Bio & Work Description",
            labelStyle: TextStyle(color: secondaryTextColor),
            prefixIcon: Icon(Icons.info_outline, color: secondaryTextColor),
            alignLabelWithHint: true,
            filled: true,
            fillColor: inputFillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFD4A017), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isArabic
                    ? "سيتولى الذكاء الاصطناعي مراجعة النبذة لضمان الاحترافية"
                    : "AI will review your bio to ensure professionalism",
                style: const TextStyle(color: Color(0xFFD4A017), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main generate button
              InkWell(
                onTap: _isGeneratingBio ? null : _generateAIBio,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withValues(alpha: 0.3),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4A017), Color(0xFFE8C86A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4A017).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGeneratingBio)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else
                        Icon(
                          _bioSuggestions.isEmpty
                              ? Icons.auto_awesome
                              : Icons.refresh,
                          color: Colors.white,
                          size: 18,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isGeneratingBio
                            ? (isArabic ? 'جاري الإنشاء...' : 'Generating...')
                            : _bioSuggestions.isEmpty
                                ? (isArabic
                                    ? '✨ إنشاء نبذة احترافية'
                                    : '✨ Generate Professional Bio')
                                : (isArabic ? '↻ اقتراح آخر' : '↻ Try Another'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Navigation arrows between suggestions
              if (_bioSuggestions.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFD4A017).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _currentBioIndex > 0
                            ? () {
                                setState(() {
                                  _currentBioIndex--;
                                  _bioController.text =
                                      _bioSuggestions[_currentBioIndex];
                                });
                              }
                            : null,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Icon(
                            isArabic ? Icons.chevron_right : Icons.chevron_left,
                            color: _currentBioIndex > 0
                                ? const Color(0xFFD4A017)
                                : const Color(0xFFD4A017)
                                    .withValues(alpha: 0.3),
                            size: 18,
                          ),
                        ),
                      ),
                      Text(
                        '${_currentBioIndex + 1}/${_bioSuggestions.length}',
                        style: const TextStyle(
                          color: Color(0xFFD4A017),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: _currentBioIndex < _bioSuggestions.length - 1
                            ? () {
                                setState(() {
                                  _currentBioIndex++;
                                  _bioController.text =
                                      _bioSuggestions[_currentBioIndex];
                                });
                              }
                            : null,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Icon(
                            isArabic ? Icons.chevron_left : Icons.chevron_right,
                            color: _currentBioIndex < _bioSuggestions.length - 1
                                ? const Color(0xFFD4A017)
                                : const Color(0xFFD4A017)
                                    .withValues(alpha: 0.3),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isArabic ? "متوسط سعر القطعة (JOD)" : "Average Piece Price (JOD)",
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_priceRangesEn.length, (index) {
            final enLabel = _priceRangesEn[index];
            final isSelected = _selectedPriceRange == enLabel;
            return ChoiceChip(
              label: Directionality(
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  isArabic ? _priceRangesAr[index] : enLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.black : primaryTextColor,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedPriceRange = selected ? enLabel : null;
                });
              },
              selectedColor: const Color(0xFFD4A017),
              backgroundColor: inputFillColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFD4A017) : borderColor,
                ),
              ),
              showCheckmark: false,
            );
          }),
        ),
        const SizedBox(height: 15),
        if (titleEn == "Crochet & Knitting")
          TextFormField(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              labelText: isArabic
                  ? "هل توفر خدمة التفصيل حسب المقاس؟"
                  : "Do you offer custom sizing?",
              labelStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Icon(Icons.straighten, color: secondaryTextColor),
              filled: true,
              fillColor: inputFillColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFD4A017), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        if (titleEn == "Pottery & Ceramics")
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic
                    ? "ما هي أنواع الطين المستخدمة؟"
                    : "Types of clay used?",
                style: TextStyle(color: secondaryTextColor, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_clayOptionsEn.length, (index) {
                  final enLabel = _clayOptionsEn[index];
                  final isSelected = _selectedClays.contains(enLabel);
                  return FilterChip(
                    label: Text(
                      isArabic ? _clayOptionsAr[index] : enLabel,
                      style: TextStyle(
                        color: isSelected ? Colors.black : primaryTextColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedClays.add(enLabel);
                        } else {
                          _selectedClays.remove(enLabel);
                        }
                      });
                    },
                    selectedColor: const Color(0xFFD4A017),
                    backgroundColor: inputFillColor,
                    checkmarkColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected ? const Color(0xFFD4A017) : borderColor,
                      ),
                    ),
                  );
                }),
              ),
              if (_selectedClays.contains('Other')) ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _otherClayController,
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? "يرجى تحديد أنواع أخرى"
                        : "Please specify other types",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon:
                        Icon(Icons.edit_outlined, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Color(0xFFD4A017), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        if (titleEn == "Jewelry & Accessories")
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? "المواد التي تعمل بها" : "Materials you work with",
                style: TextStyle(color: secondaryTextColor, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_jewelryMaterialsEn.length, (index) {
                  final enLabel = _jewelryMaterialsEn[index];
                  final isSelected =
                      _selectedJewelryMaterials.contains(enLabel);
                  return FilterChip(
                    avatar: enLabel == 'Other'
                        ? Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color:
                                isSelected ? Colors.black : secondaryTextColor,
                          )
                        : null,
                    label: Text(
                      isArabic ? _jewelryMaterialsAr[index] : enLabel,
                      style: TextStyle(
                        color: isSelected ? Colors.black : primaryTextColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedJewelryMaterials.add(enLabel);
                        } else {
                          _selectedJewelryMaterials.remove(enLabel);
                          if (enLabel == 'Other') {
                            _otherJewelryMaterialController.clear();
                          }
                        }
                      });
                    },
                    selectedColor: const Color(0xFFD4A017),
                    backgroundColor: inputFillColor,
                    checkmarkColor: Colors.black,
                    showCheckmark: enLabel != 'Other',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected ? const Color(0xFFD4A017) : borderColor,
                      ),
                    ),
                  );
                }),
              ),
              if (_selectedJewelryMaterials.contains('Other')) ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _otherJewelryMaterialController,
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? "اكتب مادة أخرى"
                        : "Specify another material",
                    hintText: isArabic
                        ? "مثال: أحجار طبيعية، جلد..."
                        : "e.g. natural stones, leather...",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.65),
                    ),
                    prefixIcon:
                        Icon(Icons.edit_outlined, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFD4A017),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _pickAndUploadIdImage() async {
    try {
      final XFile? pickedImage = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (context) => IDCameraScreen(isArabic: isArabic),
        ),
      );

      if (pickedImage == null) return;

      setState(() {
        _isUploadingId = true;
        _idUploadStatus = 'analyzing';
      });

      final result = await UploadService.uploadAndVerifyIdImage(pickedImage);

      if (!mounted) return;

      setState(() {
        _idImageUrl = result.url;
        _idImagePath = pickedImage.path;
        _isIdUploaded = true;
        _idVerificationDetails = result.verificationData;
        _idUploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم فحص ورفع صورة الهوية بنجاح'
                : 'ID image verified and uploaded successfully',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on IDVerificationException catch (e) {
      _showError(e.message);
      setState(() {
        _idUploadStatus = '';
        _idVerificationDetails = e.verificationData;
      });
    } catch (e) {
      _showError(
        isArabic ? 'حدث خطأ أثناء رفع الصورة: $e' : 'Error: $e',
      );
      setState(() {
        _idUploadStatus = '';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingId = false);
      }
    }
  }

  Future<void> _pickAndUploadPortfolioImages() async {
    try {
      final List<XFile> pickedImages =
          await _imagePicker.pickMultiImage(imageQuality: 80);

      if (pickedImages.isEmpty) return;

      setState(() => _isUploadingPortfolio = true);

      final uploadedUrls = await UploadService.uploadImages(pickedImages);

      if (!mounted) return;

      if (uploadedUrls.isEmpty) {
        _showError(
          isArabic
              ? 'فشل رفع صور الأعمال'
              : 'Failed to upload portfolio images',
        );
        return;
      }

      setState(() {
        _portfolioImageUrls.addAll(uploadedUrls);
        _portfolioImagePaths.addAll(pickedImages.map((image) => image.path));

        _isPortfolioUploaded = _portfolioImageUrls.isNotEmpty;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم رفع ${uploadedUrls.length} صورة بنجاح'
                : '${uploadedUrls.length} images uploaded successfully',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError(
        isArabic ? 'فشل رفع صور الأعمال: $e' : 'Error: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPortfolio = false);
      }
    }
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isArabic ? "التوثيق والأمان" : "Verification"),
        const SizedBox(height: 10),
        Text(
          isArabic
              ? "تحميل صور أعمالك إلزامي لبدء استقبال الطلبات. أما صورة الهوية فهي اختيارية وتساعدك فقط في الحصول على شارة «أيدٍ موثوقة» لزيادة ثقة الزبائن."
              : "Uploading portfolio samples is required to start receiving orders. The National ID is optional and only needed to earn the \"Trusted Hands\" verification badge.",
          style:
              TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: inputFillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_outline,
                        color: secondaryTextColor, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      isArabic ? "حساب عادي" : "Standard",
                      style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFD4A017).withValues(alpha: 0.5),
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified,
                        color: Color(0xFFD4A017), size: 28),
                    const SizedBox(height: 6),
                    Text(
                      isArabic ? "أيدٍ موثوقة" : "Trusted Hands",
                      style: const TextStyle(
                          color: Color(0xFFD4A017),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A017).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFD4A017).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFD4A017), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? "صورة الهوية اختيارية — تمنحك شارة «أيدٍ موثوقة» عند الموافقة عليها."
                      : "ID is optional - submitting it earns you the \"Trusted Hands\" badge after admin approval.",
                  style:
                      const TextStyle(color: Color(0xFFD4A017), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildUploadButton(
          label: isArabic
              ? "صورة الهوية الوطنية (اختياري)"
              : "National ID Image (Optional)",
          icon: Icons.badge_outlined,
          isUploaded: _isIdUploaded,
          isOptional: true,
          onTap: _isUploadingId ? () {} : _pickAndUploadIdImage,
        ),
        if (_isUploadingId) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFD4A017),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _idUploadStatus == 'analyzing'
                    ? (isArabic
                        ? 'جاري تحليل الصورة بالذكاء الاصطناعي...'
                        : 'Analyzing image with AI...')
                    : (isArabic ? 'جاري الرفع...' : 'Uploading...'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
        if (_idImageUrl != null) ...[
          const SizedBox(height: 12),
          _buildSelectedImagePreview(
            imageUrl: _idImageUrl!,
            title: isArabic ? "معاينة صورة الهوية" : "ID Image Preview",
            onDelete: () {
              setState(() {
                _idImagePath = null;
                _idImageUrl = null;
                _isIdUploaded = false;
              });
            },
          ),
        ],
        const SizedBox(height: 15),
        _buildUploadButton(
          label: isArabic ? "صور نماذج من أعمالك" : "Portfolio Sample Images",
          icon: Icons.image_outlined,
          isUploaded: _isPortfolioUploaded,
          isOptional: false,
          onTap: _isUploadingPortfolio ? () {} : _pickAndUploadPortfolioImages,
        ),
        if (_isUploadingPortfolio) ...[
          const SizedBox(height: 12),
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD4A017),
            ),
          ),
        ],
        if (_portfolioImageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            isArabic
                ? "الأعمال المختارة (${_portfolioImageUrls.length})"
                : "Selected Works (${_portfolioImageUrls.length})",
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _portfolioImageUrls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _portfolioImageUrls[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _portfolioImageUrls.removeAt(index);
                          if (index < _portfolioImagePaths.length) {
                            _portfolioImagePaths.removeAt(index);
                          }
                          _isPortfolioUploaded = _portfolioImageUrls.isNotEmpty;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _startAIVerification() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: inputFillColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.document_scanner,
                      size: 48, color: Color(0xFFD4A017)),
                  const SizedBox(height: 16),
                  Text(
                    isArabic
                        ? "الذكاء الاصطناعي يتحقق من الهوية..."
                        : "AI is verifying ID...",
                    style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: Color(0xFFD4A017)),
                ],
              ),
            ),
          );
        });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: inputFillColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user,
                        size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? "تم التحقق بنجاح!" : "Verified Successfully!",
                      style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? "دقة التطابق: 98%\nتم توثيق الهوية عبر الذكاء الاصطناعي وتقليل وقت المراجعة."
                          : "Match Confidence: 98%\nID verified by AI, reducing admin review time.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondaryTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _isIdUploaded = true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A017),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isArabic ? "متابعة" : "Continue",
                        style: const TextStyle(
                            color: Color(0xFF0D1420),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }

  Widget _buildSelectedImagePreview({
    required String imageUrl,
    required String title,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A017)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFD4A017),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextEditingController? controller,
  }) {
    if (!isPassword) {
      return TextFormField(
        controller: controller,
        style: TextStyle(color: primaryTextColor),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Icon(icon, color: secondaryTextColor),
          filled: true,
          fillColor: inputFillColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    }

    // Password field with eye toggle
    return StatefulBuilder(
      builder: (context, setFieldState) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return TextFormField(
              controller: controller,
              style: TextStyle(color: primaryTextColor),
              obscureText: obscure,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(icon, color: secondaryTextColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: secondaryTextColor,
                  ),
                  onPressed: () {
                    setInnerState(() {
                      obscure = !obscure;
                    });
                  },
                ),
                filled: true,
                fillColor: inputFillColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4A017), width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUploadButton({
    required String label,
    required IconData icon,
    required bool isUploaded,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isUploaded
              ? const Color(0xFFD4A017).withValues(alpha: 0.05)
              : inputFillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isUploaded ? const Color(0xFFD4A017) : borderColor,
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon,
                      color: isUploaded
                          ? const Color(0xFFD4A017)
                          : secondaryTextColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isUploaded
                                ? const Color(0xFFD4A017)
                                : primaryTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isOptional)
                          Text(
                            isArabic
                                ? "ستمنحك شارة «أيدٍ موثوقة»"
                                : "Earns \"Trusted Hands\" badge",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isUploaded) const Icon(Icons.check_circle, color: Colors.green),
            if (!isUploaded) Icon(Icons.upload_file, color: secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    return InkWell(
      onTap: _showCityPickerSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: inputFillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: secondaryTextColor),
                const SizedBox(width: 12),
                Text(
                  _selectedCity ?? (isArabic ? "المدينة" : "City"),
                  style: TextStyle(
                    color: _selectedCity != null
                        ? primaryTextColor
                        : secondaryTextColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down, color: secondaryTextColor),
          ],
        ),
      ),
    );
  }

  void _showCityPickerSheet() {
    final List<String> cities = isArabic
        ? [
            "نابلس",
            "رام الله",
            "الخليل",
            "جنين",
            "بيت لحم",
            "طولكرم",
            "أريحا",
            "قلقيلية",
            "سلفيت",
            "طوباس",
            "غزة",
            "القدس"
          ]
        : [
            "Nablus",
            "Ramallah",
            "Hebron",
            "Jenin",
            "Bethlehem",
            "Tulkarm",
            "Jericho",
            "Qalqilya",
            "Salfit",
            "Tubas",
            "Gaza",
            "Jerusalem"
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        bool localLocating = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isArabic ? "تحديد المدينة" : "Select City",
                      style: GoogleFonts.cairo(
                        color: primaryTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // GPS Auto Detect
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFD4A017).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFD4A017),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                              color: Color(0xFFD4A017), width: 1.5),
                        ),
                      ),
                      onPressed: localLocating
                          ? null
                          : () {
                              setModalState(() => localLocating = true);
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              Future.delayed(const Duration(milliseconds: 1500),
                                  () {
                                if (!mounted) return;
                                if (nav.canPop()) {
                                  nav.pop();
                                  setState(() {
                                    _selectedCity =
                                        isArabic ? "نابلس" : "Nablus";
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      content: Text(
                                        isArabic
                                            ? "تم تحديد موقعك تلقائياً: نابلس"
                                            : "Location resolved automatically: Nablus",
                                        style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                              });
                            },
                      icon: localLocating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Color(0xFFD4A017))),
                            )
                          : const Icon(Icons.gps_fixed),
                      label: Text(
                        localLocating
                            ? (isArabic
                                ? "جاري تحديد الموقع..."
                                : "Detecting Location...")
                            : (isArabic
                                ? "تحديد تلقائي عبر GPS"
                                : "Auto-detect via GPS"),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            isArabic
                                ? "أو اختر المدينة يدوياً"
                                : "Or select city manually",
                            style: TextStyle(
                                color: secondaryTextColor, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: borderColor)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Cities Grid
                    Expanded(
                      child: GridView.builder(
                        shrinkWrap: false,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: cities.length,
                        itemBuilder: (context, index) {
                          final city = cities[index];
                          final isSel = _selectedCity == city;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCity = city;
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFFD4A017)
                                        .withValues(alpha: 0.15)
                                    : inputFillColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSel
                                        ? const Color(0xFFD4A017)
                                        : borderColor),
                              ),
                              child: Text(
                                city,
                                style: GoogleFonts.cairo(
                                  color: isSel
                                      ? const Color(0xFFD4A017)
                                      : primaryTextColor,
                                  fontSize: 13,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _topBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: topButtonBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: topIconColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: topIconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../services/ai_service.dart';
// import '../services/auth_service.dart';
// import 'dart:async';
// import 'craftsman_login_screen.dart';
// import 'pending_verification_screen.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/upload_service.dart';
// import 'id_camera_screen.dart';

// class CraftsmanRegistrationScreen extends StatefulWidget {
//   final Map<String, dynamic> selectedCategory;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onToggleLanguage;
//   final VoidCallback onToggleTheme;

//   const CraftsmanRegistrationScreen({
//     super.key,
//     required this.selectedCategory,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onToggleLanguage,
//     required this.onToggleTheme,
//   });

//   @override
//   State<CraftsmanRegistrationScreen> createState() =>
//       _CraftsmanRegistrationScreenState();
// }

// class _CraftsmanRegistrationScreenState
//     extends State<CraftsmanRegistrationScreen> {
//   late bool isArabic;
//   late bool isDarkMode;

//   final _formKey = GlobalKey<FormState>();
//   int _currentStep = 0;
//   final int _totalSteps = 4;

//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//   TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _experienceController = TextEditingController();
//   final TextEditingController _bioController = TextEditingController();
//   final List<TextEditingController> _otpControllers =
//   List.generate(4, (_) => TextEditingController());
//   final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

//   final List<String> _clayOptionsAr = [
//     'ط®ط²ظپ ط£ط­ظ…ط±',
//     'ط¨ظˆط±ط³ظ„ط§ظ†',
//     'Stoneware (ط·ظٹظ† ط­ط¬ط±ظٹ)',
//     'ط·ظٹظ† ط£ط¨ظٹط¶',
//     'ظپط®ط§ط±',
//     'ط£ط®ط±ظ‰'
//   ];
//   final List<String> _clayOptionsEn = [
//     'Red Clay',
//     'Porcelain',
//     'Stoneware',
//     'White Clay',
//     'Earthenware',
//     'Other'
//   ];
//   final List<String> _selectedClays = [];
//   final TextEditingController _otherClayController = TextEditingController();

//   final List<String> _jewelryMaterialsEn = [
//     'Gold',
//     'Silver',
//     'Stainless Steel',
//     'Brass',
//     'Copper',
//     'Beads',
//     'Resin',
//     'Other',
//   ];

//   final List<String> _jewelryMaterialsAr = [
//     'ذهب',
//     'فضة',
//     'ستانلس ستيل',
//     'نحاس أصفر',
//     'نحاس',
//     'خرز',
//     'ريزن',
//     'أخرى',
//   ];

//   final List<String> _selectedJewelryMaterials = [];
//   final TextEditingController _otherJewelryMaterialController =
//   TextEditingController();

//   final List<String> _priceRangesAr = [
//     'أقل من 50',
//     '50 - 150',
//     '150 - 300',
//     'أكثر من 300'
//   ];
//   final List<String> _priceRangesEn = [
//     'Under 50',
//     '50 - 150',
//     '150 - 300',
//     'Over 300'
//   ];
//   String? _selectedPriceRange;

//   double _passwordStrength = 0.0;
//   bool _isIdUploaded = false;
//   bool _isPortfolioUploaded = false;
//   bool _isGeneratingBio = false;
//   final List<String> _bioSuggestions = [];
//   int _currentBioIndex = -1;

//   final ImagePicker _imagePicker = ImagePicker();
//   String? _idImageUrl;
//   String? _idImagePath;
//   final List<String> _portfolioImageUrls = [];
//   final List<String> _portfolioImagePaths = [];
//   bool _isUploadingId = false;
//   bool _isUploadingPortfolio = false;
//   Map<String, dynamic>? _idVerificationDetails;
//   String _idUploadStatus = ''; // 'analyzing', 'uploading', ''
//   String? _selectedCity;
//   int _otpCountdown = 59;
//   Timer? _otpTimer;

//   @override
//   void initState() {
//     super.initState();
//     isArabic = widget.isArabic;
//     isDarkMode = widget.isDarkMode;

//     _passwordController.addListener(_checkPasswordStrength);
//   }

//   @override
//   void dispose() {
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     _phoneController.dispose();
//     _nameController.dispose();
//     _emailController.dispose();
//     _experienceController.dispose();
//     _bioController.dispose();
//     _otherClayController.dispose();
//     _otherJewelryMaterialController.dispose();
//     for (var c in _otpControllers) {
//       c.dispose();
//     }
//     for (var f in _otpFocusNodes) {
//       f.dispose();
//     }
//     _otpTimer?.cancel();
//     super.dispose();
//   }

//   List<String>? _currentSpecializations() {
//     final String category = widget.selectedCategory['titleEn'] ?? '';

//     if (category == 'Pottery & Ceramics') {
//       final values = List<String>.from(_selectedClays);
//       if (values.contains('Other')) {
//         values.remove('Other');
//         final other = _otherClayController.text.trim();
//         if (other.isNotEmpty) values.add(other);
//       }
//       return values.isEmpty ? null : values;
//     }

//     if (category == 'Jewelry & Accessories') {
//       final values = List<String>.from(_selectedJewelryMaterials);
//       if (values.contains('Other')) {
//         values.remove('Other');
//         final other = _otherJewelryMaterialController.text.trim();
//         if (other.isNotEmpty) values.add(other);
//       }
//       return values.isEmpty ? null : values;
//     }

//     return null;
//   }

//   Future<void> _generateAIBio() async {
//     setState(() => _isGeneratingBio = true);
//     try {
//       final String categoryEn = widget.selectedCategory['titleEn'];
//       final String experience = _experienceController.text;

//       final generatedBio = await AiService.generateBio(
//         craftCategory: categoryEn,
//         experience: experience,
//         specializations: _currentSpecializations(),
//         language: isArabic ? 'ar' : 'en',
//       );

//       if (generatedBio != null && generatedBio.isNotEmpty) {
//         setState(() {
//           _bioSuggestions.add(generatedBio);
//           _currentBioIndex = _bioSuggestions.length - 1;
//           _bioController.text = generatedBio;
//         });
//       } else {
//         _showError(isArabic ? 'ظپط´ظ„ طھظˆظ„ظٹط¯ ط§ظ„ظ†ط¨ط°ط©' : 'Failed to generate bio');
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isGeneratingBio = false);
//       }
//     }
//   }

//   void _startOtpTimer() {
//     setState(() => _otpCountdown = 59);
//     _otpTimer?.cancel();
//     _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_otpCountdown > 0) {
//         setState(() => _otpCountdown--);
//       } else {
//         timer.cancel();
//       }
//     });
//   }

//   void _checkPasswordStrength() {
//     String p = _passwordController.text;
//     double strength = 0;
//     if (p.length >= 8) strength += 0.25;
//     if (RegExp(r'[A-Z]').hasMatch(p)) strength += 0.25;
//     if (RegExp(r'[0-9]').hasMatch(p)) strength += 0.25;
//     if (RegExp(r'[!@#\$&*~]').hasMatch(p)) strength += 0.25;
//     setState(() {
//       _passwordStrength = strength;
//     });
//   }

//   Color _getPasswordStrengthColor() {
//     if (_passwordStrength == 0) return Colors.transparent;
//     if (_passwordStrength <= 0.25) return Colors.red;
//     if (_passwordStrength <= 0.75) return Colors.orange;
//     return Colors.green;
//   }

//   String _getPasswordStrengthText() {
//     if (_passwordStrength == 0) return "";
//     if (_passwordStrength <= 0.25) return isArabic ? "ضعيفة" : "Weak";
//     if (_passwordStrength <= 0.75) return isArabic ? "متوسطة" : "Medium";
//     return isArabic ? "قوية" : "Strong";
//   }

//   // Colors mapping
//   Color get backgroundColor =>
//       isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;
//   Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;
//   Color get inputFillColor =>
//       isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get borderColor => isDarkMode ? Colors.white12 : Colors.black12;
//   Color get topIconColor => isDarkMode ? Colors.white : Colors.black87;
//   Color get topButtonBackground =>
//       isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get chipBorderColor => isDarkMode ? Colors.white12 : Colors.black12;

//   void toggleLanguage() {
//     setState(() {
//       isArabic = !isArabic;
//     });
//     widget.onToggleLanguage();
//   }

//   void toggleTheme() {
//     setState(() {
//       isDarkMode = !isDarkMode;
//     });
//     widget.onToggleTheme();
//   }

//   Future<void> _nextStep() async {
//     // --- Validation per step ---
//     if (_currentStep == 0) {
//       // Step 1: Basic Info
//       if (_nameController.text.trim().isEmpty) {
//         _showError(isArabic
//             ? 'الرجاء إدخال الاسم الكامل'
//             : 'Please enter your full name');
//         return;
//       }
//       if (_phoneController.text.trim().isEmpty ||
//           _phoneController.text.trim().length < 9) {
//         _showError(isArabic
//             ? 'الرجاء إدخال رقم هاتف صحيح'
//             : 'Please enter a valid phone number');
//         return;
//       }
//       if (_emailController.text.trim().isEmpty ||
//           !_emailController.text.contains('@')) {
//         _showError(isArabic
//             ? 'الرجاء إدخال بريد إلكتروني صحيح'
//             : 'Please enter a valid email');
//         return;
//       }
//       if (_selectedCity == null) {
//         _showError(
//             isArabic ? 'الرجاء اختيار المدينة' : 'Please select your city');
//         return;
//       }
//       if (_passwordController.text.length < 8) {
//         _showError(isArabic
//             ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
//             : 'Password must be at least 8 characters');
//         return;
//       }
//       // Must contain at least one letter AND one number
//       final hasLetter =
//       RegExp(r'[A-Za-z]').hasMatch(_passwordController.text);
//       final hasDigit = RegExp(r'[0-9]').hasMatch(_passwordController.text);
//       if (!hasLetter || !hasDigit) {
//         _showError(isArabic
//             ? 'كلمة المرور يجب أن تحتوي على حروف وأرقام'
//             : 'Password must contain both letters and numbers');
//         return;
//       }
//       if (_passwordController.text != _confirmPasswordController.text) {
//         _showError(
//             isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match');
//         return;
//       }
//       // Send real OTP via Email with timeout + clear feedback.
//       _showAiCheckingDialog(
//         title:
//         isArabic ? 'جاري إرسال الرمز...' : 'Sending verification code...',
//         subtitle: isArabic
//             ? 'سيصل الرمز إلى بريدك الإلكتروني'
//             : 'The code will be sent to your email',
//       );

//       bool success = false;
//       try {
//         success = await AuthService.sendOtp(
//           _emailController.text.trim(),
//         ).timeout(const Duration(seconds: 15));
//       } on TimeoutException {
//         success = false;
//       } catch (_) {
//         success = false;
//       }

//       if (!mounted) return;
//       Navigator.pop(context); // dismiss dialog

//       if (!success) {
//         _showError(
//           isArabic
//               ? 'تعذر إرسال رمز التحقق. تحققي من البريد والاتصال ثم حاولي مرة أخرى.'
//               : 'Could not send the verification code. Check your email and connection, then try again.',
//         );
//         return;
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             isArabic
//                 ? 'تم إرسال رمز التحقق إلى ${_emailController.text.trim()}'
//                 : 'Verification code sent to ${_emailController.text.trim()}',
//           ),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } else if (_currentStep == 1) {
//       // Step 2: Verify OTP
//       final enteredOtp = _otpControllers.map((c) => c.text).join();
//       if (enteredOtp.length < 4) {
//         _showError(isArabic
//             ? 'الرجاء إدخال رمز التحقق المكوّن من 4 أرقام'
//             : 'Please enter the 4-digit OTP');
//         return;
//       }

//       _showAiCheckingDialog(
//         title: isArabic ? 'جاري التحقق...' : 'Verifying...',
//         subtitle: '',
//       );

//       final success = await AuthService.verifyOtp(
//         _emailController.text.trim(),
//         enteredOtp,
//       );

//       if (!mounted) return;
//       Navigator.pop(context); // dismiss dialog

//       if (!success) {
//         _showError(
//           isArabic
//               ? 'رمز التحقق غير صحيح أو منتهي الصلاحية'
//               : 'Invalid or expired verification code',
//         );
//         return;
//       }
//     } else if (_currentStep == 2) {
//       // Step 3: Craft Details â€” validate fields then call AI for bio check
//       if (_experienceController.text.trim().isEmpty) {
//         _showError(isArabic
//             ? 'ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط³ظ†ظˆط§طھ ط§ظ„ط®ط¨ط±ط©'
//             : 'Please enter years of experience');
//         return;
//       }
//       if (_bioController.text.trim().length < 20) {
//         _showError(isArabic
//             ? 'ط§ظ„ط±ط¬ط§ط، ظƒطھط§ط¨ط© ظ†ط¨ط°ط© ظƒط§ظپظٹط© (20 ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„)'
//             : 'Please write a sufficient bio (at least 20 characters)');
//         return;
//       }

//       if (widget.selectedCategory['titleEn'] == 'Jewelry & Accessories' &&
//           _selectedJewelryMaterials.isEmpty) {
//         _showError(isArabic
//             ? 'الرجاء اختيار مادة واحدة على الأقل'
//             : 'Please select at least one material');
//         return;
//       }

//       if (_selectedJewelryMaterials.contains('Other') &&
//           _otherJewelryMaterialController.text.trim().isEmpty) {
//         _showError(isArabic
//             ? 'الرجاء كتابة المادة الأخرى'
//             : 'Please specify the other material');
//         return;
//       }

//       // ًں¤– AI Bio Validation
//       _showAiCheckingDialog();
//       final craftCategory = widget.selectedCategory['titleEn'] ?? 'Crafts';
//       final result = await AiService.validateBio(
//         bio: _bioController.text.trim(),
//         craftCategory: craftCategory,
//         language: isArabic ? 'ar' : 'en',
//       );
//       if (!mounted) return;
//       Navigator.pop(context); // dismiss AI checking dialog

//       final approved = result?['approved'] ?? true;
//       final feedback = result?['feedback'] ?? '';

//       if (!approved) {
//         _showAiRejectionDialog(feedback);
//         return;
//       }
//       // Show success feedback briefly
//       if (feedback.isNotEmpty) {
//         _showAiApprovedSnack(feedback);
//       }
//     } else if (_currentStep == 3) {
//       // Step 4: Documents â€” Portfolio is mandatory
//       if (!_isPortfolioUploaded) {
//         _showError(isArabic
//             ? 'ط§ظ„ط±ط¬ط§ط، طھط­ظ…ظٹظ„ طµظˆط± ظ†ظ…ط§ط°ط¬ ظ…ظ† ط£ط¹ظ…ط§ظ„ظƒ (ط¥ظ„ط²ط§ظ…ظٹ)'
//             : 'Please upload portfolio sample images (required)');
//         return;
//       }

//       // Save data to database
//       _showAiCheckingDialog(
//           title: isArabic ? 'ط¬ط§ط±ظٹ ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨...' : 'Creating account...',
//           subtitle:
//           isArabic ? 'ظ†ط­ظپط¸ ط¨ظٹط§ظ†ط§طھظƒ ط¨ط£ظ…ط§ظ†' : 'Saving your data securely');
//       final result = await AuthService.signup(
//         name: _nameController.text.trim(),
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//         roles: ['customer', 'artisan'],
//         city: _selectedCity ?? 'Unknown',
//         phone: _phoneController.text.trim(),
//         category: widget.selectedCategory['titleEn'],
//         experienceYears: int.tryParse(_experienceController.text) ?? 0,
//         bio: _bioController.text.trim(),
//         priceRange: _selectedPriceRange,
//         specializations: _currentSpecializations(),
//         trustedHands: _isIdUploaded,
//         idVerificationDetails: _idVerificationDetails,
//         portfolioImageUrls: _portfolioImageUrls,
//       );
//       if (!mounted) return;
//       Navigator.pop(context); // dismiss dialog

//       if (result == null) {
//         _showError(isArabic
//             ? 'ط­ط¯ط« ط®ط·ط£ ط£ط«ظ†ط§ط، ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨. ط§ظ„ط¥ظٹظ…ظٹظ„ ظ‚ط¯ ظٹظƒظˆظ† ظ…ط³طھط®ط¯ظ…ط§ظ‹.'
//             : 'Error creating account. Email might be in use.');
//         return;
//       }
//     }

//     // All validations passed â†’ go to next step
//     if (_currentStep < _totalSteps - 1) {
//       setState(() {
//         _currentStep++;
//       });
//       if (_currentStep == 1) {
//         _startOtpTimer();
//       }
//     } else {
//       // Submit â†’ Go to pending verification
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PendingVerificationScreen(
//             isArabic: isArabic,
//             isDarkMode: isDarkMode,
//             onToggleLanguage: widget.onToggleLanguage,
//             onToggleTheme: widget.onToggleTheme,
//             selectedCategory: widget.selectedCategory,
//           ),
//         ),
//             (route) => false,
//       );
//     }
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error_outline, color: Colors.white),
//             const SizedBox(width: 10),
//             Expanded(
//                 child: Text(message,
//                     style: const TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold))),
//           ],
//         ),
//         backgroundColor: Colors.redAccent,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _showAiCheckingDialog({String? title, String? subtitle}) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => Dialog(
//         backgroundColor: inputFillColor,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Padding(
//           padding: const EdgeInsets.all(28),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const CircularProgressIndicator(color: Color(0xFFD4A017)),
//               const SizedBox(height: 20),
//               Text(
//                 title ??
//                     (isArabic
//                         ? 'ط°ظƒط§ط، ط§طµط·ظ†ط§ط¹ظٹ ظٹظپط­طµ ظ†ط¨ط°طھظƒ...'
//                         : 'AI is reviewing your bio...'),
//                 style: TextStyle(
//                     color: primaryTextColor,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 15),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 subtitle ??
//                     (isArabic
//                         ? 'ظٹطھظ… ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ظ…ظ„ط§ط¦ظ…ط© ط§ظ„ظ…ط­طھظˆظ‰ ظˆط§ط­طھط±ط§ظپظٹطھظ‡'
//                         : 'Checking content appropriateness and professionalism'),
//                 style: TextStyle(color: secondaryTextColor, fontSize: 13),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showAiRejectionDialog(String feedback) {
//     showDialog(
//       context: context,
//       builder: (_) => Dialog(
//         backgroundColor: inputFillColor,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.smart_toy_outlined,
//                   color: Color(0xFFD4A017), size: 48),
//               const SizedBox(height: 12),
//               Text(
//                 isArabic ? 'ًں¤– طھط¹ظ„ظٹظ‚ ط§ظ„ط°ظƒط§ط، ط§ظ„ط§طµط·ظ†ط§ط¹ظٹ' : 'ًں¤– AI Feedback',
//                 style: TextStyle(
//                     color: primaryTextColor,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 17),
//               ),
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: Colors.redAccent.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                       color: Colors.redAccent.withValues(alpha: 0.4)),
//                 ),
//                 child: Text(
//                   feedback,
//                   style: TextStyle(
//                       color: primaryTextColor, fontSize: 14, height: 1.5),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFFD4A017),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//                 ),
//                 child: Text(
//                   isArabic ? 'طھط¹ط¯ظٹظ„ ط§ظ„ظ†ط¨ط°ط©' : 'Edit Bio',
//                   style: const TextStyle(
//                       color: Colors.black, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showAiApprovedSnack(String feedback) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.check_circle, color: Colors.white),
//             const SizedBox(width: 10),
//             Expanded(
//                 child: Text('ًں¤– $feedback',
//                     style: const TextStyle(color: Colors.white))),
//           ],
//         ),
//         backgroundColor: Colors.green.shade700,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _prevStep() {
//     if (_currentStep > 0) {
//       setState(() {
//         _currentStep--;
//       });
//     } else {
//       Navigator.pop(context);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
//     final catTitle = isArabic
//         ? widget.selectedCategory['titleAr']
//         : widget.selectedCategory['titleEn'];

//     return Directionality(
//       textDirection: direction,
//       child: Scaffold(
//         backgroundColor: backgroundColor,
//         body: SafeArea(
//           child: Column(
//             children: [
//               // Top Bar
//               Padding(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     _topBarButton(
//                       icon: isArabic
//                           ? Icons.arrow_forward_ios
//                           : Icons.arrow_back_ios,
//                       label: "",
//                       onTap: _prevStep,
//                     ),
//                     Row(
//                       children: [
//                         _topBarButton(
//                           icon: Icons.language,
//                           label: isArabic ? "EN" : "عربي",
//                           onTap: toggleLanguage,
//                         ),
//                         const SizedBox(width: 10),
//                         _topBarButton(
//                           icon: isDarkMode
//                               ? Icons.light_mode_outlined
//                               : Icons.dark_mode_outlined,
//                           label: "",
//                           onTap: toggleTheme,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),

//               // Progress Indicator
//               Padding(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
//                 child: Row(
//                   children: List.generate(_totalSteps, (index) {
//                     return Expanded(
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 4),
//                         height: 6,
//                         decoration: BoxDecoration(
//                           color: index <= _currentStep
//                               ? const Color(0xFFD4A017)
//                               : borderColor,
//                           borderRadius: BorderRadius.circular(3),
//                         ),
//                       ),
//                     );
//                   }),
//                 ),
//               ),

//               Expanded(
//                 child: Scrollbar(
//                   child: SingleChildScrollView(
//                     physics: const BouncingScrollPhysics(),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 24, vertical: 10),
//                     child: Center(
//                       child: Container(
//                         constraints: const BoxConstraints(maxWidth: 430),
//                         child: Form(
//                           key: _formKey,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.stretch,
//                             children: [
//                               // â”€â”€ Logo and Title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//                               Center(
//                                 child: Column(
//                                   children: [
//                                     Image.asset(
//                                       'assets/images/logo.png',
//                                       height: 100,
//                                       color: const Color(0xFFD4A017),
//                                     ),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       'C R A F T G O',
//                                       style: GoogleFonts.cinzel(
//                                         color: const Color(0xFFD4A017),
//                                         fontSize: 24,
//                                         fontWeight: FontWeight.bold,
//                                         letterSpacing: 2.0,
//                                       ),
//                                     ),
//                                     Text(
//                                       'ARTISAN REGISTRATION',
//                                       style: GoogleFonts.cairo(
//                                         color: const Color(0xFFD4A017)
//                                             .withValues(alpha: 0.8),
//                                         fontSize: 10,
//                                         letterSpacing: 4.0,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const SizedBox(height: 15),

//                               Text(
//                                 isArabic ? "حساب جديد" : "Create Account",
//                                 textAlign: TextAlign.center,
//                                 style: GoogleFonts.arefRuqaa(
//                                   color: primaryTextColor,
//                                   fontSize: 28,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 5),
//                               Text(
//                                 isArabic
//                                     ? "للانضمام كحرفي في مجال: $catTitle"
//                                     : "Join as a craftsman in: $catTitle",
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: Color(0xFFD4A017),
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 30),

//                               // Dynamic Steps
//                               _buildCurrentStep(),

//                               const SizedBox(height: 40),

//                               // Action Buttons
//                               Row(
//                                 children: [
//                                   if (_currentStep > 0) ...[
//                                     Expanded(
//                                       flex: 1,
//                                       child: OutlinedButton(
//                                         style: OutlinedButton.styleFrom(
//                                           padding: const EdgeInsets.symmetric(
//                                               vertical: 16),
//                                           side: BorderSide(color: borderColor),
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                             BorderRadius.circular(30),
//                                           ),
//                                         ),
//                                         onPressed: _prevStep,
//                                         child: Text(
//                                           isArabic ? "السابق" : "Back",
//                                           style: TextStyle(
//                                               color: primaryTextColor),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 15),
//                                   ],
//                                   Expanded(
//                                     flex: 2,
//                                     child: Container(
//                                       height: 55,
//                                       decoration: BoxDecoration(
//                                         borderRadius: BorderRadius.circular(30),
//                                         gradient: const LinearGradient(
//                                           colors: [
//                                             Color(0xFFF7B500),
//                                             Color(0xFFD89A00),
//                                           ],
//                                         ),
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: const Color(0xFFF7B500)
//                                                 .withValues(alpha: 0.3),
//                                             blurRadius: 15,
//                                             spreadRadius: 1,
//                                             offset: const Offset(0, 5),
//                                           ),
//                                         ],
//                                       ),
//                                       child: ElevatedButton(
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: Colors.transparent,
//                                           shadowColor: Colors.transparent,
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                             BorderRadius.circular(30),
//                                           ),
//                                         ),
//                                         onPressed: _nextStep,
//                                         child: Text(
//                                           _currentStep == _totalSteps - 1
//                                               ? (isArabic
//                                               ? "إنشاء الحساب"
//                                               : "Sign Up")
//                                               : (isArabic ? "التالي" : "Next"),
//                                           style: TextStyle(
//                                             fontSize: 18,
//                                             fontWeight: FontWeight.bold,
//                                             color: isDarkMode
//                                                 ? Colors.black
//                                                 : Colors.white,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 20),

//                               // Already have an account
//                               if (_currentStep == 0)
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       isArabic
//                                           ? "لديك حساب بالفعل؟"
//                                           : "Already have an account?",
//                                       style:
//                                       TextStyle(color: secondaryTextColor),
//                                     ),
//                                     TextButton(
//                                       onPressed: () {
//                                         Navigator.pushReplacement(
//                                           context,
//                                           MaterialPageRoute(
//                                             builder: (context) =>
//                                                 CraftsmanLoginScreen(
//                                                   selectedCategory: widget.selectedCategory,
//                                                   heroTag: 'craft-icon-${widget.selectedCategory['titleEn']}',
//                                                   isArabic: isArabic,
//                                                   isDarkMode: isDarkMode,
//                                                   onToggleLanguage: toggleLanguage,
//                                                   onToggleTheme: toggleTheme,
//                                                 ),
//                                           ),
//                                         );
//                                       },
//                                       child: Text(
//                                         isArabic ? "تسجيل الدخول" : "Login",
//                                         style: const TextStyle(
//                                           color: Color(0xFFD4A017),
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               const SizedBox(height: 40),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCurrentStep() {
//     switch (_currentStep) {
//       case 0:
//         return _buildStep1();
//       case 1:
//         return _buildStep2();
//       case 2:
//         return _buildStep3();
//       case 3:
//         return _buildStep4();
//       default:
//         return const SizedBox.shrink();
//     }
//   }

//   Widget _buildStep1() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionTitle(isArabic ? "البيانات الأساسية" : "Basic Info"),
//         const SizedBox(height: 15),
//         _buildTextField(
//           label: isArabic ? "الاسم الكامل" : "Full Name",
//           icon: Icons.person_outline,
//           controller: _nameController,
//         ),
//         const SizedBox(height: 15),
//         _buildTextField(
//           label: isArabic ? "رقم الهاتف" : "Phone Number",
//           icon: Icons.phone_outlined,
//           keyboardType: TextInputType.phone,
//           controller: _phoneController,
//         ),
//         const SizedBox(height: 15),
//         _buildTextField(
//           label: isArabic ? "البريد الإلكتروني" : "Email",
//           icon: Icons.email_outlined,
//           keyboardType: TextInputType.emailAddress,
//           controller: _emailController,
//         ),
//         const SizedBox(height: 15),
//         _buildCitySelector(),
//         const SizedBox(height: 15),
//         _buildTextField(
//           label: isArabic ? "كلمة المرور" : "Password",
//           icon: Icons.lock_outline,
//           isPassword: true,
//           controller: _passwordController,
//         ),
//         // Password Strength Indicator
//         if (_passwordController.text.isNotEmpty)
//           Padding(
//             padding: const EdgeInsets.only(top: 8, right: 12, left: 12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(2),
//                     child: LinearProgressIndicator(
//                       value: _passwordStrength,
//                       backgroundColor: borderColor,
//                       valueColor: AlwaysStoppedAnimation<Color>(
//                           _getPasswordStrengthColor()),
//                       minHeight: 4,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Text(
//                   _getPasswordStrengthText(),
//                   style: TextStyle(
//                     color: _getPasswordStrengthColor(),
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         const SizedBox(height: 15),
//         _buildTextField(
//           label: isArabic ? "تأكيد كلمة المرور" : "Confirm Password",
//           icon: Icons.lock_reset_outlined,
//           isPassword: true,
//           controller: _confirmPasswordController,
//         ),
//       ],
//     );
//   }

//   Widget _buildStep2() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionTitle(
//             isArabic ? "تأكيد البريد الإلكتروني" : "Verify Email"),
//         const SizedBox(height: 15),
//         Text(
//           isArabic
//               ? "ط§ظ„ط±ط¬ط§ط، ط¥ط¯ط®ط§ظ„ ط±ظ…ط² ط§ظ„طھط­ظ‚ظ‚ (OTP) ط§ظ„ظ…ط±ط³ظ„ ط¥ظ„ظ‰ ط§ظ„ط¨ط±ظٹط¯\n${_emailController.text.isEmpty ? '****' : _emailController.text}"
//               : "Please enter the OTP sent to\n${_emailController.text.isEmpty ? '****' : _emailController.text}",
//           style: TextStyle(color: secondaryTextColor, fontSize: 14),
//         ),
//         const SizedBox(height: 25),
//         Directionality(
//           textDirection: TextDirection.ltr,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: List.generate(4, (index) {
//               return SizedBox(
//                 width: 60,
//                 height: 60,
//                 child: TextFormField(
//                   controller: _otpControllers[index],
//                   focusNode: _otpFocusNodes[index],
//                   textAlign: TextAlign.center,
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   style: TextStyle(
//                       color: primaryTextColor,
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold),
//                   decoration: InputDecoration(
//                     filled: true,
//                     fillColor: inputFillColor,
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide(color: borderColor),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide:
//                       const BorderSide(color: Color(0xFFD4A017), width: 2),
//                     ),
//                   ),
//                   onChanged: (value) {
//                     if (value.isNotEmpty) {
//                       // طھط£ظƒط¯ ط¥ظ† ط§ظ„ط®ط§ظ†ط© ظپظٹظ‡ط§ ط±ظ‚ظ… ظˆط§ط­ط¯ ظپظ‚ط·
//                       if (value.length > 1) {
//                         _otpControllers[index].text = value[value.length - 1];
//                         _otpControllers[index].selection =
//                             TextSelection.fromPosition(
//                               TextPosition(offset: 1),
//                             );
//                       }
//                       // ط§ظ†طھظ‚ظ„ ظ„ظ„ط®ط§ظ†ط© ط§ظ„طھط§ظ„ظٹط© طھظ„ظ‚ط§ط¦ظٹط§ظ‹
//                       if (index < 3) {
//                         FocusScope.of(context)
//                             .requestFocus(_otpFocusNodes[index + 1]);
//                       } else {
//                         // ط¢ط®ط± ط®ط§ظ†ط© â€” ط£ط؛ظ„ظ‚ ط§ظ„ظƒظٹط¨ظˆط±ط¯
//                         _otpFocusNodes[index].unfocus();
//                       }
//                     } else if (value.isEmpty && index > 0) {
//                       // ط§ط±ط¬ط¹ ظ„ظ„ط®ط§ظ†ط© ط§ظ„ط³ط§ط¨ظ‚ط© ط¹ظ†ط¯ ط§ظ„ط­ط°ظپ
//                       FocusScope.of(context)
//                           .requestFocus(_otpFocusNodes[index - 1]);
//                     }
//                   },
//                 ),
//               );
//             }),
//           ),
//         ),
//         const SizedBox(height: 20),
//         Center(
//           child: TextButton(
//             onPressed: _otpCountdown == 0
//                 ? () async {
//               // Resend OTP logic
//               _showAiCheckingDialog(
//                   title: isArabic ? 'ط¥ط¹ط§ط¯ط© ط§ظ„ط¥ط±ط³ط§ظ„...' : 'Resending...',
//                   subtitle: '');
//               final success =
//               await AuthService.sendOtp(_emailController.text.trim());
//               if (!mounted) return;
//               Navigator.pop(context);
//               if (success) {
//                 _startOtpTimer();
//               } else {
//                 _showError(isArabic ? 'ظپط´ظ„ ط§ظ„ط¥ط±ط³ط§ظ„' : 'Failed to send');
//               }
//             }
//                 : null,
//             child: Text(
//               _otpCountdown > 0
//                   ? (isArabic
//                   ? "ط¥ط¹ط§ط¯ط© ط§ظ„ط¥ط±ط³ط§ظ„ ط¨ط¹ط¯ ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}"
//                   : "Resend code in ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}")
//                   : (isArabic ? "ط¥ط¹ط§ط¯ط© ط¥ط±ط³ط§ظ„ ط§ظ„ط±ظ…ط²" : "Resend Code"),
//               style: TextStyle(
//                 color: _otpCountdown > 0
//                     ? secondaryTextColor
//                     : const Color(0xFFD4A017),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildStep3() {
//     String titleEn = widget.selectedCategory['titleEn'];
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionTitle(isArabic ? "طھظپط§طµظٹظ„ ط§ظ„ط­ط±ظپط©" : "Craft Details"),
//         const SizedBox(height: 15),
//         // â”€â”€ Experience Stepper â”€â”€
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//           decoration: BoxDecoration(
//             color: inputFillColor,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: borderColor),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.history, color: secondaryTextColor),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   isArabic ? "ط³ظ†ظˆط§طھ ط§ظ„ط®ط¨ط±ط©" : "Years of Experience",
//                   style: TextStyle(color: secondaryTextColor, fontSize: 16),
//                 ),
//               ),
//               InkWell(
//                 onTap: () {
//                   final current = int.tryParse(_experienceController.text) ?? 0;
//                   if (current > 0) {
//                     setState(() {
//                       _experienceController.text = (current - 1).toString();
//                     });
//                   }
//                 },
//                 borderRadius: BorderRadius.circular(12),
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: borderColor.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child:
//                   Icon(Icons.remove, color: secondaryTextColor, size: 24),
//                 ),
//               ),
//               Container(
//                 width: 50,
//                 alignment: Alignment.center,
//                 child: Text(
//                   _experienceController.text.isEmpty
//                       ? '0'
//                       : _experienceController.text,
//                   style: TextStyle(
//                     color: primaryTextColor,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               InkWell(
//                 onTap: () {
//                   final current = int.tryParse(_experienceController.text) ?? 0;
//                   setState(() {
//                     _experienceController.text = (current + 1).toString();
//                   });
//                 },
//                 borderRadius: BorderRadius.circular(12),
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFD4A017).withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child:
//                   const Icon(Icons.add, color: Color(0xFFD4A017), size: 24),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 15),
//         TextFormField(
//           controller: _bioController,
//           textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//           style: TextStyle(color: primaryTextColor),
//           maxLines: 4,
//           maxLength: 500,
//           decoration: InputDecoration(
//             labelText:
//             isArabic ? "ظ†ط¨ط°ط© ط¹ظ†ظƒ ظˆط¹ظ† ط£ط¹ظ…ط§ظ„ظƒ" : "Bio & Work Description",
//             labelStyle: TextStyle(color: secondaryTextColor),
//             prefixIcon: Icon(Icons.info_outline, color: secondaryTextColor),
//             alignLabelWithHint: true,
//             filled: true,
//             fillColor: inputFillColor,
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(16),
//               borderSide: BorderSide(color: borderColor),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(16),
//               borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
//             ),
//             contentPadding:
//             const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             const Icon(Icons.auto_awesome, color: Color(0xFFD4A017), size: 16),
//             const SizedBox(width: 6),
//             Expanded(
//               child: Text(
//                 isArabic
//                     ? "ط³ظٹظ‚ظˆظ… ط§ظ„ط°ظƒط§ط، ط§ظ„ط§طµط·ظ†ط§ط¹ظٹ ط¨ظ…ط±ط§ط¬ط¹ط© ط§ظ„ظ†ط¨ط°ط© ظ„ط¶ظ…ط§ظ† ط§ظ„ط§ط­طھط±ط§ظپظٹط©"
//                     : "AI will review your bio to ensure professionalism",
//                 style: const TextStyle(color: Color(0xFFD4A017), fontSize: 12),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 10),
//         Align(
//           alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Main generate button
//               InkWell(
//                 onTap: _isGeneratingBio ? null : _generateAIBio,
//                 borderRadius: BorderRadius.circular(20),
//                 splashColor: Colors.white.withValues(alpha: 0.3),
//                 highlightColor: Colors.white.withValues(alpha: 0.1),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFFD4A017), Color(0xFFE8C86A)],
//                     ),
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFFD4A017).withValues(alpha: 0.3),
//                         blurRadius: 8,
//                         offset: const Offset(0, 3),
//                       )
//                     ],
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (_isGeneratingBio)
//                         const SizedBox(
//                           width: 16,
//                           height: 16,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2, color: Colors.white),
//                         )
//                       else
//                         Icon(
//                           _bioSuggestions.isEmpty ? Icons.auto_awesome : Icons.refresh,
//                           color: Colors.white,
//                           size: 18,
//                         ),
//                       const SizedBox(width: 8),
//                       Text(
//                         _isGeneratingBio
//                             ? (isArabic ? 'جاري الإنشاء...' : 'Generating...')
//                             : _bioSuggestions.isEmpty
//                             ? (isArabic ? '✨ إنشاء نبذة احترافية' : '✨ Generate Professional Bio')
//                             : (isArabic ? '↻ اقتراح آخر' : '↻ Try Another'),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 13,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               // Navigation arrows between suggestions (only shown when >1 suggestion)
//               if (_bioSuggestions.length > 1) ...[
//                 const SizedBox(width: 8),
//                 Container(
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFD4A017).withValues(alpha: 0.15),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: const Color(0xFFD4A017).withValues(alpha: 0.5)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       InkWell(
//                         onTap: _currentBioIndex > 0
//                             ? () {
//                           setState(() {
//                             _currentBioIndex--;
//                             _bioController.text = _bioSuggestions[_currentBioIndex];
//                           });
//                         }
//                             : null,
//                         borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                           child: Icon(
//                             isArabic ? Icons.chevron_right : Icons.chevron_left,
//                             color: _currentBioIndex > 0
//                                 ? const Color(0xFFD4A017)
//                                 : const Color(0xFFD4A017).withValues(alpha: 0.3),
//                             size: 18,
//                           ),
//                         ),
//                       ),
//                       Text(
//                         '${_currentBioIndex + 1}/${_bioSuggestions.length}',
//                         style: const TextStyle(
//                           color: Color(0xFFD4A017),
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       InkWell(
//                         onTap: _currentBioIndex < _bioSuggestions.length - 1
//                             ? () {
//                           setState(() {
//                             _currentBioIndex++;
//                             _bioController.text = _bioSuggestions[_currentBioIndex];
//                           });
//                         }
//                             : null,
//                         borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                           child: Icon(
//                             isArabic ? Icons.chevron_left : Icons.chevron_right,
//                             color: _currentBioIndex < _bioSuggestions.length - 1
//                                 ? const Color(0xFFD4A017)
//                                 : const Color(0xFFD4A017).withValues(alpha: 0.3),
//                             size: 18,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         const SizedBox(height: 20),
//         Text(
//           isArabic ? "متوسط سعر القطعة (JOD)" : "Average Piece Price (JOD)",
//           style: TextStyle(color: secondaryTextColor, fontSize: 14),
//         ),
//         const SizedBox(height: 10),
//         Wrap(
//           spacing: 10,
//           runSpacing: 10,
//           children: List.generate(_priceRangesEn.length, (index) {
//             final enLabel = _priceRangesEn[index];
//             final isSelected = _selectedPriceRange == enLabel;
//             return ChoiceChip(
//               label: Directionality(
//                 textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//                 child: Text(
//                   isArabic ? _priceRangesAr[index] : enLabel,
//                   style: TextStyle(
//                     color: isSelected ? Colors.black : primaryTextColor,
//                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                   ),
//                 ),
//               ),
//               selected: isSelected,
//               onSelected: (selected) {
//                 setState(() {
//                   _selectedPriceRange = selected ? enLabel : null;
//                 });
//               },
//               selectedColor: const Color(0xFFD4A017),
//               backgroundColor: inputFillColor,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//                 side: BorderSide(
//                   color: isSelected ? const Color(0xFFD4A017) : borderColor,
//                 ),
//               ),
//               showCheckmark: false,
//             );
//           }),
//         ),
//         const SizedBox(height: 15),
//         if (titleEn == "Crochet & Knitting")
//           TextFormField(
//             textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//             style: TextStyle(color: primaryTextColor),
//             decoration: InputDecoration(
//               labelText: isArabic
//                   ? "ظ‡ظ„ طھظˆظپط± ط®ط¯ظ…ط© ط§ظ„طھظپطµظٹظ„ ط­ط³ط¨ ط§ظ„ظ…ظ‚ط§ط³طں"
//                   : "Do you offer custom sizing?",
//               labelStyle: TextStyle(color: secondaryTextColor),
//               prefixIcon: Icon(Icons.straighten, color: secondaryTextColor),
//               filled: true,
//               fillColor: inputFillColor,
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(16),
//                 borderSide: BorderSide(color: borderColor),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(16),
//                 borderSide:
//                 const BorderSide(color: Color(0xFFD4A017), width: 2),
//               ),
//               contentPadding:
//               const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//             ),
//           ),
//         if (titleEn == "Pottery & Ceramics")
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 isArabic
//                     ? "ظ…ط§ ظ‡ظٹ ط£ظ†ظˆط§ط¹ ط§ظ„ط·ظٹظ† ط§ظ„ظ…ط³طھط®ط¯ظ…ط©طں"
//                     : "Types of clay used?",
//                 style: TextStyle(color: secondaryTextColor, fontSize: 14),
//               ),
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 10,
//                 runSpacing: 10,
//                 children: List.generate(_clayOptionsEn.length, (index) {
//                   final enLabel = _clayOptionsEn[index];
//                   final isSelected = _selectedClays.contains(enLabel);
//                   return FilterChip(
//                     label: Text(
//                       isArabic ? _clayOptionsAr[index] : enLabel,
//                       style: TextStyle(
//                         color: isSelected ? Colors.black : primaryTextColor,
//                         fontWeight:
//                         isSelected ? FontWeight.bold : FontWeight.normal,
//                         fontSize: 13,
//                       ),
//                     ),
//                     selected: isSelected,
//                     onSelected: (selected) {
//                       setState(() {
//                         if (selected) {
//                           _selectedClays.add(enLabel);
//                         } else {
//                           _selectedClays.remove(enLabel);
//                         }
//                       });
//                     },
//                     selectedColor: const Color(0xFFD4A017),
//                     backgroundColor: inputFillColor,
//                     checkmarkColor: Colors.black,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(20),
//                       side: BorderSide(
//                         color:
//                         isSelected ? const Color(0xFFD4A017) : borderColor,
//                       ),
//                     ),
//                   );
//                 }),
//               ),
//               if (_selectedClays.contains('Other')) ...[
//                 const SizedBox(height: 15),
//                 TextFormField(
//                   controller: _otherClayController,
//                   textDirection:
//                   isArabic ? TextDirection.rtl : TextDirection.ltr,
//                   style: TextStyle(color: primaryTextColor),
//                   decoration: InputDecoration(
//                     labelText: isArabic
//                         ? "ظٹط±ط¬ظ‰ طھط­ط¯ظٹط¯ ط£ظ†ظˆط§ط¹ ط£ط®ط±ظ‰"
//                         : "Please specify other types",
//                     labelStyle: TextStyle(color: secondaryTextColor),
//                     prefixIcon:
//                     Icon(Icons.edit_outlined, color: secondaryTextColor),
//                     filled: true,
//                     fillColor: inputFillColor,
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide(color: borderColor),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide:
//                       const BorderSide(color: Color(0xFFD4A017), width: 2),
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 20, vertical: 16),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         if (titleEn == "Jewelry & Accessories")
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 isArabic ? "المواد التي تعمل بها" : "Materials you work with",
//                 style: TextStyle(color: secondaryTextColor, fontSize: 14),
//               ),
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 10,
//                 runSpacing: 10,
//                 children: List.generate(_jewelryMaterialsEn.length, (index) {
//                   final enLabel = _jewelryMaterialsEn[index];
//                   final isSelected = _selectedJewelryMaterials.contains(enLabel);
//                   return FilterChip(
//                     avatar: enLabel == 'Other'
//                         ? Icon(
//                       Icons.edit_outlined,
//                       size: 16,
//                       color: isSelected ? Colors.black : secondaryTextColor,
//                     )
//                         : null,
//                     label: Text(
//                       isArabic ? _jewelryMaterialsAr[index] : enLabel,
//                       style: TextStyle(
//                         color: isSelected ? Colors.black : primaryTextColor,
//                         fontWeight:
//                         isSelected ? FontWeight.bold : FontWeight.normal,
//                         fontSize: 13,
//                       ),
//                     ),
//                     selected: isSelected,
//                     onSelected: (selected) {
//                       setState(() {
//                         if (selected) {
//                           _selectedJewelryMaterials.add(enLabel);
//                         } else {
//                           _selectedJewelryMaterials.remove(enLabel);
//                           if (enLabel == 'Other') {
//                             _otherJewelryMaterialController.clear();
//                           }
//                         }
//                       });
//                     },
//                     selectedColor: const Color(0xFFD4A017),
//                     backgroundColor: inputFillColor,
//                     checkmarkColor: Colors.black,
//                     showCheckmark: enLabel != 'Other',
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(20),
//                       side: BorderSide(
//                         color: isSelected
//                             ? const Color(0xFFD4A017)
//                             : borderColor,
//                       ),
//                     ),
//                   );
//                 }),
//               ),
//               if (_selectedJewelryMaterials.contains('Other')) ...[
//                 const SizedBox(height: 15),
//                 TextFormField(
//                   controller: _otherJewelryMaterialController,
//                   textDirection:
//                   isArabic ? TextDirection.rtl : TextDirection.ltr,
//                   style: TextStyle(color: primaryTextColor),
//                   decoration: InputDecoration(
//                     labelText: isArabic
//                         ? "اكتب مادة أخرى"
//                         : "Specify another material",
//                     hintText: isArabic
//                         ? "مثال: أحجار طبيعية، جلد..."
//                         : "e.g. natural stones, leather...",
//                     labelStyle: TextStyle(color: secondaryTextColor),
//                     hintStyle: TextStyle(
//                       color: secondaryTextColor.withValues(alpha: 0.65),
//                     ),
//                     prefixIcon:
//                     Icon(Icons.edit_outlined, color: secondaryTextColor),
//                     filled: true,
//                     fillColor: inputFillColor,
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide(color: borderColor),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: const BorderSide(
//                         color: Color(0xFFD4A017),
//                         width: 2,
//                       ),
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 20,
//                       vertical: 16,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//       ],
//     );
//   }

//   Future<void> _pickAndUploadIdImage() async {
//     try {
//       // 1. Open the custom ID camera screen
//       final XFile? pickedImage = await Navigator.of(context).push<XFile>(
//         MaterialPageRoute(
//           builder: (context) => IDCameraScreen(isArabic: isArabic),
//         ),
//       );

//       if (pickedImage == null) return;

//       setState(() {
//         _isUploadingId = true;
//         _idUploadStatus = 'analyzing';
//       });

//       // 2. Upload and verify with AI
//       final result = await UploadService.uploadAndVerifyIdImage(pickedImage);

//       if (!mounted) return;

//       setState(() {
//         _idImageUrl = result.url;
//         _idImagePath = pickedImage.path;
//         _isIdUploaded = true;
//         _idVerificationDetails = result.verificationData;
//         _idUploadStatus = '';
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             isArabic
//                 ? 'طھظ… ظپط­طµ ظˆط±ظپط¹ طµظˆط±ط© ط§ظ„ظ‡ظˆظٹط© ط¨ظ†ط¬ط§ط­'
//                 : 'ID image verified and uploaded successfully',
//           ),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } on IDVerificationException catch (e) {
//       _showError(e.message);
//       setState(() {
//         _idUploadStatus = '';
//         _idVerificationDetails = e.verificationData;
//       });
//     } catch (e) {
//       _showError(
//         isArabic
//             ? 'ط­ط¯ط« ط®ط·ط£ ط£ط«ظ†ط§ط، ط±ظپط¹ ط§ظ„طµظˆط±ط©: $e'
//             : 'Error: $e',
//       );
//       setState(() {
//         _idUploadStatus = '';
//       });
//     } finally {
//       if (mounted) {
//         setState(() => _isUploadingId = false);
//       }
//     }
//   }

//   Future<void> _pickAndUploadPortfolioImages() async {
//     try {
//       final List<XFile> pickedImages =
//       await _imagePicker.pickMultiImage(imageQuality: 80);

//       if (pickedImages.isEmpty) return;

//       setState(() => _isUploadingPortfolio = true);

//       final uploadedUrls = await UploadService.uploadImages(pickedImages);

//       if (!mounted) return;

//       if (uploadedUrls.isEmpty) {
//         _showError(
//           isArabic
//               ? 'ظپط´ظ„ ط±ظپط¹ طµظˆط± ط§ظ„ط£ط¹ظ…ط§ظ„'
//               : 'Failed to upload portfolio images',
//         );
//         return;
//       }

//       setState(() {
//         _portfolioImageUrls.addAll(uploadedUrls);
//         _portfolioImagePaths.addAll(pickedImages.map((image) => image.path));

//         _isPortfolioUploaded = _portfolioImageUrls.isNotEmpty;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             isArabic
//                 ? 'طھظ… ط±ظپط¹ ${uploadedUrls.length} طµظˆط±ط© ط¨ظ†ط¬ط§ط­'
//                 : '${uploadedUrls.length} images uploaded successfully',
//           ),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } catch (e) {
//       _showError(
//         isArabic
//             ? 'ظپط´ظ„ ط±ظپط¹ طµظˆط± ط§ظ„ط£ط¹ظ…ط§ظ„: $e'
//             : 'Error: $e',
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isUploadingPortfolio = false);
//       }
//     }
//   }

//   Widget _buildStep4() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionTitle(isArabic ? "ط§ظ„طھظˆط«ظٹظ‚ ظˆط§ظ„ط£ظ…ط§ظ†" : "Verification"),
//         const SizedBox(height: 10),
//         Text(
//           isArabic
//               ? "طھط­ظ…ظٹظ„ طµظˆط± ط£ط¹ظ…ط§ظ„ظƒ ط¥ظ„ط²ط§ظ…ظٹ ظ„ط¨ط¯ط، ط§ط³طھظ‚ط¨ط§ظ„ ط§ظ„ط·ظ„ط¨ط§طھ. ط£ظ…ط§ طµظˆط±ط© ط§ظ„ظ‡ظˆظٹط© ظپظ‡ظٹ ط§ط®طھظٹط§ط±ظٹط© ظˆطھط³ط§ط¹ط¯ظƒ ظپظ‚ط· ظپظٹ ط§ظ„ط­طµظˆظ„ ط¹ظ„ظ‰ ط´ط§ط±ط© آ«ط£ظٹط¯ظچ ظ…ظˆط«ظˆظ‚ط©آ» ظ„ط²ظٹط§ط¯ط© ط«ظ‚ط© ط§ظ„ط²ط¨ط§ط¦ظ†."
//               : "Uploading portfolio samples is required to start receiving orders. The National ID is optional and only needed to earn the \"Trusted Hands\" verification badge.",
//           style:
//           TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.5),
//         ),
//         const SizedBox(height: 16),

//         // â”€â”€ Visual Comparison for Trusted Hands â”€â”€
//         Row(
//           children: [
//             Expanded(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 decoration: BoxDecoration(
//                   color: inputFillColor,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: borderColor),
//                 ),
//                 child: Column(
//                   children: [
//                     Icon(Icons.person_outline,
//                         color: secondaryTextColor, size: 28),
//                     const SizedBox(height: 6),
//                     Text(
//                       isArabic ? "ط­ط³ط§ط¨ ط¹ط§ط¯ظٹ" : "Standard",
//                       style: TextStyle(
//                           color: primaryTextColor,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFD4A017).withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                       color: const Color(0xFFD4A017).withValues(alpha: 0.5),
//                       width: 1.5),
//                 ),
//                 child: Column(
//                   children: [
//                     const Icon(Icons.verified,
//                         color: Color(0xFFD4A017), size: 28),
//                     const SizedBox(height: 6),
//                     Text(
//                       isArabic ? "ط£ظٹط¯ظچ ظ…ظˆط«ظˆظ‚ط©" : "Trusted Hands",
//                       style: const TextStyle(
//                           color: Color(0xFFD4A017),
//                           fontWeight: FontWeight.bold,
//                           fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         // Optional badge for ID
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: const Color(0xFFD4A017).withValues(alpha: 0.08),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//                 color: const Color(0xFFD4A017).withValues(alpha: 0.3)),
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.info_outline,
//                   color: Color(0xFFD4A017), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   isArabic
//                       ? "طµظˆط±ط© ط§ظ„ظ‡ظˆظٹط© ط§ط®طھظٹط§ط±ظٹط© â€” طھظ…ظ†ط­ظƒ ط´ط§ط±ط© \u00abط£ظٹط¯ظچ ظ…ظˆط«ظˆظ‚ط©\u00bb ط¹ظ†ط¯ ط§ظ„ظ…ظˆط§ظپظ‚ط© ط¹ظ„ظٹظ‡ط§."
//                       : "ID is optional - submitting it earns you the \"Trusted Hands\" badge after admin approval.",
//                   style:
//                   const TextStyle(color: Color(0xFFD4A017), fontSize: 12),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         _buildUploadButton(
//           label: isArabic
//               ? "طµظˆط±ط© ط§ظ„ظ‡ظˆظٹط© ط§ظ„ظˆط·ظ†ظٹط© (ط§ط®طھظٹط§ط±ظٹ)"
//               : "National ID Image (Optional)",
//           icon: Icons.badge_outlined,
//           isUploaded: _isIdUploaded,
//           isOptional: true,
//           onTap: _isUploadingId ? () {} : _pickAndUploadIdImage,
//         ),

//         if (_isUploadingId) ...[
//           const SizedBox(height: 12),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   color: Color(0xFFD4A017),
//                   strokeWidth: 2,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 _idUploadStatus == 'analyzing'
//                     ? (isArabic ? 'ط¬ط§ط±ظٹ طھط­ظ„ظٹظ„ ط§ظ„طµظˆط±ط© ط¨ط§ظ„ط°ظƒط§ط، ط§ظ„ط§طµط·ظ†ط§ط¹ظٹ...' : 'Analyzing image with AI...')
//                     : (isArabic ? 'ط¬ط§ط±ظٹ ط§ظ„ط±ظپط¹...' : 'Uploading...'),
//                 style: const TextStyle(
//                   color: Colors.white70,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//         ],

//         if (_idImageUrl != null) ...[
//           const SizedBox(height: 12),
//           _buildSelectedImagePreview(
//             imageUrl: _idImageUrl!,
//             title: isArabic ? "ظ…ط¹ط§ظٹظ†ط© طµظˆط±ط© ط§ظ„ظ‡ظˆظٹط©" : "ID Image Preview",
//             onDelete: () {
//               setState(() {
//                 _idImagePath = null;
//                 _idImageUrl = null;
//                 _isIdUploaded = false;
//               });
//             },
//           ),
//         ],

//         const SizedBox(height: 15),
//         _buildUploadButton(
//           label: isArabic ? "طµظˆط± ظ†ظ…ط§ط°ط¬ ظ…ظ† ط£ط¹ظ…ط§ظ„ظƒ" : "Portfolio Sample Images",
//           icon: Icons.image_outlined,
//           isUploaded: _isPortfolioUploaded,
//           isOptional: false,
//           onTap: _isUploadingPortfolio ? () {} : _pickAndUploadPortfolioImages,
//         ),

//         if (_isUploadingPortfolio) ...[
//           const SizedBox(height: 12),
//           const Center(
//             child: CircularProgressIndicator(
//               color: Color(0xFFD4A017),
//             ),
//           ),
//         ],

//         if (_portfolioImageUrls.isNotEmpty) ...[
//           const SizedBox(height: 12),
//           Text(
//             isArabic
//                 ? "ط§ظ„ط£ط¹ظ…ط§ظ„ ط§ظ„ظ…ط®طھط§ط±ط© (${_portfolioImageUrls.length})"
//                 : "Selected Works (${_portfolioImageUrls.length})",
//             style: TextStyle(
//               color: primaryTextColor,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 10),
//           GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: _portfolioImageUrls.length,
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 3,
//               crossAxisSpacing: 10,
//               mainAxisSpacing: 10,
//             ),
//             itemBuilder: (context, index) {
//               return Stack(
//                 children: [
//                   Positioned.fill(
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(12),
//                       child: Image.network(
//                         _portfolioImageUrls[index],
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                   Positioned(
//                     top: 4,
//                     right: 4,
//                     child: InkWell(
//                       onTap: () {
//                         setState(() {
//                           _portfolioImageUrls.removeAt(index);
//                           if (index < _portfolioImagePaths.length) {
//                             _portfolioImagePaths.removeAt(index);
//                           }
//                           _isPortfolioUploaded =
//                               _portfolioImageUrls.isNotEmpty;
//                         });
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(4),
//                         decoration: const BoxDecoration(
//                           color: Colors.black54,
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(
//                           Icons.close,
//                           color: Colors.white,
//                           size: 18,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ],
//     );
//   }

//   void _startAIVerification() {
//     showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) {
//           return Dialog(
//             backgroundColor: inputFillColor,
//             shape:
//             RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             child: Padding(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.document_scanner,
//                       size: 48, color: Color(0xFFD4A017)),
//                   const SizedBox(height: 16),
//                   Text(
//                     isArabic
//                         ? "ط§ظ„ط°ظƒط§ط، ط§ظ„ط§طµط·ظ†ط§ط¹ظٹ ظٹطھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ظ‡ظˆظٹط©..."
//                         : "AI is verifying ID...",
//                     style: TextStyle(
//                         color: primaryTextColor,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 16),
//                   const CircularProgressIndicator(color: Color(0xFFD4A017)),
//                 ],
//               ),
//             ),
//           );
//         });

//     Future.delayed(const Duration(seconds: 3), () {
//       if (!mounted) return;
//       Navigator.pop(context); // close scanning dialog

//       showDialog(
//           context: context,
//           builder: (context) {
//             return Dialog(
//               backgroundColor: inputFillColor,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20)),
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.verified_user,
//                         size: 64, color: Colors.green),
//                     const SizedBox(height: 16),
//                     Text(
//                       isArabic ? "طھظ… ط§ظ„طھط­ظ‚ظ‚ ط¨ظ†ط¬ط§ط­!" : "Verified Successfully!",
//                       style: TextStyle(
//                           color: primaryTextColor,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       isArabic
//                           ? "ط¯ظ‚ط© ط§ظ„طھط·ط§ط¨ظ‚: 98%\nطھظ… طھظˆط«ظٹظ‚ ط§ظ„ظ‡ظˆظٹط© ط¹ط¨ط± ط§ظ„ط°ظƒط§ط، ط§ظ„ط§طµط·ظ†ط§ط¹ظٹ ظˆطھظ‚ظ„ظٹظ„ ظˆظ‚طھ ط§ظ„ظ…ط±ط§ط¬ط¹ط©."
//                           : "Match Confidence: 98%\nID verified by AI, reducing admin review time.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: secondaryTextColor, fontSize: 14),
//                     ),
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: () {
//                         Navigator.pop(context);
//                         setState(() => _isIdUploaded = true);
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFFD4A017),
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12)),
//                       ),
//                       child: Text(
//                         isArabic ? "ظ…طھط§ط¨ط¹ط©" : "Continue",
//                         style: const TextStyle(
//                             color: Color(0xFF0D1420),
//                             fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           });
//     });
//   }

//   Widget _buildSelectedImagePreview({
//     required String imageUrl,
//     required String title,
//     required VoidCallback onDelete,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: inputFillColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFD4A017)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   title,
//                   style: TextStyle(
//                     color: primaryTextColor,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               IconButton(
//                 onPressed: onDelete,
//                 icon: const Icon(
//                   Icons.delete_outline,
//                   color: Colors.redAccent,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(12),
//             child: Image.network(
//               imageUrl,
//               width: double.infinity,
//               height: 190,
//               fit: BoxFit.cover,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Row(
//       children: [
//         Container(
//           width: 4,
//           height: 20,
//           decoration: BoxDecoration(
//             color: const Color(0xFFD4A017),
//             borderRadius: BorderRadius.circular(2),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Text(
//           title,
//           style: TextStyle(
//             color: primaryTextColor,
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTextField({
//     required String label,
//     required IconData icon,
//     bool isPassword = false,
//     TextInputType? keyboardType,
//     int maxLines = 1,
//     TextEditingController? controller,
//   }) {
//     if (!isPassword) {
//       return TextFormField(
//         controller: controller,
//         style: TextStyle(color: primaryTextColor),
//         keyboardType: keyboardType,
//         maxLines: maxLines,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(color: secondaryTextColor),
//           prefixIcon: Icon(icon, color: secondaryTextColor),
//           filled: true,
//           fillColor: inputFillColor,
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(16),
//             borderSide: BorderSide(color: borderColor),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(16),
//             borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
//           ),
//           contentPadding:
//           const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         ),
//       );
//     }

//     // Password field with eye toggle
//     return StatefulBuilder(
//       builder: (context, setFieldState) {
//         bool obscure = true;
//         return StatefulBuilder(
//           builder: (context, setInnerState) {
//             return TextFormField(
//               controller: controller,
//               style: TextStyle(color: primaryTextColor),
//               obscureText: obscure,
//               keyboardType: keyboardType,
//               decoration: InputDecoration(
//                 labelText: label,
//                 labelStyle: TextStyle(color: secondaryTextColor),
//                 prefixIcon: Icon(icon, color: secondaryTextColor),
//                 suffixIcon: IconButton(
//                   icon: Icon(
//                     obscure
//                         ? Icons.visibility_off_outlined
//                         : Icons.visibility_outlined,
//                     color: secondaryTextColor,
//                   ),
//                   onPressed: () {
//                     setInnerState(() {
//                       obscure = !obscure;
//                     });
//                   },
//                 ),
//                 filled: true,
//                 fillColor: inputFillColor,
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   borderSide: BorderSide(color: borderColor),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(16),
//                   borderSide:
//                   const BorderSide(color: Color(0xFFD4A017), width: 2),
//                 ),
//                 contentPadding:
//                 const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildUploadButton({
//     required String label,
//     required IconData icon,
//     required bool isUploaded,
//     required VoidCallback onTap,
//     bool isOptional = false,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//         decoration: BoxDecoration(
//           color: isUploaded
//               ? const Color(0xFFD4A017).withValues(alpha: 0.05)
//               : inputFillColor,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//               color: isUploaded ? const Color(0xFFD4A017) : borderColor,
//               style: BorderStyle.solid),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Expanded(
//               child: Row(
//                 children: [
//                   Icon(icon,
//                       color: isUploaded
//                           ? const Color(0xFFD4A017)
//                           : secondaryTextColor),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           label,
//                           style: TextStyle(
//                             color: isUploaded
//                                 ? const Color(0xFFD4A017)
//                                 : primaryTextColor,
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         if (isOptional)
//                           Text(
//                             isArabic
//                                 ? "ط³ظٹظ…ظ†ط­ظƒ ط´ط§ط±ط© آ«ط£ظٹط¯ظچ ظ…ظˆط«ظˆظ‚ط©آ»"
//                                 : "Earns \"Trusted Hands\" badge",
//                             style: TextStyle(
//                               color: secondaryTextColor,
//                               fontSize: 11,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (isUploaded) const Icon(Icons.check_circle, color: Colors.green),
//             if (!isUploaded) Icon(Icons.upload_file, color: secondaryTextColor),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCitySelector() {
//     return InkWell(
//       onTap: _showCityPickerSheet,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         decoration: BoxDecoration(
//           color: inputFillColor,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: borderColor),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.location_on_outlined, color: secondaryTextColor),
//                 const SizedBox(width: 12),
//                 Text(
//                   _selectedCity ?? (isArabic ? "ط§ظ„ظ…ط¯ظٹظ†ط©" : "City"),
//                   style: TextStyle(
//                     color: _selectedCity != null
//                         ? primaryTextColor
//                         : secondaryTextColor,
//                     fontSize: 16,
//                   ),
//                 ),
//               ],
//             ),
//             Icon(Icons.arrow_drop_down, color: secondaryTextColor),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showCityPickerSheet() {
//     final List<String> cities = isArabic
//         ? [
//       "ظ†ط§ط¨ظ„ط³",
//       "ط±ط§ظ… ط§ظ„ظ„ظ‡",
//       "ط§ظ„ط®ظ„ظٹظ„",
//       "ط¬ظ†ظٹظ†",
//       "ط¨ظٹطھ ظ„ط­ظ…",
//       "ط·ظˆظ„ظƒط±ظ…",
//       "ط£ط±ظٹط­ط§",
//       "ظ‚ظ„ظ‚ظٹظ„ظٹط©",
//       "ط³ظ„ظپظٹطھ",
//       "ط·ظˆط¨ط§ط³",
//       "ط؛ط²ط©",
//       "ط§ظ„ظ‚ط¯ط³"
//     ]
//         : [
//       "Nablus",
//       "Ramallah",
//       "Hebron",
//       "Jenin",
//       "Bethlehem",
//       "Tulkarm",
//       "Jericho",
//       "Qalqilya",
//       "Salfit",
//       "Tubas",
//       "Gaza",
//       "Jerusalem"
//     ];

//     showModalBottomSheet(
//       context: context,
//       backgroundColor: backgroundColor,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
//       ),
//       builder: (context) {
//         bool localLocating = false;
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return SizedBox(
//               height: MediaQuery.of(context).size.height * 0.75,
//               child: Container(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.max,
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Center(
//                       child: Container(
//                         width: 40,
//                         height: 5,
//                         decoration: BoxDecoration(
//                           color: borderColor,
//                           borderRadius: BorderRadius.circular(2.5),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     Text(
//                       isArabic ? "طھط­ط¯ظٹط¯ ط§ظ„ظ…ط¯ظٹظ†ط©" : "Select City",
//                       style: GoogleFonts.cairo(
//                         color: primaryTextColor,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 20),

//                     // Option 1: GPS Auto Detect
//                     ElevatedButton.icon(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor:
//                         const Color(0xFFD4A017).withValues(alpha: 0.15),
//                         foregroundColor: const Color(0xFFD4A017),
//                         elevation: 0,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                           side: const BorderSide(
//                               color: Color(0xFFD4A017), width: 1.5),
//                         ),
//                       ),
//                       onPressed: localLocating
//                           ? null
//                           : () {
//                         setModalState(() => localLocating = true);
//                         final nav = Navigator.of(context);
//                         final messenger = ScaffoldMessenger.of(context);
//                         Future.delayed(const Duration(milliseconds: 1500),
//                                 () {
//                               if (!mounted) return;
//                               if (nav.canPop()) {
//                                 nav.pop();
//                                 setState(() {
//                                   _selectedCity =
//                                   isArabic ? "ظ†ط§ط¨ظ„ط³" : "Nablus";
//                                 });
//                                 messenger.showSnackBar(
//                                   SnackBar(
//                                     backgroundColor: const Color(0xFF4CAF50),
//                                     content: Text(
//                                       isArabic
//                                           ? "طھظ… طھط­ط¯ظٹط¯ ظ…ظˆظ‚ط¹ظƒ طھظ„ظ‚ط§ط¦ظٹط§ظ‹: ظ†ط§ط¨ظ„ط³"
//                                           : "Location resolved automatically: Nablus",
//                                       style: GoogleFonts.cairo(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold),
//                                     ),
//                                   ),
//                                 );
//                               }
//                             });
//                       },
//                       icon: localLocating
//                           ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor: AlwaysStoppedAnimation(
//                                 Color(0xFFD4A017))),
//                       )
//                           : const Icon(Icons.gps_fixed),
//                       label: Text(
//                         localLocating
//                             ? (isArabic
//                             ? "ط¬ط§ط±ظٹ طھط­ط¯ظٹط¯ ط§ظ„ظ…ظˆظ‚ط¹..."
//                             : "Detecting Location...")
//                             : (isArabic
//                             ? "طھط­ط¯ظٹط¯ طھظ„ظ‚ط§ط¦ظٹ ط¹ط¨ط± GPS"
//                             : "Auto-detect via GPS"),
//                         style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
//                       ),
//                     ),

//                     const SizedBox(height: 20),
//                     Row(
//                       children: [
//                         Expanded(child: Divider(color: borderColor)),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 10),
//                           child: Text(
//                             isArabic
//                                 ? "ط£ظˆ ط§ط®طھط± ط§ظ„ظ…ط¯ظٹظ†ط© ظٹط¯ظˆظٹط§ظ‹"
//                                 : "Or select city manually",
//                             style: TextStyle(
//                                 color: secondaryTextColor, fontSize: 12),
//                           ),
//                         ),
//                         Expanded(child: Divider(color: borderColor)),
//                       ],
//                     ),
//                     const SizedBox(height: 15),

//                     // Option 2: Cities Dropdown/Grid
//                     Expanded(
//                       child: GridView.builder(
//                         shrinkWrap: false,
//                         physics: const BouncingScrollPhysics(),
//                         gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 3,
//                           childAspectRatio: 2.2,
//                           crossAxisSpacing: 10,
//                           mainAxisSpacing: 10,
//                         ),
//                         itemCount: cities.length,
//                         itemBuilder: (context, index) {
//                           final city = cities[index];
//                           final isSel = _selectedCity == city;
//                           return InkWell(
//                             onTap: () {
//                               setState(() {
//                                 _selectedCity = city;
//                               });
//                               Navigator.pop(context);
//                             },
//                             borderRadius: BorderRadius.circular(12),
//                             child: Container(
//                               alignment: Alignment.center,
//                               decoration: BoxDecoration(
//                                 color: isSel
//                                     ? const Color(0xFFD4A017)
//                                     .withValues(alpha: 0.15)
//                                     : inputFillColor,
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                     color: isSel
//                                         ? const Color(0xFFD4A017)
//                                         : borderColor),
//                               ),
//                               child: Text(
//                                 city,
//                                 style: GoogleFonts.cairo(
//                                   color: isSel
//                                       ? const Color(0xFFD4A017)
//                                       : primaryTextColor,
//                                   fontSize: 13,
//                                   fontWeight: isSel
//                                       ? FontWeight.bold
//                                       : FontWeight.normal,
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _topBarButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       borderRadius: BorderRadius.circular(20),
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(
//           color: topButtonBackground,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: chipBorderColor),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 18, color: topIconColor),
//             if (label.isNotEmpty) ...[
//               const SizedBox(width: 6),
//               Text(
//                 label,
//                 style: TextStyle(
//                   color: topIconColor,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
