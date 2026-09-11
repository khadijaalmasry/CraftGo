import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import 'customer_login_screen.dart'; // ← added for navigation

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isOtpSent = false;

  Timer? _timer;
  int _otpCountdown = 60;

  // ─── Logo Animation Controllers ──────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ─── Gold Colors (same as CustomerLoginScreen & craftsman registration) ──
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
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() {
          _otpCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appState = context.read<AppState>();

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('كلمتا المرور غير متطابقتين', 'Passwords do not match', appState),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    if (!_isOtpSent) {
      // Step 1: Send OTP
      final sent = await AuthService.sendOtp(email);
      setState(() => _isLoading = false);

      if (sent) {
        setState(() {
          _isOtpSent = true;
        });
        _startOtpTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t('تم إرسال كود التحقق إلى بريدك الإلكتروني',
                    'Verification code sent to your email', appState),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t('فشل إرسال كود التحقق', 'Failed to send verification code',
                    appState),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      return;
    }

    // Step 2: Verify OTP
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('الرجاء إدخال كود التحقق كاملاً',
                'Please enter full verification code', appState),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isVerified = await AuthService.verifyOtp(email, otp);
    if (!isVerified) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('كود التحقق غير صحيح', 'Invalid verification code', appState),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Step 3: Signup
    final user = await AuthService.signup(
      name: _nameController.text.trim(),
      email: email,
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      roles: ['customer'],
    );

    setState(() => _isLoading = false);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('فشل إنشاء الحساب. قد يكون البريد مستخدماً.',
                  'Signup failed. Email might be in use.', appState),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تم إنشاء الحساب بنجاح!', 'Account created successfully!',
                appState),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the main shell (Customer dashboard)
      appState.setActiveRole('customer');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => appState.getShellForActiveRole()),
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

    // ─── Compute shimmer colors inside build ──────────────────────
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
            t('إنشاء حساب جديد', 'Create Account', appState),
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
                  const SizedBox(height: 8), // ← reduced from 16 to 8

                  // ─── Title (Cairo font) ──────────────────────────
                  Text(
                    isArabic ? "حساب جديد" : "Create Account",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Subtitle ─────────────────────────────────────
                  Text(
                    t(
                        'أنشئ حسابك لتتمكن من استكشاف المنتجات وطلب الخدمات',
                        'Create an account to explore products and request services',
                        appState),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Full Name
                  _field(
                    context: context,
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

                  // Email
                  _field(
                    context: context,
                    controller: _emailController,
                    label: t('البريد الإلكتروني', 'Email', appState),
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return t('البريد الإلكتروني مطلوب', 'Email is required',
                            appState);
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(val)) {
                        return t('بريد إلكتروني غير صالح',
                            'Invalid email format', appState);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Phone
                  _field(
                    context: context,
                    controller: _phoneController,
                    label: t('رقم الهاتف (اختياري)', 'Phone Number (Optional)',
                        appState),
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),

                  // Password
                  _passwordField(
                    context: context,
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

                  // Confirm Password
                  _passwordField(
                    context: context,
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
                  const SizedBox(height: 15),

                  // OTP Input (Visible only if _isOtpSent is true)
                  if (_isOtpSent) ...[
                    const SizedBox(height: 10),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (index) {
                          return SizedBox(
                            width: 55,
                            height: 65,
                            child: TextFormField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: surface,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD4A017), width: 2),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  if (value.length > 1) {
                                    _otpControllers[index].text =
                                        value[value.length - 1];
                                    _otpControllers[index].selection =
                                        TextSelection.fromPosition(
                                            const TextPosition(offset: 1));
                                  }
                                  if (index < 3) {
                                    FocusScope.of(context).requestFocus(
                                        _otpFocusNodes[index + 1]);
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
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _otpCountdown == 0
                            ? () async {
                                final success = await AuthService.sendOtp(
                                    _emailController.text.trim());
                                if (!context.mounted) return;
                                if (success) {
                                  _startOtpTimer();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(t('فشل الإرسال',
                                          'Failed to send', appState)),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Text(
                          _otpCountdown > 0
                              ? (isArabic
                                  ? "إعادة الإرسال بعد ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}"
                                  : "Resend code in ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}")
                              : (isArabic
                                  ? "إعادة إرسال الرمز"
                                  : "Resend Code"),
                          style: TextStyle(
                            color: _otpCountdown > 0
                                ? secondaryText
                                : const Color(0xFFD4A017),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  const SizedBox(height: 20),

                  // Signup Button
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
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _handleSignup,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : Text(
                              _isOtpSent
                                  ? t('تأكيد وإنشاء الحساب', 'Verify & Sign Up',
                                      appState)
                                  : t('إنشاء حساب', 'Sign Up', appState),
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
                          // Navigate to Customer Login Screen
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

  Widget _field({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final appState = context.watch<AppState>();
    final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = appState.isDarkMode ? Colors.white70 : Colors.black54;
    final surface =
        appState.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final borderColor = appState.isDarkMode ? Colors.white12 : Colors.black12;

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

  Widget _passwordField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    final appState = context.watch<AppState>();
    final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = appState.isDarkMode ? Colors.white70 : Colors.black54;
    final surface =
        appState.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final borderColor = appState.isDarkMode ? Colors.white12 : Colors.black12;

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

  // ─── Top Bar Button (matches CustomerLoginScreen) ──────────────────────

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
// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../app_state.dart';
// import '../services/auth_service.dart';

// class CustomerSignupScreen extends StatefulWidget {
//   const CustomerSignupScreen({super.key});

//   @override
//   State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
// }

// class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController = TextEditingController();

//   final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
//   final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;
//   bool _isLoading = false;
//   bool _isOtpSent = false;
  
//   Timer? _timer;
//   int _otpCountdown = 60;

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     for (var c in _otpControllers) {
//       c.dispose();
//     }
//     for (var n in _otpFocusNodes) {
//       n.dispose();
//     }
//     _timer?.cancel();
//     super.dispose();
//   }

//   void _startOtpTimer() {
//     _otpCountdown = 60;
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_otpCountdown > 0) {
//         setState(() {
//           _otpCountdown--;
//         });
//       } else {
//         timer.cancel();
//       }
//     });
//   }

//   String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

//   void _handleSignup() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     final appState = context.read<AppState>();
    
//     if (_passwordController.text != _confirmPasswordController.text) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             t('كلمتا المرور غير متطابقتين', 'Passwords do not match', appState),
//           ),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final email = _emailController.text.trim();

//     if (!_isOtpSent) {
//       // Step 1: Send OTP
//       final sent = await AuthService.sendOtp(email);
//       setState(() => _isLoading = false);

//       if (sent) {
//         setState(() {
//           _isOtpSent = true;
//         });
//         _startOtpTimer();
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 t('تم إرسال كود التحقق إلى بريدك الإلكتروني', 'Verification code sent to your email', appState),
//               ),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 t('فشل إرسال كود التحقق', 'Failed to send verification code', appState),
//               ),
//               backgroundColor: Colors.redAccent,
//             ),
//           );
//         }
//       }
//       return;
//     }

//     // Step 2: Verify OTP
//     final otp = _otpControllers.map((c) => c.text).join();
//     if (otp.length < 4) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             t('الرجاء إدخال كود التحقق كاملاً', 'Please enter full verification code', appState),
//           ),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//       return;
//     }

//     final isVerified = await AuthService.verifyOtp(email, otp);
//     if (!isVerified) {
//       setState(() => _isLoading = false);
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               t('كود التحقق غير صحيح', 'Invalid verification code', appState),
//             ),
//             backgroundColor: Colors.redAccent,
//           ),
//         );
//       }
//       return;
//     }

//     // Step 3: Signup
//     final user = await AuthService.signup(
//       name: _nameController.text.trim(),
//       email: email,
//       phone: _phoneController.text.trim(),
//       password: _passwordController.text,
//       roles: ['customer'],
//     );

//     setState(() => _isLoading = false);

//     if (user == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               t('فشل إنشاء الحساب. قد يكون البريد مستخدماً.', 'Signup failed. Email might be in use.', appState),
//             ),
//             backgroundColor: Colors.redAccent,
//           ),
//         );
//       }
//       return;
//     }

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             t('تم إنشاء الحساب بنجاح!', 'Account created successfully!', appState),
//           ),
//           backgroundColor: Colors.green,
//         ),
//       );
      
//       // Navigate to the main shell (Customer dashboard)
//       appState.setActiveRole('customer');
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => appState.getShellForActiveRole()),
//         (route) => false,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = context.watch<AppState>();
//     final isArabic = appState.isArabic;
//     final isDarkMode = appState.isDarkMode;
//     final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//     final primaryText = isDarkMode ? Colors.white : Colors.black87;
//     final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

//     return Directionality(
//       textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFFE8B84B)),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: Text(
//             t('إنشاء حساب جديد', 'Create Account', appState),
//             style: TextStyle(
//               color: primaryText,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         body: SafeArea(
//           child: SingleChildScrollView(
//             physics: const BouncingScrollPhysics(),
//             padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   const SizedBox(height: 10),
//                   // Header text
//                   Text(
//                     t('مرحباً بك في عالم الحرف', 'Welcome to the world of crafts', appState),
//                     style: TextStyle(
//                       color: const Color(0xFFD4A017),
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       fontFamily: 'ArefRuqaa',
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     t('أنشئ حسابك لتتمكن من استكشاف المنتجات وطلب الخدمات', 'Create an account to explore products and request services', appState),
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: isDarkMode ? Colors.white70 : Colors.black54,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 30),

//                   // Full Name
//                   _field(
//                     context: context,
//                     controller: _nameController,
//                     label: t('الاسم الكامل', 'Full Name', appState),
//                     icon: Icons.person_outline,
//                     validator: (val) {
//                       if (val == null || val.trim().isEmpty) {
//                         return t('الاسم مطلوب', 'Name is required', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),

//                   // Email
//                   _field(
//                     context: context,
//                     controller: _emailController,
//                     label: t('البريد الإلكتروني', 'Email', appState),
//                     icon: Icons.email_outlined,
//                     keyboardType: TextInputType.emailAddress,
//                     validator: (val) {
//                       if (val == null || val.trim().isEmpty) {
//                         return t('البريد الإلكتروني مطلوب', 'Email is required', appState);
//                       }
//                       if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
//                         return t('بريد إلكتروني غير صالح', 'Invalid email format', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),

//                   // Phone
//                   _field(
//                     context: context,
//                     controller: _phoneController,
//                     label: t('رقم الهاتف (اختياري)', 'Phone Number (Optional)', appState),
//                     icon: Icons.phone_outlined,
//                     keyboardType: TextInputType.phone,
//                   ),
//                   const SizedBox(height: 15),

//                   // Password
//                   _passwordField(
//                     context: context,
//                     controller: _passwordController,
//                     label: t('كلمة المرور', 'Password', appState),
//                     obscure: _obscurePassword,
//                     onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
//                     validator: (val) {
//                       if (val == null || val.isEmpty) {
//                         return t('كلمة المرور مطلوبة', 'Password is required', appState);
//                       }
//                       if (val.length < 6) {
//                         return t('يجب أن لا تقل عن 6 أحرف', 'Must be at least 6 characters', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),

//                   // Confirm Password
//                   _passwordField(
//                     context: context,
//                     controller: _confirmPasswordController,
//                     label: t('تأكيد كلمة المرور', 'Confirm Password', appState),
//                     obscure: _obscureConfirmPassword,
//                     onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
//                     validator: (val) {
//                       if (val == null || val.isEmpty) {
//                         return t('يرجى تأكيد كلمة المرور', 'Please confirm your password', appState);
//                       }
//                       if (val != _passwordController.text) {
//                         return t('كلمتا المرور غير متطابقتين', 'Passwords do not match', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),

//                   // OTP Input (Visible only if _isOtpSent is true)
//                   if (_isOtpSent) ...[
//                     const SizedBox(height: 10),
//                     Directionality(
//                       textDirection: TextDirection.ltr,
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: List.generate(4, (index) {
//                           return SizedBox(
//                             width: 55,
//                             height: 65,
//                             child: TextFormField(
//                               controller: _otpControllers[index],
//                               focusNode: _otpFocusNodes[index],
//                               keyboardType: TextInputType.number,
//                               textAlign: TextAlign.center,
//                               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                               style: TextStyle(
//                                 color: primaryText,
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               decoration: InputDecoration(
//                                 filled: true,
//                                 fillColor: isDarkMode ? const Color(0xFF1C2431) : Colors.white,
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(16),
//                                   borderSide: BorderSide(color: borderColor),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(16),
//                                   borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 if (value.isNotEmpty) {
//                                   if (value.length > 1) {
//                                     _otpControllers[index].text = value[value.length - 1];
//                                     _otpControllers[index].selection = TextSelection.fromPosition(const TextPosition(offset: 1));
//                                   }
//                                   if (index < 3) {
//                                     FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
//                                   } else {
//                                     _otpFocusNodes[index].unfocus();
//                                   }
//                                 } else if (value.isEmpty && index > 0) {
//                                   FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
//                                 }
//                               },
//                             ),
//                           );
//                         }),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Center(
//                       child: TextButton(
//                         onPressed: _otpCountdown == 0
//                             ? () async {
//                                 final success = await AuthService.sendOtp(_emailController.text.trim());
//                                 if (!context.mounted) return;
//                                 if (success) {
//                                   _startOtpTimer();
//                                 } else {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(
//                                       content: Text(t('فشل الإرسال', 'Failed to send', appState)),
//                                       backgroundColor: Colors.redAccent,
//                                     ),
//                                   );
//                                 }
//                               }
//                             : null,
//                         child: Text(
//                           _otpCountdown > 0
//                               ? (isArabic
//                                   ? "إعادة الإرسال بعد ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}"
//                                   : "Resend code in ${(_otpCountdown ~/ 60).toString().padLeft(2, '0')}:${(_otpCountdown % 60).toString().padLeft(2, '0')}")
//                               : (isArabic ? "إعادة إرسال الرمز" : "Resend Code"),
//                           style: TextStyle(
//                             color: _otpCountdown > 0 ? (isDarkMode ? Colors.white70 : Colors.black54) : const Color(0xFFD4A017),
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 15),
//                   ],

//                   const SizedBox(height: 20),

//                   // Signup Button
//                   Container(
//                     width: double.infinity,
//                     height: 56,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(30),
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
//                       ),
//                       boxShadow: [
//                         BoxShadow(
//                           color: const Color(0xFFD4A017).withValues(alpha: 0.35),
//                           blurRadius: 18,
//                           spreadRadius: 1,
//                           offset: const Offset(0, 5),
//                         ),
//                       ],
//                     ),
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.transparent,
//                         shadowColor: Colors.transparent,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30)),
//                       ),
//                       onPressed: _handleSignup,
//                       child: _isLoading
//                           ? const SizedBox(
//                               width: 24,
//                               height: 24,
//                               child: CircularProgressIndicator(
//                                   strokeWidth: 2, color: Colors.black))
//                           : Text(
//                               _isOtpSent
//                                   ? t('تأكيد وإنشاء الحساب', 'Verify & Sign Up', appState)
//                                   : t('إنشاء حساب', 'Sign Up', appState),
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: isDarkMode ? Colors.black : Colors.white,
//                               ),
//                             ),
//                     ),
//                   ),
//                   const SizedBox(height: 25),

//                   // Already have an account? Login
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         t('لديك حساب بالفعل؟ ', 'Already have an account? ', appState),
//                         style: TextStyle(
//                           color: isDarkMode ? Colors.white70 : Colors.black54,
//                           fontSize: 15,
//                         ),
//                       ),
//                       GestureDetector(
//                         onTap: () => Navigator.pop(context),
//                         child: Text(
//                           t('تسجيل الدخول', 'Login', appState),
//                           style: const TextStyle(
//                             color: Color(0xFFD4A017),
//                             fontWeight: FontWeight.bold,
//                             fontSize: 15,
//                           ),
//                         ),
//                       ),
//                     ],
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

//   // ─── Input Fields ────────────────────────────────────────────────────────

//   Widget _field({
//     required BuildContext context,
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     TextInputType? keyboardType,
//     String? Function(String?)? validator,
//   }) {
//     final appState = context.watch<AppState>();
//     final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
//     final secondaryText = appState.isDarkMode ? Colors.white70 : Colors.black54;
//     final surface = appState.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final borderColor = appState.isDarkMode ? Colors.white12 : Colors.black12;

//     return TextFormField(
//       controller: controller,
//       style: TextStyle(color: primaryText),
//       keyboardType: keyboardType,
//       validator: validator,
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: TextStyle(color: secondaryText),
//         prefixIcon: Icon(icon, color: secondaryText),
//         filled: true,
//         fillColor: surface,
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: BorderSide(color: borderColor),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 2),
//         ),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       ),
//     );
//   }

//   Widget _passwordField({
//     required BuildContext context,
//     required TextEditingController controller,
//     required String label,
//     required bool obscure,
//     required VoidCallback onToggle,
//     String? Function(String?)? validator,
//   }) {
//     final appState = context.watch<AppState>();
//     final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
//     final secondaryText = appState.isDarkMode ? Colors.white70 : Colors.black54;
//     final surface = appState.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final borderColor = appState.isDarkMode ? Colors.white12 : Colors.black12;

//     return TextFormField(
//       controller: controller,
//       obscureText: obscure,
//       style: TextStyle(color: primaryText),
//       validator: validator,
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: TextStyle(color: secondaryText),
//         prefixIcon: Icon(Icons.lock_outline, color: secondaryText),
//         suffixIcon: IconButton(
//           icon: Icon(
//             obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
//             color: secondaryText,
//           ),
//           onPressed: onToggle,
//         ),
//         filled: true,
//         fillColor: surface,
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: BorderSide(color: borderColor),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 1),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.redAccent, width: 2),
//         ),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       ),
//     );
//   }
// }
