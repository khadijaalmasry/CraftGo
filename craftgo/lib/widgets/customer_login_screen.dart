import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'role_selection_screen.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../../main.dart'; // for OnboardingScreen
import 'login_role_selection.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late AnimationController _shimmerController;

  // ── Gold/Navy Palette (Synchronized with Onboarding) ─────────────
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color navy = Color(0xFF0D1B33);
  static const Color navyLight = Color(0xFF1B3A66);

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  List<Color> logoShimmerColors(AppState state) => state.isDarkMode
      ? [goldBright, goldBrightLight, Colors.white, goldBrightLight, goldBright]
      : [goldDark, goldBright, Colors.white, goldBright, goldDark];

  void _navigateAfterLogin(BuildContext context, List<String> roles) {
    if (roles.isEmpty) roles = ['customer'];
    final appState = context.read<AppState>();

    if (roles.length == 1) {
      appState.setActiveRole(roles.first);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => appState.getShellForActiveRole()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginRoleSelectionScreen()),
      );
    }
  }

  void _handleLogin() async {
    final appState = context.read<AppState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('يرجى ملء جميع الحقول', 'Please fill all fields', appState),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = await AuthService.login(email, password);
    setState(() => _isLoading = false);

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('فشل تسجيل الدخول. تحقق من بياناتك.',
                'Login failed. Check your credentials.', appState),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final token = await SessionService.getToken() ?? '';
    final roles = List<String>.from(user['roles'] ?? ['customer']);
    final isVerified = user['isVerified'] == true;
    appState.setAuth(
      userId: user['id']?.toString() ?? '',
      userName: user['name'] ?? '',
      token: token,
      roles: roles,
      isVerified: isVerified,
    );
    if (!mounted) return;
    _navigateAfterLogin(context, roles);
  }

  void _handleGuest() {
    final appState = context.read<AppState>();
    appState.setGuest();
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => appState.getShellForActiveRole()),
    );
  }

  // ─── Shared form builder ─────────────────────────────────────────────
  Widget _buildForm({
    required bool showLogo,
    required AppState appState,
    required Color accentGold,
    required Color buttonGradient1,
    required Color buttonGradient2,
    required Color buttonTextColor,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
  }) {
    final isArabic = appState.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLogo) ...[
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              final dx = _shimmerController.value;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: logoShimmerColors(appState),
                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                    begin: Alignment(-1.0 + dx * 3, -0.3),
                    end: Alignment(1.0 + dx * 3, 0.3),
                    tileMode: TileMode.clamp,
                  ).createShader(bounds);
                },
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 140,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        Text(
          t('تسجيل الدخول', 'Log In', appState),
          style: GoogleFonts.elMessiri(
            color: accentGold,
            fontSize: showLogo ? 26 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: showLogo ? 24 : 28),
        // Email
        _field(
          context: context,
          controller: _emailController,
          label: t('البريد الإلكتروني', 'Email', appState),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          surface: surface,
          primaryText: primaryText,
          secondaryText: secondaryText,
          borderColor: borderColor,
          accentGold: accentGold,
        ),
        const SizedBox(height: 15),
        // Password
        _passwordField(
          context: context,
          controller: _passwordController,
          label: t('كلمة المرور', 'Password', appState),
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          surface: surface,
          primaryText: primaryText,
          secondaryText: secondaryText,
          borderColor: borderColor,
          accentGold: accentGold,
        ),
        const SizedBox(height: 8),
        // Forgot Password
        Align(
          alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showForgotPasswordDialog(context),
            child: Text(
              t('نسيت كلمة المرور؟', 'Forgot Password?', appState),
              style: GoogleFonts.cairo(
                color: accentGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: showLogo ? 22 : 20),
        // Login Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient:
                LinearGradient(colors: [buttonGradient1, buttonGradient2]),
            boxShadow: [
              BoxShadow(
                color: (appState.isDarkMode ? goldBright : navy)
                    .withValues(alpha: 0.35),
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
                  borderRadius: BorderRadius.circular(26)),
            ),
            onPressed: _handleLogin,
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: buttonTextColor,
                    ),
                  )
                : Text(
                    t('تسجيل الدخول', 'Log In', appState),
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: buttonTextColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t('أو', 'OR', appState),
                style: GoogleFonts.cairo(
                  color: secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: borderColor)),
          ],
        ),
        const SizedBox(height: 18),
        // Google & Guest (side-by-side on web, stacked on mobile)
        if (!showLogo) ...[
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _handleLogin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('G',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent)),
                        const SizedBox(width: 8),
                        Text('Google',
                            style: GoogleFonts.cairo(
                                color: primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _handleGuest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline,
                            color: secondaryText, size: 18),
                        const SizedBox(width: 8),
                        Text(t('زائر', 'Guest', appState),
                            style: GoogleFonts.cairo(
                                color: primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
        ] else ...[
          // Mobile: stacked
          GestureDetector(
            onTap: _handleLogin,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('G',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                  const SizedBox(width: 10),
                  Text(
                    t('متابعة بحساب Google', 'Continue with Google', appState),
                    style: GoogleFonts.cairo(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleGuest,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, color: secondaryText, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    t('تصفح كزائر (بدون تسجيل)', 'Continue as Guest', appState),
                    style: GoogleFonts.cairo(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        // Sign up row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('ليس لديك حساب؟ ', 'Don\'t have an account? ', appState),
              style: GoogleFonts.cairo(
                color: secondaryText,
                fontSize: showLogo ? 14 : 13,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                );
              },
              child: Text(
                t('إنشاء حساب', 'Sign up', appState),
                style: GoogleFonts.cairo(
                  color: accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: showLogo ? 14 : 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────
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
    final topBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.18);
    final topBg = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final accentGold = isDarkMode ? goldBright : goldDark;
    final buttonGradient1 = isDarkMode ? goldBrightLight : navyLight;
    final buttonGradient2 = isDarkMode ? goldBright : navy;
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: accentGold),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: _topBarButton(
                icon: Icons.language,
                label: isArabic ? 'EN' : 'عربي',
                bg: topBg,
                iconColor: primaryText,
                borderColor: topBorder,
                onTap: () => appState.toggleLanguage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: _topBarButton(
                icon: isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: '',
                bg: topBg,
                iconColor: primaryText,
                borderColor: topBorder,
                onTap: () => appState.toggleTheme(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ── Web layout (>900px) ──────────────────────────────
              if (constraints.maxWidth > 900) {
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: Branding Showcase (larger)
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: isArabic ? 0 : 40,
                              left: isArabic ? 40 : 0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, child) {
                                    final dx = _shimmerController.value;
                                    return ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) {
                                        return LinearGradient(
                                          colors: logoShimmerColors(appState),
                                          stops: const [
                                            0.0,
                                            0.35,
                                            0.5,
                                            0.65,
                                            1.0
                                          ],
                                          begin: Alignment(-1.0 + dx * 3, -0.3),
                                          end: Alignment(1.0 + dx * 3, 0.3),
                                          tileMode: TileMode.clamp,
                                        ).createShader(bounds);
                                      },
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        height: 160,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'CraftGo',
                                  style: GoogleFonts.playfairDisplay(
                                    color: accentGold,
                                    fontSize: 44,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  t(
                                    'مرحباً بك مجدداً في منصة الحرف اليدوية الأولى. سجل دخولك للوصول لخدمات التخصيص والمتاجر.',
                                    'Welcome back to the premier craft platform. Log in to access custom orders and artisan stores.',
                                    appState,
                                  ),
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.shield_outlined,
                                          color: accentGold, size: 30),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          t(
                                            'تضمن منصة CraftGo حماية كاملة للمدفوعات وحسابات المستخدمين.',
                                            'CraftGo platform ensures end-to-end payment and user account protection.',
                                            appState,
                                          ),
                                          style: GoogleFonts.cairo(
                                            color: secondaryText,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    _featureBadge(
                                      icon: Icons.verified,
                                      label: t('موثوق', 'Verified', appState),
                                      accentGold: accentGold,
                                      secondaryText: secondaryText,
                                    ),
                                    const SizedBox(width: 16),
                                    _featureBadge(
                                      icon: Icons.security,
                                      label: t('آمن', 'Secure', appState),
                                      accentGold: accentGold,
                                      secondaryText: secondaryText,
                                    ),
                                    const SizedBox(width: 16),
                                    _featureBadge(
                                      icon: Icons.support_agent,
                                      label: t(
                                          'دعم 24/7', '24/7 Support', appState),
                                      accentGold: accentGold,
                                      secondaryText: secondaryText,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Right Column: Form Card (smaller)
                        Expanded(
                          flex: 4,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 480),
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildForm(
                                showLogo: false,
                                appState: appState,
                                accentGold: accentGold,
                                buttonGradient1: buttonGradient1,
                                buttonGradient2: buttonGradient2,
                                buttonTextColor: buttonTextColor,
                                surface: surface,
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                borderColor: borderColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // ── Mobile/Tablet layout (≤900px) ────────────────────
              return Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildForm(
                      showLogo: true,
                      appState: appState,
                      accentGold: accentGold,
                      buttonGradient1: buttonGradient1,
                      buttonGradient2: buttonGradient2,
                      buttonTextColor: buttonTextColor,
                      surface: surface,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      borderColor: borderColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _featureBadge({
    required IconData icon,
    required String label,
    required Color accentGold,
    required Color secondaryText,
  }) {
    return Row(
      children: [
        Icon(icon, color: accentGold, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Forgot Password Dialog ──────────────────────────────────────────────
  void _showForgotPasswordDialog(BuildContext context) {
    final appState = context.read<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final emailCtrl = TextEditingController();
    final accentGold = isDarkMode ? goldBright : goldDark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C2431) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            t('استعادة كلمة المرور', 'Reset Password', appState),
            style: GoogleFonts.cairo(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(
                  'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور.',
                  'Enter your email and we will send you a password reset link.',
                  appState,
                ),
                style: GoogleFonts.cairo(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.cairo(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: t('البريد الإلكتروني', 'Email', appState),
                  labelStyle: GoogleFonts.cairo(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  prefixIcon: Icon(Icons.email_outlined,
                      color: isDarkMode ? Colors.white54 : Colors.black45),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF0D1420)
                      : Colors.grey.shade100,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentGold, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                t('إلغاء', 'Cancel', appState),
                style: GoogleFonts.cairo(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      t('تم إرسال رابط الاستعادة إلى بريدك',
                          'Reset link sent to your email', appState),
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                );
              },
              child: Text(
                t('إرسال', 'Send', appState),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
    required Color accentGold,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.cairo(color: primaryText),
      keyboardType: keyboardType,
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
          borderSide: BorderSide(color: accentGold, width: 2),
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
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color borderColor,
    required Color accentGold,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.cairo(color: primaryText),
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
          borderSide: BorderSide(color: accentGold, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

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
