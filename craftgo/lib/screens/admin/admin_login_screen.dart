import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/admin_shell.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../widgets/login_role_selection.dart'; // Added import

class AdminLoginScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const AdminLoginScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  late bool isArabic;
  late bool isDarkMode;

  final _adminIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _showOtp = false;
  bool _isVerifying = false;
  bool _otpVerified = false;
  String _aiSecurityMessage = '';
  String _otpDestination = '';
  Color _aiSecurityColor = const Color(0xFFD4A017);
  IconData _aiSecurityIcon = Icons.verified_outlined;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnim;

  // Gold/Navy palette (matching onboarding)
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color navy = Color(0xFF0D1B33);
  static const Color navyLight = Color(0xFF1B3A66);

  String t(String ar, String en) => isArabic ? ar : en;

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get primaryText => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryText => isDarkMode ? Colors.white70 : Colors.black54;
  Color get borderColor => isDarkMode ? Colors.white12 : Colors.black12;
  Color get accentGold => isDarkMode ? goldBright : goldDark;
  Color get accentNavy => isDarkMode ? navyLight : navy;

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _adminIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _verifyCredentials() async {
    final staffId = _adminIdController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (staffId.isEmpty || email.isEmpty || password.isEmpty) {
      _showError(t('يرجى تعبئة رمز الإدارة والبريد وكلمة المرور.',
          'Please enter the staff ID, email, and password.'));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await ApiService.post(
        '/admin/login/request-otp',
        body: {
          'staffId': staffId,
          'email': email,
          'password': password,
        },
      );

      final data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showError(
          (data['error'] ??
                  t('فشل التحقق من بيانات الإدارة.',
                      'Admin verification failed.'))
              .toString(),
        );
        return;
      }

      final unusualHours = data['unusualHours'] == true;

      setState(() {
        _showOtp = true;
        _otpDestination = (data['otpDestination'] ?? '').toString();

        _aiSecurityMessage = isArabic
            ? (data['securityMessageAr'] ??
                    'تم التحقق من بيانات الدخول وإرسال رمز الأمان.')
                .toString()
            : (data['securityMessageEn'] ??
                    'Credentials verified and the security code was sent.')
                .toString();

        _aiSecurityColor = unusualHours ? Colors.orange : accentGold;
        _aiSecurityIcon = unusualHours
            ? Icons.warning_amber_rounded
            : Icons.verified_outlined;
      });
    } catch (error) {
      debugPrint('Admin credential verification error: $error');
      _showError(t('تعذر الاتصال بالخادم. تأكد من تشغيل الباك إند.',
          'Could not connect to the server.'));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showError(t('أدخل رمز التحقق المكوّن من 6 أرقام.',
          'Enter the 6-digit verification code.'));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await ApiService.post(
        '/admin/login/verify-otp',
        body: {
          'staffId': _adminIdController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'otp': otp,
        },
      );

      final data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showError(
          (data['error'] ??
                  t('رمز التحقق غير صحيح.', 'OTP verification failed.'))
              .toString(),
        );
        return;
      }

      final user = Map<String, dynamic>.from(data['user'] as Map);
      final roles = List<String>.from(user['roles'] ?? const ['admin']);
      final token = (data['token'] ?? '').toString();

      await SessionService.saveSession(
        userId: (user['id'] ?? '').toString(),
        name: (user['name'] ?? '').toString(),
        email: (user['email'] ?? '').toString(),
        roles: roles,
        token: token,
        isVerified: true,
      );

      if (!mounted) return;

      setState(() => _otpVerified = true);

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminShell()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('Admin OTP verification error: $error');
      _showError(t('تعذر التحقق من الرمز. حاول مرة أخرى.',
          'Could not verify the code.'));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildFormCard() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentGold.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Admin ID
                _buildLabel(t('رمز معرف الإدارة', 'Admin Staff ID')),
                const SizedBox(height: 8),
                _buildField(
                  controller: _adminIdController,
                  hint: t('أدخل رمز الإدارة', 'Enter admin ID'),
                  icon: Icons.badge_outlined,
                  enabled: !_showOtp,
                ),
                const SizedBox(height: 16),

                // Email
                _buildLabel(t('البريد المهني', 'Work Email')),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailController,
                  hint: t('admin@craftgo.com', 'admin@craftgo.com'),
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_showOtp,
                ),
                const SizedBox(height: 16),

                // Password
                _buildLabel(t('كلمة المرور', 'Password')),
                const SizedBox(height: 8),
                _buildPasswordField(
                  controller: _passwordController,
                  enabled: !_showOtp,
                ),
                const SizedBox(height: 24),

                // AI Security result banner
                if (_aiSecurityMessage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _aiSecurityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _aiSecurityColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_aiSecurityIcon,
                            color: _aiSecurityColor, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _aiSecurityMessage,
                            style: GoogleFonts.cairo(
                              color: _aiSecurityColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // OTP field
                if (_showOtp) ...[
                  _buildLabel(t('رمز التحقق (OTP)', 'Two-Factor OTP')),
                  const SizedBox(height: 4),
                  Text(
                    _otpDestination.isEmpty
                        ? t(
                            'تم إرسال رمز الأمان إلى البريد المخصص للإدارة.',
                            'The security code was sent to the admin mailbox.',
                          )
                        : t(
                            'تم إرسال الرمز إلى: $_otpDestination',
                            'Code sent to: $_otpDestination',
                          ),
                    style: GoogleFonts.cairo(
                      color: accentGold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _otpController,
                    hint: t('أدخل رمز التحقق المكون من 6 أرقام',
                        'Enter 6-digit OTP'),
                    icon: Icons.security,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                ],

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isVerifying
                        ? null
                        : (_showOtp ? _verifyOtp : _verifyCredentials),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _otpVerified ? Colors.green : accentGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                t('جاري التحقق الآمن...',
                                    'Verifying securely...'),
                                style: GoogleFonts.cairo(
                                  color: isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : _otpVerified
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    t('تم التحقق! جاري الدخول...',
                                        'Verified! Redirecting...'),
                                    style: GoogleFonts.cairo(
                                      color: isDarkMode
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _showOtp
                                    ? t('تحقق من الرمز', 'Verify OTP')
                                    : t('تحقق من الهوية', 'Verify Identity'),
                                style: GoogleFonts.cairo(
                                  color: isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 16,
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

    Widget buildSecurityStatsRow() {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.lock_outline,
              t('256-bit', '256-bit'),
              t('تشفير', 'Encryption'),
              accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              Icons.shield_outlined,
              t('صفر', 'Zero'),
              t('خروقات', 'Breaches'),
              accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              Icons.psychology_outlined,
              t('ذكاء اصطناعي', 'AI'),
              t('مراقبة', 'Monitoring'),
              accentGold,
            ),
          ),
        ],
      );
    }

    Widget buildTopBar() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topBtn(
            icon: isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginRoleSelectionScreen(),
                ),
              );
            },
          ),
          Row(
            children: [
              _topBtn(
                icon: Icons.language,
                label: isArabic ? 'EN' : 'عربي',
                onTap: () => setState(() {
                  isArabic = !isArabic;
                  widget.onToggleLanguage();
                }),
              ),
              const SizedBox(width: 8),
              _topBtn(
                icon: isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                onTap: () => setState(() {
                  isDarkMode = !isDarkMode;
                  widget.onToggleTheme();
                }),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildDesktopLayout() {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1050),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Row(
            children: [
              // Left Column: Security Showcase & Portal Info
              Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: isArabic ? 0 : 32,
                    left: isArabic ? 32 : 0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseAnim.value * 0.97,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDarkMode
                                    ? [goldBright, goldDark]
                                    : [goldDark, navyLight],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentGold.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t('بوابة إدارة CraftGo', 'CraftGo Admin Portal'),
                        style: GoogleFonts.cairo(
                          color: primaryText,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('دخول آمن محمي بالذكاء الاصطناعي ومراقب على مدار الساعة',
                            'AI-Secured & Monitored Access Control'),
                        style: GoogleFonts.cairo(
                          color: accentGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      buildSecurityStatsRow(),
                    ],
                  ),
                ),
              ),

              // Right Column: Form Card
              Expanded(
                flex: 5,
                child: buildFormCard(),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // Subtle animated gradient background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [
                                const Color(0xFF0D1420),
                                const Color(0xFF0D1B33),
                                const Color(0xFF0D1420),
                              ]
                            : [
                                const Color(0xFFF5F6F8),
                                const Color(0xFFF0F4FF),
                                const Color(0xFFF5F6F8),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Decorative circles
            Positioned(
              top: -80,
              right: -80,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentGold.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withValues(alpha: 0.04),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: buildTopBar(),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          return buildDesktopLayout();
                        } else {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (context, child) => Transform.scale(
                                    scale: _pulseAnim.value * 0.97,
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDarkMode
                                              ? [goldBright, goldDark]
                                              : [goldDark, navyLight],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentGold.withValues(
                                                alpha: 0.4),
                                            blurRadius: 30,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        color: Colors.white,
                                        size: 46,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  t('بوابة إدارة CraftGo',
                                      'CraftGo Admin Portal'),
                                  style: GoogleFonts.cairo(
                                    color: primaryText,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t('دخول آمن محمي بالذكاء الاصطناعي',
                                      'AI-Secured Access'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    color: accentGold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                buildFormCard(),
                                const SizedBox(height: 24),
                                buildSecurityStatsRow(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.cairo(
        color: secondaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: GoogleFonts.cairo(color: primaryText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon: Icon(icon, color: accentGold, size: 20),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentGold, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      enabled: enabled,
      style: GoogleFonts.cairo(color: primaryText),
      decoration: InputDecoration(
        hintText: t('••••••••', '••••••••'),
        hintStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon:
            const Icon(Icons.lock_outline, color: Color(0xFFD4A017), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: secondaryText,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFFD4A017), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(color: secondaryText, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _topBtn({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label != null ? 12 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primaryText),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: primaryText,
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
