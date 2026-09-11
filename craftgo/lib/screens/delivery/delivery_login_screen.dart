import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../core/delivery_shell.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/upload_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/customer_login_screen.dart';

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends State<DeliveryLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // OTP state
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  // License document state
  String? _licenseUrl;
  String? _licenseFileName;
  bool _isUploadingLicense = false;

  bool _idUploaded = false;
  bool _faceVerified = false;
  bool _isUploadingId = false;

  // ─── Logo Animation Controllers ──────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ─── Gold Colors ──────────────────────────────────────────────────
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar(t('يرجى إدخال بريد إلكتروني صحيح',
          'Please enter a valid email', context.read<AppState>()));
      return;
    }

    setState(() => _isSendingOtp = true);
    final success = await AuthService.sendOtp(email);
    setState(() => _isSendingOtp = false);

    if (success) {
      setState(() => _isOtpSent = true);
      _showSuccessSnackBar(t(
          'تم إرسال رمز التحقق OTP إلى بريدك الإلكتروني',
          'OTP code sent to your email',
          context.read<AppState>()));
    } else {
      _showErrorSnackBar(t(
          'فشل إرسال رمز التحقق OTP. تحقق من البريد.',
          'Failed to send OTP code. Check your email.',
          context.read<AppState>()));
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────
  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length < 4) {
      _showErrorSnackBar(t('يرجى إدخال رمز التحقق المكون من 4 أرقام',
          'Please enter 4-digit OTP', context.read<AppState>()));
      return;
    }

    setState(() => _isVerifyingOtp = true);
    final success = await AuthService.verifyOtp(email, otp);
    setState(() => _isVerifyingOtp = false);

    if (success) {
      setState(() => _isOtpVerified = true);
      _showSuccessSnackBar(t('تم تأكيد رمز OTP بنجاح!',
          'OTP code verified successfully!', context.read<AppState>()));
    } else {
      _showErrorSnackBar(t('رمز التحقق OTP غير صحيح أو منتهي الصلاحية',
          'Invalid or expired OTP code', context.read<AppState>()));
    }
  }

  // ── Pick and Upload Driver License (Image / PDF) ─────────────────────────
  Future<void> _pickAndUploadLicense() async {
    final appState = context.read<AppState>();
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() {
        _isUploadingLicense = true;
        _licenseFileName = file.name;
      });

      final uploadedUrl = await UploadService.uploadImage(file);

      setState(() => _isUploadingLicense = false);

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _licenseUrl = uploadedUrl;
          _idUploaded = true;
        });
        _showSuccessSnackBar(t('تم رفع رخصة القيادة بنجاح!',
            'Driver license uploaded successfully!', appState));
      } else {
        _showErrorSnackBar(t('فشل رفع رخصة القيادة',
            'Failed to upload driver license', appState));
      }
    } catch (e) {
      setState(() => _isUploadingLicense = false);
      _showErrorSnackBar(t('حدث خطأ أثناء رفع الرخصة',
          'Error uploading driver license', appState));
    }
  }

  // ── Complete Sign Up ──────────────────────────────────────────────────────
  Future<void> _handleSignup() async {
    final appState = context.read<AppState>();

    if (!_formKey.currentState!.validate()) return;

    if (!_isOtpVerified) {
      _showErrorSnackBar(t(
          'يرجى إكمال التحقق من البريد الإلكتروني برمز OTP أولاً',
          'Please verify your email via OTP code first',
          appState));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar(
        t('كلمتا المرور غير متطابقتين', 'Passwords do not match', appState),
      );
      return;
    }

    if (_licenseUrl == null || _licenseUrl!.isEmpty) {
      _showErrorSnackBar(
        t('يرجى رفع رخصة القيادة (صورة أو ملف PDF)',
            'Please upload your driver license (Image or PDF file)', appState),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = await AuthService.signup(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      roles: ['delivery'],
      phone: _phoneController.text.trim(),
      driverLicenseUrl: _licenseUrl,
      vehicleType: _vehicleTypeController.text.trim().isNotEmpty
          ? _vehicleTypeController.text.trim()
          : 'Car',
    );

    setState(() => _isLoading = false);

    if (user == null) {
      _showErrorSnackBar(
        t('فشل إنشاء الحساب. قد تكون كلمة المرور غير مطابقة للحساب أو البريد مستخدم.',
            'Signup failed. Password or credentials error.', appState),
      );
      return;
    }

    if (mounted) {
      final rolesList =
          (user['roles'] as List?)?.map((e) => e.toString()).toList() ??
              ['delivery'];
      final tokenStr =
          (user['token'] ?? await SessionService.getToken())?.toString() ?? '';

      appState.setAuth(
        userId: user['id']?.toString() ?? '',
        userName: user['name']?.toString() ?? _nameController.text.trim(),
        token: tokenStr,
        roles: rolesList,
        isVerified: user['isVerified'] == true,
        activeRole: 'delivery',
      );

      _showSuccessSnackBar(t(
          'تم تقديم طلب الانضمام بنجاح! حسابك قيد المراجعة والتحقق من قبل الآدمن.',
          'Application submitted successfully! Your account is pending admin verification.',
          appState));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    final accentGold = isDarkMode ? goldBright : goldDark;
    final topBg = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final topBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.18);
    final topIconColor = isDarkMode ? Colors.white : Colors.black87;

    final List<Color> shimmerColors = isDarkMode
        ? [
            goldBright,
            goldBrightLight,
            Colors.white,
            goldBrightLight,
            goldBright
          ]
        : [goldDark, goldBright, Colors.white, goldBright, goldDark];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: accentGold),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('انضم كأسطول توصيل', 'Join the Delivery Fleet', appState),
            style: GoogleFonts.cairo(
              color: accentGold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4, left: 4),
              child: _topBarButton(
                icon: Icons.language,
                label: isArabic ? "EN" : "عربي",
                bg: topBg,
                iconColor: topIconColor,
                borderColor: topBorder,
                onTap: () => appState.toggleLanguage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4, left: 4),
              child: _topBarButton(
                icon: isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: "",
                bg: topBg,
                iconColor: topIconColor,
                borderColor: topBorder,
                onTap: () => appState.toggleTheme(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // ─── Logo with Pulse + Shimmer ────────────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale =
                            1.0 + 0.05 * (1.0 - _pulseController.value);
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
                                    colors: shimmerColors,
                                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                    begin: Alignment(-1.0 + dx * 3, -0.3),
                                    end: Alignment(1.0 + dx * 3, 0.3),
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
                  const SizedBox(height: 8),

                  // ─── Title ──────────────────────────────────────────
                  Text(
                    isArabic ? "انضم كأسطول توصيل" : "Join the Delivery Fleet",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Subtitle ───────────────────────────────────────
                  Text(
                    t(
                      'سجل معنا وابدأ في جني الأرباح عبر توصيل الطلبات',
                      'Register and start earning by delivering crafts',
                      appState,
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ─── Name ───────────────────────────────────────────
                  _buildTextField(
                    controller: _nameController,
                    label: t('الاسم الكامل', 'Full Name', appState),
                    icon: Icons.person_outline,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return t('الاسم مطلوب', 'Name is required', appState);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ─── Email + Send OTP ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _emailController,
                          label: t('البريد الإلكتروني', 'Email Address', appState),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return t('البريد الإلكتروني مطلوب',
                                  'Email is required', appState);
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(val)) {
                              return t('بريد إلكتروني غير صالح',
                                  'Invalid email format', appState);
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSendingOtp || _isOtpVerified
                                ? null
                                : _handleSendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isOtpVerified
                                  ? Colors.green
                                  : const Color(0xFFD4A017),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSendingOtp
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black))
                                : _isOtpVerified
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.white)
                                    : Text(
                                        t('إرسال OTP', 'Send OTP', appState),
                                        style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ─── OTP Field (Shown if OTP sent) ──────────────────
                  if (_isOtpSent && !_isOtpVerified) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _otpController,
                            label: t('رمز التحقق OTP (4 أرقام)',
                                '4-Digit OTP Code', appState),
                            icon: Icons.mark_email_read_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                _isVerifyingOtp ? null : _handleVerifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(
                                    t('تأكيد OTP', 'Verify OTP', appState),
                                    style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],

                  // ─── Phone Number ──────────────────────────────────
                  _buildTextField(
                    controller: _phoneController,
                    label: t('رقم الهاتف', 'Phone Number', appState),
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),

                  // ─── Vehicle Type ──────────────────────────────────
                  _buildTextField(
                    controller: _vehicleTypeController,
                    label: t('نوع المركبة (سيارة / دراجة نارية / باص)',
                        'Vehicle Type (Car / Motorbike / Van)', appState),
                    icon: Icons.directions_car_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return t('نوع المركبة مطلوب',
                            'Vehicle type is required', appState);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ─── Password ──────────────────────────────────────
                  _buildPasswordField(
                    controller: _passwordController,
                    label: t('كلمة المرور', 'Password', appState),
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return t('كلمة المرور مطلوبة', 'Password is required',
                            appState);
                      }
                      if (val.length < 6) {
                        return t('يجب أن لا تقل عن 6 أحرف',
                            'Must be at least 6 characters', appState);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ─── Confirm Password ──────────────────────────────
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: t('تأكيد كلمة المرور', 'Confirm Password', appState),
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return t('يرجى تأكيد كلمة المرور',
                            'Please confirm your password', appState);
                      }
                      if (val != _passwordController.text) {
                        return t('كلمتا المرور غير متطابقتين',
                            'Passwords do not match', appState);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ─── Driver's License Document Upload (Image or PDF) ─────
                  Text(
                    t('رفع رخصة القيادة (صورة أو ملف PDF)',
                        'Upload Driver License (Image or PDF)', appState),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _AIVerificationCard(
                    icon: Icons.drive_eta_outlined,
                    title: _licenseFileName != null
                        ? '${t('تم الرفع: ', 'Uploaded: ', appState)}$_licenseFileName'
                        : t('اختر صورة أو ملف PDF لرخصة القيادة',
                            'Upload License (Image / PDF)', appState),
                    isCompleted: _licenseUrl != null,
                    isDark: isDarkMode,
                    onTap: _pickAndUploadLicense,
                    isLoading: _isUploadingLicense,
                  ),
                  const SizedBox(height: 28),

                  // ─── Sign Up Button ────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFD4A017).withValues(alpha: 0.35),
                          blurRadius: 18,
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
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleSignup,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : Text(
                              t('إرسال طلب الانضمام للآدمن',
                                  'Submit Application', appState),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // ─── Already have an account? Login ──────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('لديك حساب بالفعل؟ ', 'Already have an account? ',
                            appState),
                        style: GoogleFonts.cairo(
                          color: secondaryText,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomerLoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          t('تسجيل الدخول', 'Login', appState),
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFD4A017),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
    );
  }

  // ─── Input Fields ────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return TextFormField(
      controller: controller,
      style: GoogleFonts.cairo(color: primaryText),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon: Icon(icon, color: secondaryText),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.cairo(color: primaryText),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon: Icon(Icons.lock_outline, color: secondaryText),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: secondaryText,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  // ─── Top Bar Button ──────────────────────────────────────────────────────

  Widget _topBarButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: iconColor,
                  fontSize: 12,
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

// ─── AI Verification Card ───────────────────────────────────────────────

class _AIVerificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isCompleted;
  final bool isDark;
  final VoidCallback onTap;
  final bool isLoading;

  const _AIVerificationCard({
    required this.icon,
    required this.title,
    required this.isCompleted,
    required this.isDark,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C2431) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;

    return GestureDetector(
      onTap: isCompleted || isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? Colors.green : border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCompleted ? Colors.green : const Color(0xFFD4A017),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFD4A017),
                ),
              )
            else if (isCompleted)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Face Scan Dialog ────────────────────────────────────────────────────

class _FaceScanDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _FaceScanDialog({required this.onSuccess});

  @override
  State<_FaceScanDialog> createState() => _FaceScanDialogState();
}

class _FaceScanDialogState extends State<_FaceScanDialog> {
  String statusText = "Scanning Face...";
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _simulateScan();
  }

  void _simulateScan() async {
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) setState(() => progress = i / 100);
    }
    if (mounted) {
      setState(() => statusText = "Face Verified Successfully (99% Match)");
    }
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) widget.onSuccess();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    final bg = isDark ? const Color(0xFF1C2431) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.face_retouching_natural,
              color: Color(0xFFD4A017),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: GoogleFonts.cairo(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              color: const Color(0xFFD4A017),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import '../../app_state.dart';
// import '../../core/delivery_shell.dart';
// import '../../services/api_service.dart';
// import '../../services/session_service.dart';
// import '../../theme/app_palette.dart';

// class DeliveryLoginScreen extends StatefulWidget {
//   const DeliveryLoginScreen({super.key});

//   @override
//   State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
// }

// class _DeliveryLoginScreenState extends State<DeliveryLoginScreen>
//     with SingleTickerProviderStateMixin {
//   bool isLogin = true;
//   late AnimationController _fadeController;
//   late Animation<double> _fadeIn;

//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _nameController = TextEditingController();
//   final _vehicleTypeController = TextEditingController();

//   bool _idUploaded = false;
//   bool _faceVerified = false;
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _fadeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//       parent: _fadeController,
//       curve: Curves.easeIn,
//     ));
//     _fadeController.forward();
//   }

//   @override
//   void dispose() {
//     _fadeController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _nameController.dispose();
//     _vehicleTypeController.dispose();
//     super.dispose();
//   }

//   void _showErrorSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           style: GoogleFonts.cairo(color: Colors.white),
//         ),
//         backgroundColor: Colors.redAccent,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   Future<void> _handleAuthSubmit() async {
//     final isAr = context.read<AppState>().isArabic;

//     // Input Validation
//     if (_emailController.text.trim().isEmpty ||
//         _passwordController.text.trim().isEmpty) {
//       _showErrorSnackBar(
//         isAr
//             ? 'يرجى إدخال البريد الإلكتروني وكلمة المرور'
//             : 'Please fill in email and password',
//       );
//       return;
//     }

//     if (!isLogin) {
//       if (_nameController.text.trim().isEmpty ||
//           _vehicleTypeController.text.trim().isEmpty) {
//         _showErrorSnackBar(
//           isAr
//               ? 'يرجى إدخال الاسم ونوع المركبة'
//               : 'Please fill in name and vehicle type',
//         );
//         return;
//       }
//       if (!_idUploaded) {
//         _showErrorSnackBar(
//           isAr
//               ? 'يرجى رفع الهوية أو الإقامة للتحقق'
//               : 'Please upload your ID or residency card',
//         );
//         return;
//       }
//       if (!_faceVerified) {
//         _showErrorSnackBar(
//           isAr
//               ? 'يرجى إكمال التحقق من الوجه'
//               : 'Please complete AI face verification',
//         );
//         return;
//       }
//     }

//     setState(() => isLoading = true);

//     try {
//       final endpoint = isLogin ? '/auth/login' : '/auth/register';
//       final payload = isLogin
//           ? {
//               'email': _emailController.text.trim(),
//               'password': _passwordController.text.trim(),
//               'role': 'delivery',
//             }
//           : {
//               'name': _nameController.text.trim(),
//               'email': _emailController.text.trim(),
//               'password': _passwordController.text.trim(),
//               'vehicleType': _vehicleTypeController.text.trim(),
//               'role': 'delivery',
//               'idVerified': _idUploaded,
//               'faceVerified': _faceVerified,
//             };

//       final response = await ApiService.post(endpoint, body: payload);

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//         final token = data['token'] ?? 'delivery-token';
//         final user = data['user'] ?? {};

//         final userId =
//             user['id']?.toString() ?? user['_id']?.toString() ?? 'driver-123';
//         final userName = user['name'] ??
//             (isLogin ? 'أحمد المندوب' : _nameController.text.trim());
//         final userEmail = user['email'] ?? _emailController.text.trim();
//         final userCity = user['city'] ?? '';
//         final List<String> roles =
//             List<String>.from(user['roles'] ?? ['delivery']);

//         // Persist session
//         final isVerified = user['isVerified'] == true;
//         await SessionService.saveSession(
//           userId: userId,
//           name: userName,
//           email: userEmail,
//           roles: roles,
//           token: token,
//           city: userCity,
//           isVerified: isVerified,
//         );

//         if (mounted) {
//           final appState = context.read<AppState>();
//           appState.setAuth(
//             userId: userId,
//             userName: userName,
//             token: token,
//             roles: roles,
//             isVerified: user['isVerified'] == true,
//           );
//           appState.setActiveRole('delivery');

//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (_) => const DeliveryShell()),
//             (route) => false,
//           );
//         }
//       } else {
//         final errorData = jsonDecode(response.body);
//         _showErrorSnackBar(
//           errorData['message'] ??
//               (isAr
//                   ? 'فشلت العملية، يرجى المحاولة لاحقاً'
//                   : 'Authentication failed. Please try again.'),
//         );
//       }
//     } catch (e) {
//       // Fallback for offline testing / API connectivity issues
//       await SessionService.saveSession(
//         userId: 'driver-123',
//         name: isLogin ? 'أحمد المندوب' : _nameController.text.trim(),
//         email: _emailController.text.trim(),
//         roles: ['delivery'],
//         token: 'delivery-token',
//         city: '',
//       );

//       if (mounted) {
//         final appState = context.read<AppState>();
//         appState.setAuth(
//           userId: 'driver-123',
//           userName: isLogin ? 'أحمد المندوب' : _nameController.text.trim(),
//           token: 'delivery-token',
//           roles: ['delivery'],
//         );
//         appState.setActiveRole('delivery');

//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(builder: (_) => const DeliveryShell()),
//           (route) => false,
//         );
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = context.watch<AppState>();
//     final isAr = appState.isArabic;
//     final isDark = appState.isDarkMode;

//     final bg = AppPalette.background(isDark);
//     final textColor = AppPalette.primaryText(isDark);
//     final subColor = AppPalette.secondaryText(isDark);

//     return Directionality(
//       textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios_rounded,
//                 color: Color(0xFFE8B84B), size: 20),
//             onPressed: () => Navigator.pop(context),
//           ),
//         ),
//         body: FadeTransition(
//           opacity: _fadeIn,
//           child: SafeArea(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 28),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Logo and Title
//                   Center(
//                     child: Column(
//                       children: [
//                         Hero(
//                           tag: 'hero_delivery',
//                           child: Image.asset(
//                             'assets/images/logo.png',
//                             height: 100,
//                             color: AppPalette.goldBright,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'C R A F T G O',
//                           style: GoogleFonts.cinzel(
//                             color: const Color(0xFFE8B84B),
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 2.0,
//                           ),
//                         ),
//                         Text(
//                           'DELIVERY APP',
//                           style: GoogleFonts.cairo(
//                             color: AppPalette.goldDark,
//                             fontSize: 10,
//                             letterSpacing: 4.0,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 40),

//                   Center(
//                     child: Text(
//                       isLogin
//                           ? (isAr ? 'بوابة المندوبين' : 'Driver Portal')
//                           : (isAr ? 'انضم كأسطول توصيل' : 'Join the Fleet'),
//                       style: GoogleFonts.cairo(
//                           fontSize: 22,
//                           fontWeight: FontWeight.bold,
//                           color: textColor),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Center(
//                     child: Text(
//                       isLogin
//                           ? (isAr
//                               ? 'قم بتسجيل الدخول لبدء ورديتك وتتبع أرباحك'
//                               : 'Sign in to start your shift and track earnings')
//                           : (isAr
//                               ? 'سجل معنا وابدأ في جني الأرباح عبر توصيل الطلبات'
//                               : 'Register and start earning by delivering crafts'),
//                       style: GoogleFonts.cairo(fontSize: 12, color: subColor),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   const SizedBox(height: 32),

//                   if (!isLogin) ...[
//                     _InputField(
//                         controller: _nameController,
//                         icon: Icons.person_outline,
//                         label: isAr ? 'الاسم الكامل' : 'Full Name',
//                         isDark: isDark),
//                     const SizedBox(height: 12),
//                     _InputField(
//                         controller: _vehicleTypeController,
//                         icon: Icons.directions_car_outlined,
//                         label: isAr ? 'نوع السيارة / الدراجة' : 'Vehicle Type',
//                         isDark: isDark),
//                     const SizedBox(height: 12),
//                   ],

//                   _InputField(
//                       controller: _emailController,
//                       icon: Icons.email_outlined,
//                       label: isAr ? 'البريد الإلكتروني' : 'Email Address',
//                       isDark: isDark),
//                   const SizedBox(height: 12),
//                   _InputField(
//                       controller: _passwordController,
//                       icon: Icons.lock_outline,
//                       label: isAr ? 'كلمة المرور' : 'Password',
//                       isPassword: true,
//                       isDark: isDark),
//                   const SizedBox(height: 20),

//                   if (!isLogin) ...[
//                     Text(
//                       isAr
//                           ? 'الوثائق والتحقق الأمني الذكي (AI)'
//                           : 'Documents & AI Security Check',
//                       style: TextStyle(
//                           fontWeight: FontWeight.w600,
//                           fontSize: 13,
//                           color: textColor),
//                     ),
//                     const SizedBox(height: 12),
//                     _AIVerificationCard(
//                       icon: Icons.badge_outlined,
//                       title: isAr
//                           ? 'صورة الهوية أو الإقامة'
//                           : 'ID or Residency Card',
//                       isCompleted: _idUploaded,
//                       isDark: isDark,
//                       onTap: () => setState(() => _idUploaded = true),
//                     ),
//                     const SizedBox(height: 10),
//                     _AIVerificationCard(
//                       icon: Icons.face_retouching_natural,
//                       title: isAr
//                           ? 'مسح الوجه (Face Matching)'
//                           : 'AI Face Matching',
//                       isCompleted: _faceVerified,
//                       isDark: isDark,
//                       onTap: () {
//                         showDialog(
//                           context: context,
//                           builder: (ctx) => _FaceScanDialog(
//                             onSuccess: () {
//                               Navigator.pop(ctx);
//                               setState(() => _faceVerified = true);
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                     const SizedBox(height: 28),
//                   ],

//                   SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: ElevatedButton(
//                       onPressed: isLoading ? null : _handleAuthSubmit,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppPalette.goldBright,
//                         foregroundColor: const Color(0xFF1A1A1A),
//                         elevation: 0,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14)),
//                       ),
//                       child: isLoading
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                   strokeWidth: 2, color: Color(0xFF1A1A1A)))
//                           : Text(
//                               isLogin
//                                   ? (isAr ? 'تسجيل الدخول' : 'Sign In')
//                                   : (isAr
//                                       ? 'إرسال طلب الانضمام للآدمن'
//                                       : 'Submit Application'),
//                               style: const TextStyle(
//                                   fontSize: 15, fontWeight: FontWeight.bold),
//                             ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Center(
//                     child: TextButton(
//                       onPressed: () => setState(() => isLogin = !isLogin),
//                       child: Text(
//                         isLogin
//                             ? (isAr
//                                 ? 'ليس لديك حساب؟ قم بإنشاء حساب جديد'
//                                 : "Don't have an account? Register")
//                             : (isAr
//                                 ? 'لديك حساب بالفعل؟ قم بتسجيل الدخول'
//                                 : "Already have an account? Sign In"),
//                         style: GoogleFonts.cairo(
//                           color: const Color(0xFFE8B84B),
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _InputField extends StatelessWidget {
//   final TextEditingController controller;
//   final IconData icon;
//   final String label;
//   final bool isPassword;
//   final bool isDark;

//   const _InputField({
//     required this.controller,
//     required this.icon,
//     required this.label,
//     this.isPassword = false,
//     required this.isDark,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final inpBg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
//     final inpBorder =
//         isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
//     final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
//     final subColor = isDark ? const Color(0x66FFFFFF) : const Color(0xFF999999);

//     return ClipRRect(
//       borderRadius: BorderRadius.circular(14),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//         child: Container(
//           decoration: BoxDecoration(
//             color: inpBg,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: inpBorder, width: 0.5),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//           child: Row(
//             children: [
//               Icon(icon, color: const Color(0xFFE8B84B), size: 20),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: TextField(
//                   controller: controller,
//                   obscureText: isPassword,
//                   style: TextStyle(fontSize: 14, color: textColor),
//                   decoration: InputDecoration(
//                     border: InputBorder.none,
//                     hintText: label,
//                     hintStyle: TextStyle(color: subColor, fontSize: 13),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _AIVerificationCard extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final bool isCompleted;
//   final bool isDark;
//   final VoidCallback onTap;

//   const _AIVerificationCard({
//     required this.icon,
//     required this.title,
//     required this.isCompleted,
//     required this.isDark,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final bg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
//     final border = isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);

//     return GestureDetector(
//       onTap: isCompleted ? null : onTap,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: bg,
//           borderRadius: BorderRadius.circular(14),
//           border:
//               Border.all(color: isCompleted ? Colors.green : border, width: 1),
//         ),
//         child: Row(
//           children: [
//             Icon(icon,
//                 color: isCompleted ? Colors.green : const Color(0xFFE8B84B)),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Text(
//                 title,
//                 style: TextStyle(
//                   color: isDark ? Colors.white : Colors.black,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//             if (isCompleted)
//               const Icon(Icons.check_circle, color: Colors.green)
//             else
//               const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _FaceScanDialog extends StatefulWidget {
//   final VoidCallback onSuccess;
//   const _FaceScanDialog({required this.onSuccess});

//   @override
//   State<_FaceScanDialog> createState() => _FaceScanDialogState();
// }

// class _FaceScanDialogState extends State<_FaceScanDialog> {
//   String statusText = "Scanning Face...";
//   double progress = 0;

//   @override
//   void initState() {
//     super.initState();
//     _simulateScan();
//   }

//   void _simulateScan() async {
//     for (int i = 0; i <= 100; i += 10) {
//       await Future.delayed(const Duration(milliseconds: 150));
//       if (mounted) setState(() => progress = i / 100);
//     }
//     if (mounted) {
//       setState(() => statusText = "Face Verified Successfully (99% Match)");
//     }
//     await Future.delayed(const Duration(seconds: 1));
//     if (mounted) widget.onSuccess();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: const Color(0xFF1A1A1A),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.face_retouching_natural,
//                 color: Color(0xFFE8B84B), size: 60),
//             const SizedBox(height: 16),
//             Text(statusText,
//                 style: const TextStyle(color: Colors.white, fontSize: 16)),
//             const SizedBox(height: 20),
//             LinearProgressIndicator(
//               value: progress,
//               backgroundColor: Colors.white24,
//               color: const Color(0xFFE8B84B),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
