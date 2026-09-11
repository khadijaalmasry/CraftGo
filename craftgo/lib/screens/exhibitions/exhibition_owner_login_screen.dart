import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/exhibition_owner_shell.dart';
import '../../app_state.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/customer_login_screen.dart';

class ExhibitionOwnerLoginScreen extends StatefulWidget {
  const ExhibitionOwnerLoginScreen({super.key});

  @override
  State<ExhibitionOwnerLoginScreen> createState() =>
      _ExhibitionOwnerLoginScreenState();
}

class _ExhibitionOwnerLoginScreenState extends State<ExhibitionOwnerLoginScreen>
    with TickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _showAiPrediction = false;
  List<String> _aiNameSuggestions = [];
  bool _loadingNames = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _phoneController = TextEditingController();

  late AnimationController _entranceController;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  String? _exhibitionTypeSelection;
  final List<String> _exhibitionTypesAr = [
    'حرف تراثية',
    'مجوهرات',
    'خزف وفخار',
    'نسيج وتطريز',
    'خشبيات',
    'متعدد التخصصات'
  ];
  final List<String> _exhibitionTypesEn = [
    'Heritage Crafts',
    'Jewelry',
    'Ceramics & Pottery',
    'Textile & Embroidery',
    'Woodwork',
    'Multi-Specialty'
  ];

  String _predictedVisitors = '350–480';
  String _bestDay = '';
  String _trendingCraft = '';

  // ─── Logo Animation Controllers ──────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ─── Gold Colors (same as customer signup) ──────────────────────
  static const Color goldBright = Color(0xFFFFD700);
  static const Color goldBrightLight = Color(0xFFFFEC8B);
  static const Color goldDark = Color(0xFFB8860B);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _glowController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    // Logo animation
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
    _entranceController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String t(String ar, String en, AppState state) => state.isArabic ? ar : en;

  void _generateAiNames() async {
    final state = context.read<AppState>();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              t('أدخل اسم المنظم أولاً', 'Please enter organizer name first',
                  state),
              style: GoogleFonts.cairo()),
          backgroundColor: goldBright,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _loadingNames = true;
      _aiNameSuggestions = [];
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final name = _nameController.text.trim();
    setState(() {
      _loadingNames = false;
      _aiNameSuggestions = state.isArabic
          ? [
              'معرض $name للحرف الأصيلة',
              'إرث $name للإبداع اليدوي',
              'بصمة $name الحرفية',
            ]
          : [
              '$name Craft Heritage Fair',
              '$name Artisan Showcase',
              '$name Creative Hands Exhibition',
            ];
    });
  }

  void _handleSignup() async {
    final state = context.read<AppState>();

    // Basic validation
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('يرجى ملء جميع الحقول', 'Please fill all fields', state),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('كلمتا المرور غير متطابقتين', 'Passwords do not match', state),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_exhibitionTypeSelection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('يرجى اختيار تخصص المعرض', 'Please select exhibition specialty',
                state),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Map Arabic type to English for backend
    final selectedEn = _exhibitionTypesAr.contains(_exhibitionTypeSelection)
        ? _exhibitionTypesEn[
            _exhibitionTypesAr.indexOf(_exhibitionTypeSelection!)]
        : _exhibitionTypeSelection!;

    final user = await AuthService.signup(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      roles: ['exhibition_owner', 'customer'],
      city: 'Bethlehem', // default
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : '+970599000000',
      category: selectedEn,
      experienceYears: 5,
      bio: 'Exhibition Organizer',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('فشل إنشاء الحساب. قد يكون البريد مستخدماً.',
                'Signup failed. Email might be in use.', state),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generate AI predictions based on the selected type
    final idx = _exhibitionTypesAr.indexOf(_exhibitionTypeSelection!);
    final predictions = [
      {
        'visitors': '400–550',
        'day': t('الجمعة والسبت', 'Fri & Sat', state),
        'craft': t('حرف تراثية', 'Heritage Crafts', state)
      },
      {
        'visitors': '300–420',
        'day': t('نهاية الأسبوع', 'Weekend', state),
        'craft': t('مجوهرات', 'Jewelry', state)
      },
      {
        'visitors': '250–380',
        'day': t('السبت', 'Saturday', state),
        'craft': t('خزف', 'Ceramics', state)
      },
      {
        'visitors': '350–500',
        'day': t('الجمعة', 'Friday', state),
        'craft': t('تطريز', 'Embroidery', state)
      },
      {
        'visitors': '280–400',
        'day': t('نهاية الأسبوع', 'Weekend', state),
        'craft': t('خشبيات', 'Woodwork', state)
      },
      {
        'visitors': '450–650',
        'day': t('الجمعة والسبت', 'Fri & Sat', state),
        'craft': t('متعدد', 'Multi', state)
      },
    ];
    final pred = idx >= 0 && idx < predictions.length
        ? predictions[idx]
        : predictions[5];

    setState(() {
      _showAiPrediction = true;
      _predictedVisitors = pred['visitors']!;
      _bestDay = pred['day']!;
      _trendingCraft = pred['craft']!;
    });
  }

  void _proceedToDashboard() async {
    final state = context.read<AppState>();
    setState(() => _isLoading = true);

    final token = await SessionService.getToken() ?? '';
    final userId = state.userId ?? '';

    if (userId.isNotEmpty) {
      state.setAuth(
        userId: userId,
        userName: _nameController.text.trim(),
        token: token,
        roles: ['exhibition_owner', 'customer'],
      );
      state.setActiveRole('exhibition_owner');
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ExhibitionOwnerShell(
          ownerName: _nameController.text.trim(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final bgColor =
        isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
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
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: accentGold),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('بوابة صاحب المعرض', 'Exhibition Owner Portal', appState),
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
        body: Stack(
          children: [
            // // Subtle gold glow blobs (instead of purple)
            // Positioned(
            //   top: -100,
            //   right: -100,
            //   child: AnimatedBuilder(
            //     animation: _glowAnim,
            //     builder: (context, snapshot) => Opacity(
            //       opacity: _glowAnim.value * 0.08,
            //       child: Container(
            //         width: 350,
            //         height: 350,
            //         decoration: const BoxDecoration(
            //           shape: BoxShape.circle,
            //           color: goldBright,
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            // Positioned(
            //   bottom: -60,
            //   left: -60,
            //   child: Container(
            //     width: 250,
            //     height: 250,
            //     decoration: BoxDecoration(
            //       shape: BoxShape.circle,
            //       color: goldBright.withValues(alpha: 0.04),
            //     ),
            //   ),
            // ),

            SafeArea(
              child: _showAiPrediction
                  ? _buildAiPredictionScreen(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      child: FadeTransition(
                        opacity: _entranceController,
                        child: Column(
                          children: [
                            // ─── Animated Logo ────────────────────
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
                                              colors: shimmerColors,
                                              stops: const [
                                                0.0,
                                                0.35,
                                                0.5,
                                                0.65,
                                                1.0
                                              ],
                                              begin: Alignment(
                                                  -1.0 + dx * 3, -0.3),
                                              end: Alignment(1.0 + dx * 3, 0.3),
                                              tileMode: TileMode.clamp,
                                            ).createShader(bounds);
                                          },
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            height: 130,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ─── Title ────────────────────────────
                            Text(
                              t('انضم كصاحب معرض', 'Join as Exhibition Owner',
                                  appState),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: primaryText,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('نظام AI ذكي لإدارة معارضك',
                                  'AI-Powered Exhibition Management', appState),
                              style: GoogleFonts.cairo(
                                  color: goldBright, fontSize: 12),
                            ),
                            const SizedBox(height: 28),

                            // ─── Form (no frosted glass) ──────────
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Organizer name + AI button
                                _buildLabel(
                                    context,
                                    t('اسم المنظم / الشركة',
                                        'Organizer / Company Name', appState)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildField(
                                        context: context,
                                        controller: _nameController,
                                        hint: t(
                                            'مثال: مؤسسة إرث الأردن',
                                            'e.g. Jordan Heritage Foundation',
                                            appState),
                                        icon: Icons.business_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _generateAiNames,
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFF7B500),
                                              Color(0xFFD89A00)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                                color: goldBright.withValues(
                                                    alpha: 0.4),
                                                blurRadius: 12),
                                          ],
                                        ),
                                        child: _loadingNames
                                            ? const Center(
                                                child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white)))
                                            : const Icon(Icons.auto_awesome,
                                                color: Colors.white, size: 22),
                                      ),
                                    ),
                                  ],
                                ),

                                // AI name suggestions
                                if (_aiNameSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: goldBright.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: goldBright.withValues(
                                              alpha: 0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.auto_awesome,
                                                color: Color(0xFFFFD700),
                                                size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              t(
                                                  'اقتراحات AI لتسمية معرضك',
                                                  'AI Exhibition Name Suggestions',
                                                  appState),
                                              style: GoogleFonts.cairo(
                                                  color: goldBright,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ..._aiNameSuggestions.map((name) =>
                                            GestureDetector(
                                              onTap: () => setState(() {
                                                _nameController.text = name;
                                                _aiNameSuggestions = [];
                                              }),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 6),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDarkMode
                                                      ? const Color(0xFF1C2431)
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: borderColor),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.museum_outlined,
                                                        color:
                                                            Color(0xFFFFD700),
                                                        size: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style:
                                                            GoogleFonts.cairo(
                                                                color:
                                                                    primaryText,
                                                                fontSize: 13),
                                                      ),
                                                    ),
                                                    Icon(Icons.touch_app,
                                                        color: secondaryText,
                                                        size: 14),
                                                  ],
                                                ),
                                              ),
                                            )),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // License
                                _buildLabel(
                                    context,
                                    t(
                                        'رقم الرخصة / السجل التجاري',
                                        'License / Commercial Register No.',
                                        appState)),
                                const SizedBox(height: 8),
                                _buildField(
                                  context: context,
                                  controller: _licenseController,
                                  hint: t('مثال: JO-2024-78901',
                                      'e.g. JO-2024-78901', appState),
                                  icon: Icons.verified_outlined,
                                ),
                                const SizedBox(height: 14),

                                // Phone
                                _buildLabel(context,
                                    t('رقم الهاتف', 'Phone Number', appState)),
                                const SizedBox(height: 8),
                                _buildField(
                                  context: context,
                                  controller: _phoneController,
                                  hint: t('+962 7XXXXXXXX', '+962 7XXXXXXXX',
                                      appState),
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 14),

                                // Exhibition type dropdown
                                _buildLabel(
                                    context,
                                    t('تخصص المعرض', 'Exhibition Specialty',
                                        appState)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF1C2431)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _exhibitionTypeSelection,
                                      isExpanded: true,
                                      dropdownColor: isDarkMode
                                          ? const Color(0xFF1C2431)
                                          : Colors.white,
                                      hint: Text(
                                        t('اختر التخصص', 'Choose specialty',
                                            appState),
                                        style: GoogleFonts.cairo(
                                            color: secondaryText),
                                      ),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Color(0xFFFFD700)),
                                      items: (isArabic
                                              ? _exhibitionTypesAr
                                              : _exhibitionTypesEn)
                                          .map((type) {
                                        return DropdownMenuItem(
                                          value: type,
                                          child: Text(
                                            type,
                                            style: GoogleFonts.cairo(
                                                color: primaryText),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (v) => setState(
                                          () => _exhibitionTypeSelection = v),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Email
                                _buildLabel(
                                    context,
                                    t('البريد الإلكتروني', 'Email Address',
                                        appState)),
                                const SizedBox(height: 8),
                                _buildField(
                                  context: context,
                                  controller: _emailController,
                                  hint: t('example@gallery.com',
                                      'example@gallery.com', appState),
                                  icon: Icons.alternate_email,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),

                                // Password
                                _buildLabel(context,
                                    t('كلمة المرور', 'Password', appState)),
                                const SizedBox(height: 8),
                                _buildPasswordField(
                                  context: context,
                                  controller: _passwordController,
                                  obscure: _obscurePassword,
                                  onToggle: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                const SizedBox(height: 14),

                                // Confirm Password
                                _buildLabel(
                                    context,
                                    t('تأكيد كلمة المرور', 'Confirm Password',
                                        appState)),
                                const SizedBox(height: 8),
                                _buildPasswordField(
                                  context: context,
                                  controller: _confirmController,
                                  obscure: _obscureConfirm,
                                  onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),

                                const SizedBox(height: 24),

                                // Sign up button
                                Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF7B500),
                                        Color(0xFFD89A00)
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
                                              BorderRadius.circular(30)),
                                    ),
                                    onPressed:
                                        _isLoading ? null : _handleSignup,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black))
                                        : Text(
                                            t('إنشاء الحساب', 'Create Account',
                                                appState),
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
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ─── Already have an account? ──────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t('لديك حساب بالفعل؟ ',
                                      'Already have an account? ', appState),
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
                                        builder: (context) =>
                                            const CustomerLoginScreen(),
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
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AI Prediction Screen ──────────────────────────────────────────────

  Widget _buildAiPredictionScreen(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: goldBright.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: goldBright.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.psychology,
                color: Color(0xFFFFD700), size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            t('تم إنشاء حسابك بنجاح!', 'Account Created Successfully!',
                appState),
            style: GoogleFonts.cairo(
                color: primaryText, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            t(
                'إليك توقعات الذكاء الاصطناعي لمعرضك القادم',
                'Here are AI predictions for your upcoming exhibition',
                appState),
            style: GoogleFonts.cairo(color: secondaryText, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Prediction Cards (gold themed)
          _buildPredictionCard(
            context: context,
            icon: Icons.people_outline,
            title: t('الجمهور المتوقع', 'Predicted Audience', appState),
            value: _predictedVisitors,
            subtitle: t('زائر', 'visitors', appState),
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 14),
          _buildPredictionCard(
            context: context,
            icon: Icons.calendar_today_outlined,
            title: t('أفضل أيام المعرض', 'Best Exhibition Days', appState),
            value: _bestDay,
            subtitle: t('أعلى تفاعل', 'Peak engagement', appState),
            color: const Color(0xFFF7B500),
          ),
          const SizedBox(height: 14),
          _buildPredictionCard(
            context: context,
            icon: Icons.whatshot,
            title: t('الأعلى طلباً في منطقتك', 'Trending Craft in Your Area',
                appState),
            value: _trendingCraft,
            subtitle: t('+40% هذا الشهر', '+40% this month', appState),
            color: Colors.redAccent,
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Colors.green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(
                      'نصيحة AI: جهّز خصومات حصرية لأول 50 زائر لرفع التفاعل الاجتماعي بمعدل 3x',
                      'AI Tip: Prepare exclusive discounts for the first 50 visitors to boost social engagement by 3x',
                      appState,
                    ),
                    style: GoogleFonts.cairo(
                        color: Colors.green, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7B500).withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _proceedToDashboard,
              icon: const Icon(Icons.dashboard_outlined, color: Colors.black),
              label: Text(
                t('انطلق إلى لوحة التحكم', 'Go to Dashboard', appState),
                style: GoogleFonts.cairo(
                  color: isDarkMode ? Colors.black : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPredictionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.cairo(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style:
                        GoogleFonts.cairo(color: secondaryText, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper widgets ──────────────────────────────────────────────────────

  Widget _buildLabel(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.cairo(
            color: context.watch<AppState>().isDarkMode
                ? Colors.white70
                : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      );

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final primaryText = isDarkMode ? Colors.white : Colors.black87;
    final secondaryText = isDarkMode ? Colors.white70 : Colors.black54;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(color: primaryText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
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
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: GoogleFonts.cairo(color: secondaryText),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFFD700)),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: secondaryText,
              size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import '../../core/exhibition_owner_shell.dart';
// import '../../app_state.dart';
// import '../../services/auth_service.dart';
// import '../../services/session_service.dart';
// import '../../theme/app_palette.dart';

// class ExhibitionOwnerLoginScreen extends StatefulWidget {
//   const ExhibitionOwnerLoginScreen({super.key});

//   @override
//   State<ExhibitionOwnerLoginScreen> createState() =>
//       _ExhibitionOwnerLoginScreenState();
// }

// class _ExhibitionOwnerLoginScreenState extends State<ExhibitionOwnerLoginScreen>
//     with TickerProviderStateMixin {
//   bool _isLogin = true;
//   bool _obscurePassword = true;
//   bool _obscureConfirm = true;
//   bool _isLoading = false;
//   bool _showAiPrediction = false;
//   List<String> _aiNameSuggestions = [];
//   bool _loadingNames = false;

//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _confirmController = TextEditingController();
//   final _nameController = TextEditingController();
//   final _licenseController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _exhibitionTypeController = TextEditingController();

//   late AnimationController _entranceController;
//   late AnimationController _glowController;
//   late Animation<double> _glowAnim;

//   String? _exhibitionTypeSelection;
//   final List<String> _exhibitionTypesAr = [
//     'حرف تراثية',
//     'مجوهرات',
//     'خزف وفخار',
//     'نسيج وتطريز',
//     'خشبيات',
//     'متعدد التخصصات'
//   ];
//   final List<String> _exhibitionTypesEn = [
//     'Heritage Crafts',
//     'Jewelry',
//     'Ceramics & Pottery',
//     'Textile & Embroidery',
//     'Woodwork',
//     'Multi-Specialty'
//   ];

//   String _predictedVisitors = '350–480';
//   String _bestDay = '';
//   String _trendingCraft = '';

//   @override
//   void initState() {
//     super.initState();
//     _entranceController = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 900))
//       ..forward();
//     _glowController =
//         AnimationController(vsync: this, duration: const Duration(seconds: 2))
//           ..repeat(reverse: true);
//     _glowAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
//         CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _entranceController.dispose();
//     _glowController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _confirmController.dispose();
//     _nameController.dispose();
//     _licenseController.dispose();
//     _phoneController.dispose();
//     _exhibitionTypeController.dispose();
//     super.dispose();
//   }

//   String t(String ar, String en, AppState state) => state.isArabic ? ar : en;
//   Color bg(BuildContext context) =>
//       AppPalette.background(context.watch<AppState>().isDarkMode);
//   Color surface(BuildContext context) =>
//       AppPalette.inputBackground(context.watch<AppState>().isDarkMode);
//   Color surface2(BuildContext context) => context.watch<AppState>().isDarkMode
//       ? const Color(0xFF1C2640)
//       : const Color(0xFFF8F5FF);
//   Color primaryText(BuildContext context) =>
//       AppPalette.primaryText(context.watch<AppState>().isDarkMode);
//   Color secondaryText(BuildContext context) =>
//       AppPalette.secondaryText(context.watch<AppState>().isDarkMode);
//   Color borderColor(BuildContext context) =>
//       AppPalette.borderColor(context.watch<AppState>().isDarkMode);
//   static const Color exAccent = Color(0xFF7B5EA7);

//   void _generateAiNames() async {
//     final state = context.read<AppState>();
//     if (_nameController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               t('أدخل اسم المنظم أولاً', 'Please enter organizer name first',
//                   state),
//               style: GoogleFonts.cairo()),
//           backgroundColor: exAccent,
//           behavior: SnackBarBehavior.floating,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         ),
//       );
//       return;
//     }
//     setState(() {
//       _loadingNames = true;
//       _aiNameSuggestions = [];
//     });
//     await Future.delayed(const Duration(seconds: 2));
//     if (!mounted) return;
//     final name = _nameController.text.trim();
//     setState(() {
//       _loadingNames = false;
//       _aiNameSuggestions = state.isArabic
//           ? [
//               'معرض $name للحرف الأصيلة',
//               'إرث $name للإبداع اليدوي',
//               'بصمة $name الحرفية',
//             ]
//           : [
//               '$name Craft Heritage Fair',
//               '$name Artisan Showcase',
//               '$name Creative Hands Exhibition',
//             ];
//     });
//   }

//   void _handleSubmit() async {
//     final state = context.read<AppState>();
//     setState(() {
//       _isLoading = true;
//     });

//     if (!_isLogin) {
//       final idx = _exhibitionTypesAr.indexOf(_exhibitionTypeSelection ?? '');
//       final predictions = [
//         {
//           'visitors': '400–550',
//           'day': t('الجمعة والسبت', 'Fri & Sat', state),
//           'craft': t('حرف تراثية', 'Heritage Crafts', state)
//         },
//         {
//           'visitors': '300–420',
//           'day': t('نهاية الأسبوع', 'Weekend', state),
//           'craft': t('مجوهرات', 'Jewelry', state)
//         },
//         {
//           'visitors': '250–380',
//           'day': t('السبت', 'Saturday', state),
//           'craft': t('خزف', 'Ceramics', state)
//         },
//         {
//           'visitors': '350–500',
//           'day': t('الجمعة', 'Friday', state),
//           'craft': t('تطريز', 'Embroidery', state)
//         },
//         {
//           'visitors': '280–400',
//           'day': t('نهاية الأسبوع', 'Weekend', state),
//           'craft': t('خشبيات', 'Woodwork', state)
//         },
//         {
//           'visitors': '450–650',
//           'day': t('الجمعة والسبت', 'Fri & Sat', state),
//           'craft': t('متعدد', 'Multi', state)
//         },
//       ];
//       final pred = idx >= 0 && idx < predictions.length
//           ? predictions[idx]
//           : predictions[5];
//       setState(() {
//         _isLoading = false;
//         _showAiPrediction = true;
//         _predictedVisitors = pred['visitors']!;
//         _bestDay = pred['day']!;
//         _trendingCraft = pred['craft']!;
//       });
//     } else {
//       final email = _emailController.text.trim().isNotEmpty
//           ? _emailController.text.trim()
//           : 'exhibition@craftgo.com';
//       final password = _passwordController.text.isNotEmpty
//           ? _passwordController.text
//           : '123456';

//       final user = await AuthService.login(email, password);
//       if (!mounted) return;

//       setState(() {
//         _isLoading = false;
//       });

//       if (!mounted) return;
//       if (user != null) {
//         final roles = List<String>.from(
//             user['roles'] ?? ['exhibition_owner', 'customer']);
//         final token = await SessionService.getToken() ?? '';
//         if (!mounted) return;
//         state.setAuth(
//           userId: user['id']?.toString() ?? '',
//           userName: user['name'] ?? '',
//           token: token,
//           roles: roles,
//         );
//         state.setActiveRole('exhibition_owner');
//         final ownerN = user['name'] ??
//             (_nameController.text.isNotEmpty
//                 ? _nameController.text
//                 : (state.isArabic
//                     ? 'بيت لحم للفنون'
//                     : 'Beit Jala Arts Center'));
//         if (!mounted) return;
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(
//             builder: (_) => ExhibitionOwnerShell(ownerName: ownerN),
//           ),
//           (route) => false,
//         );
//       } else {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               t('فشل تسجيل الدخول. يرجى التحقق من البيانات',
//                   'Login failed. Please check credentials', state),
//               style: GoogleFonts.cairo(),
//             ),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   void _proceedToDashboard() async {
//     final state = context.read<AppState>();
//     setState(() {
//       _isLoading = true;
//     });

//     final name = _nameController.text.trim().isNotEmpty
//         ? _nameController.text.trim()
//         : 'Beit Jala Arts Center';
//     final email = _emailController.text.trim().isNotEmpty
//         ? _emailController.text.trim()
//         : 'exhibition_${DateTime.now().millisecondsSinceEpoch}@craftgo.com';
//     final password = _passwordController.text.isNotEmpty
//         ? _passwordController.text
//         : '123456';

//     final user = await AuthService.signup(
//       name: name,
//       email: email,
//       password: password,
//       roles: ['exhibition_owner', 'customer'],
//       city: 'Bethlehem',
//       phone: _phoneController.text.trim().isNotEmpty
//           ? _phoneController.text.trim()
//           : '+970599000000',
//       category: _exhibitionTypeSelection ?? 'Heritage Crafts',
//       experienceYears: 5,
//       bio: 'Exhibition Organizer',
//     );

//     if (!mounted) return;
//     setState(() {
//       _isLoading = false;
//     });

//     final ownerName = user != null ? (user['name'] ?? name) : name;
//     if (user != null) {
//       final token = await SessionService.getToken() ?? '';
//       if (!mounted) return;
//       state.setAuth(
//         userId: user['id']?.toString() ?? '',
//         userName: ownerName,
//         token: token,
//         roles: ['exhibition_owner', 'customer'],
//       );
//       state.setActiveRole('exhibition_owner');
//     }

//     if (!mounted) return;
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ExhibitionOwnerShell(
//           ownerName: ownerName,
//         ),
//       ),
//       (route) => false,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = context.watch<AppState>();
//     final isArabic = appState.isArabic;
//     final isDarkMode = appState.isDarkMode;

//     return Directionality(
//       textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg(context),
//         body: Stack(
//           children: [
//             // Gradient background
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: isDarkMode
//                         ? [
//                             const Color(0xFF0A0F1E),
//                             const Color(0xFF130D22),
//                             const Color(0xFF0A0F1E)
//                           ]
//                         : [
//                             const Color(0xFFF5F0FF),
//                             const Color(0xFFFDF9FF),
//                             const Color(0xFFF5F0FF)
//                           ],
//                   ),
//                 ),
//               ),
//             ),
//             // Glow blobs
//             Positioned(
//               top: -100,
//               right: -100,
//               child: AnimatedBuilder(
//                 animation: _glowAnim,
//                 builder: (context, snapshot) => Opacity(
//                   opacity: _glowAnim.value * 0.15,
//                   child: Container(
//                     width: 350,
//                     height: 350,
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: exAccent,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Positioned(
//               bottom: -60,
//               left: -60,
//               child: Container(
//                 width: 250,
//                 height: 250,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: exAccent.withValues(alpha: 0.06),
//                 ),
//               ),
//             ),

//             SafeArea(
//               child: _showAiPrediction
//                   ? _buildAiPredictionScreen(context)
//                   : SingleChildScrollView(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 24, vertical: 16),
//                       child: FadeTransition(
//                         opacity: _entranceController,
//                         child: Column(
//                           children: [
//                             // Top bar
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 _topBtn(
//                                   context: context,
//                                   icon: isArabic
//                                       ? Icons.arrow_forward_ios
//                                       : Icons.arrow_back_ios,
//                                   onTap: () => Navigator.pop(context),
//                                 ),
//                                 Row(
//                                   children: [
//                                     _topBtn(
//                                       context: context,
//                                       icon: Icons.language,
//                                       label: isArabic ? 'EN' : 'عربي',
//                                       onTap: () => appState.toggleLanguage(),
//                                     ),
//                                     const SizedBox(width: 8),
//                                     _topBtn(
//                                       context: context,
//                                       icon: isDarkMode
//                                           ? Icons.light_mode_outlined
//                                           : Icons.dark_mode_outlined,
//                                       onTap: () => appState.toggleTheme(),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 28),

//                             // Logo
//                             AnimatedBuilder(
//                               animation: _glowAnim,
//                               builder: (context, snapshot) => Container(
//                                 width: 88,
//                                 height: 88,
//                                 decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   gradient: const LinearGradient(
//                                     colors: [Color(0xFF9B73D1), exAccent],
//                                   ),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: exAccent.withValues(
//                                           alpha: _glowAnim.value * 0.55),
//                                       blurRadius: 28,
//                                       spreadRadius: 4,
//                                     ),
//                                   ],
//                                 ),
//                                 child: const Icon(Icons.museum,
//                                     color: Colors.white, size: 42),
//                               ),
//                             ),
//                             const SizedBox(height: 18),

//                             Text(
//                               t('بوابة صاحب المعرض', 'Exhibition Owner Portal',
//                                   appState),
//                               style: GoogleFonts.cairo(
//                                 color: primaryText(context),
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               t('نظام AI ذكي لإدارة معارضك',
//                                   'AI-Powered Exhibition Management', appState),
//                               style: GoogleFonts.cairo(
//                                   color: exAccent, fontSize: 12),
//                             ),
//                             const SizedBox(height: 28),

//                             // Login / Register tabs
//                             Container(
//                               padding: const EdgeInsets.all(4),
//                               decoration: BoxDecoration(
//                                 color: surface(context),
//                                 borderRadius: BorderRadius.circular(30),
//                                 border: Border.all(color: borderColor(context)),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Expanded(
//                                       child: _buildTab(
//                                           context,
//                                           t('تسجيل الدخول', 'Login', appState),
//                                           _isLogin,
//                                           () =>
//                                               setState(() => _isLogin = true))),
//                                   Expanded(
//                                       child: _buildTab(
//                                           context,
//                                           t('حساب جديد', 'Sign Up', appState),
//                                           !_isLogin,
//                                           () => setState(
//                                               () => _isLogin = false))),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 24),

//                             // Form
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(24),
//                               child: BackdropFilter(
//                                 filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
//                                 child: Container(
//                                   padding: const EdgeInsets.all(22),
//                                   decoration: BoxDecoration(
//                                     color: surface(context)
//                                         .withValues(alpha: 0.88),
//                                     borderRadius: BorderRadius.circular(24),
//                                     border: Border.all(
//                                         color:
//                                             exAccent.withValues(alpha: 0.25)),
//                                   ),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       if (!_isLogin) ...[
//                                         // Organizer name + AI button
//                                         _buildLabel(
//                                             context,
//                                             t(
//                                                 'اسم المنظم / الشركة',
//                                                 'Organizer / Company Name',
//                                                 appState)),
//                                         const SizedBox(height: 8),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: _buildField(
//                                                 context: context,
//                                                 controller: _nameController,
//                                                 hint: t(
//                                                     'مثال: مؤسسة إرث الأردن',
//                                                     'e.g. Jordan Heritage Foundation',
//                                                     appState),
//                                                 icon: Icons.business_outlined,
//                                               ),
//                                             ),
//                                             const SizedBox(width: 10),
//                                             GestureDetector(
//                                               onTap: _generateAiNames,
//                                               child: Container(
//                                                 width: 52,
//                                                 height: 52,
//                                                 decoration: BoxDecoration(
//                                                   color: exAccent,
//                                                   borderRadius:
//                                                       BorderRadius.circular(14),
//                                                   boxShadow: [
//                                                     BoxShadow(
//                                                         color:
//                                                             exAccent.withValues(
//                                                                 alpha: 0.4),
//                                                         blurRadius: 12),
//                                                   ],
//                                                 ),
//                                                 child: _loadingNames
//                                                     ? const Center(
//                                                         child: SizedBox(
//                                                             width: 18,
//                                                             height: 18,
//                                                             child:
//                                                                 CircularProgressIndicator(
//                                                                     strokeWidth:
//                                                                         2,
//                                                                     color: Colors
//                                                                         .white)))
//                                                     : const Icon(
//                                                         Icons.auto_awesome,
//                                                         color: Colors.white,
//                                                         size: 22),
//                                               ),
//                                             ),
//                                           ],
//                                         ),

//                                         // AI name suggestions
//                                         if (_aiNameSuggestions.isNotEmpty) ...[
//                                           const SizedBox(height: 10),
//                                           Container(
//                                             padding: const EdgeInsets.all(12),
//                                             decoration: BoxDecoration(
//                                               color: exAccent.withValues(
//                                                   alpha: 0.08),
//                                               borderRadius:
//                                                   BorderRadius.circular(14),
//                                               border: Border.all(
//                                                   color: exAccent.withValues(
//                                                       alpha: 0.3)),
//                                             ),
//                                             child: Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Row(
//                                                   children: [
//                                                     const Icon(
//                                                         Icons.auto_awesome,
//                                                         color: exAccent,
//                                                         size: 14),
//                                                     const SizedBox(width: 6),
//                                                     Text(
//                                                       t(
//                                                           'اقتراحات AI لتسمية معرضك',
//                                                           'AI Exhibition Name Suggestions',
//                                                           appState),
//                                                       style: GoogleFonts.cairo(
//                                                           color: exAccent,
//                                                           fontSize: 12,
//                                                           fontWeight:
//                                                               FontWeight.bold),
//                                                     ),
//                                                   ],
//                                                 ),
//                                                 const SizedBox(height: 8),
//                                                 ..._aiNameSuggestions.map(
//                                                     (name) => GestureDetector(
//                                                           onTap: () =>
//                                                               setState(() {
//                                                             _nameController
//                                                                 .text = name;
//                                                             _aiNameSuggestions =
//                                                                 [];
//                                                           }),
//                                                           child: Container(
//                                                             margin:
//                                                                 const EdgeInsets
//                                                                     .only(
//                                                                     bottom: 6),
//                                                             padding:
//                                                                 const EdgeInsets
//                                                                     .symmetric(
//                                                                     horizontal:
//                                                                         12,
//                                                                     vertical:
//                                                                         8),
//                                                             decoration:
//                                                                 BoxDecoration(
//                                                               color: surface2(
//                                                                   context),
//                                                               borderRadius:
//                                                                   BorderRadius
//                                                                       .circular(
//                                                                           10),
//                                                               border: Border.all(
//                                                                   color: borderColor(
//                                                                       context)),
//                                                             ),
//                                                             child: Row(
//                                                               children: [
//                                                                 const Icon(
//                                                                     Icons
//                                                                         .museum_outlined,
//                                                                     color:
//                                                                         exAccent,
//                                                                     size: 16),
//                                                                 const SizedBox(
//                                                                     width: 8),
//                                                                 Expanded(
//                                                                   child: Text(
//                                                                     name,
//                                                                     style: GoogleFonts.cairo(
//                                                                         color: primaryText(
//                                                                             context),
//                                                                         fontSize:
//                                                                             13),
//                                                                   ),
//                                                                 ),
//                                                                 Icon(
//                                                                     Icons
//                                                                         .touch_app,
//                                                                     color: secondaryText(
//                                                                         context),
//                                                                     size: 14),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                         )),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                         const SizedBox(height: 14),

//                                         // License
//                                         _buildLabel(
//                                             context,
//                                             t(
//                                                 'رقم الرخصة / السجل التجاري',
//                                                 'License / Commercial Register No.',
//                                                 appState)),
//                                         const SizedBox(height: 8),
//                                         _buildField(
//                                           context: context,
//                                           controller: _licenseController,
//                                           hint: t('مثال: JO-2024-78901',
//                                               'e.g. JO-2024-78901', appState),
//                                           icon: Icons.verified_outlined,
//                                         ),
//                                         const SizedBox(height: 14),

//                                         // Phone
//                                         _buildLabel(
//                                             context,
//                                             t('رقم الهاتف', 'Phone Number',
//                                                 appState)),
//                                         const SizedBox(height: 8),
//                                         _buildField(
//                                           context: context,
//                                           controller: _phoneController,
//                                           hint: t('+962 7XXXXXXXX',
//                                               '+962 7XXXXXXXX', appState),
//                                           icon: Icons.phone_outlined,
//                                           keyboardType: TextInputType.phone,
//                                         ),
//                                         const SizedBox(height: 14),

//                                         // Exhibition type dropdown
//                                         _buildLabel(
//                                             context,
//                                             t(
//                                                 'تخصص المعرض',
//                                                 'Exhibition Specialty',
//                                                 appState)),
//                                         const SizedBox(height: 8),
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(
//                                               horizontal: 16),
//                                           decoration: BoxDecoration(
//                                             color: surface2(context),
//                                             borderRadius:
//                                                 BorderRadius.circular(14),
//                                             border: Border.all(
//                                                 color: borderColor(context)),
//                                           ),
//                                           child: DropdownButtonHideUnderline(
//                                             child: DropdownButton<String>(
//                                               value: _exhibitionTypeSelection,
//                                               isExpanded: true,
//                                               dropdownColor: surface(context),
//                                               hint: Text(
//                                                 t(
//                                                     'اختر التخصص',
//                                                     'Choose specialty',
//                                                     appState),
//                                                 style: GoogleFonts.cairo(
//                                                     color:
//                                                         secondaryText(context)),
//                                               ),
//                                               icon: const Icon(
//                                                   Icons.keyboard_arrow_down,
//                                                   color: exAccent),
//                                               items: (isArabic
//                                                       ? _exhibitionTypesAr
//                                                       : _exhibitionTypesEn)
//                                                   .map((type) {
//                                                 return DropdownMenuItem(
//                                                   value: type,
//                                                   child: Text(type,
//                                                       style: GoogleFonts.cairo(
//                                                           color: primaryText(
//                                                               context))),
//                                                 );
//                                               }).toList(),
//                                               onChanged: (v) => setState(() =>
//                                                   _exhibitionTypeSelection = v),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(height: 14),
//                                       ],

//                                       // Email
//                                       _buildLabel(
//                                           context,
//                                           t('البريد الإلكتروني',
//                                               'Email Address', appState)),
//                                       const SizedBox(height: 8),
//                                       _buildField(
//                                         context: context,
//                                         controller: _emailController,
//                                         hint: t('example@gallery.com',
//                                             'example@gallery.com', appState),
//                                         icon: Icons.alternate_email,
//                                         keyboardType:
//                                             TextInputType.emailAddress,
//                                       ),
//                                       const SizedBox(height: 14),

//                                       // Password
//                                       _buildLabel(
//                                           context,
//                                           t('كلمة المرور', 'Password',
//                                               appState)),
//                                       const SizedBox(height: 8),
//                                       _buildPasswordField(
//                                         context: context,
//                                         controller: _passwordController,
//                                         obscure: _obscurePassword,
//                                         onToggle: () => setState(() =>
//                                             _obscurePassword =
//                                                 !_obscurePassword),
//                                       ),

//                                       if (!_isLogin) ...[
//                                         const SizedBox(height: 14),
//                                         _buildLabel(
//                                             context,
//                                             t('تأكيد كلمة المرور',
//                                                 'Confirm Password', appState)),
//                                         const SizedBox(height: 8),
//                                         _buildPasswordField(
//                                           context: context,
//                                           controller: _confirmController,
//                                           obscure: _obscureConfirm,
//                                           onToggle: () => setState(() =>
//                                               _obscureConfirm =
//                                                   !_obscureConfirm),
//                                         ),
//                                       ],

//                                       const SizedBox(height: 24),

//                                       SizedBox(
//                                         width: double.infinity,
//                                         height: 54,
//                                         child: ElevatedButton(
//                                           onPressed:
//                                               _isLoading ? null : _handleSubmit,
//                                           style: ElevatedButton.styleFrom(
//                                             backgroundColor: exAccent,
//                                             shape: RoundedRectangleBorder(
//                                                 borderRadius:
//                                                     BorderRadius.circular(16)),
//                                             elevation: 0,
//                                           ),
//                                           child: _isLoading
//                                               ? Row(
//                                                   mainAxisAlignment:
//                                                       MainAxisAlignment.center,
//                                                   children: [
//                                                     const SizedBox(
//                                                         width: 20,
//                                                         height: 20,
//                                                         child:
//                                                             CircularProgressIndicator(
//                                                                 strokeWidth: 2,
//                                                                 color: Colors
//                                                                     .white)),
//                                                     const SizedBox(width: 12),
//                                                     Text(
//                                                       t(
//                                                           'AI يحلل معرضك...',
//                                                           'AI analyzing your exhibition...',
//                                                           appState),
//                                                       style: GoogleFonts.cairo(
//                                                           color: Colors.white,
//                                                           fontWeight:
//                                                               FontWeight.bold),
//                                                     ),
//                                                   ],
//                                                 )
//                                               : Text(
//                                                   _isLogin
//                                                       ? t('تسجيل الدخول',
//                                                           'Login', appState)
//                                                       : t(
//                                                           'إنشاء الحساب + توقعات AI',
//                                                           'Create Account + AI Forecast',
//                                                           appState),
//                                                   style: GoogleFonts.cairo(
//                                                       color: Colors.white,
//                                                       fontSize: 15,
//                                                       fontWeight:
//                                                           FontWeight.bold),
//                                                 ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 32),
//                           ],
//                         ),
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAiPredictionScreen(BuildContext context) {
//     final appState = context.watch<AppState>();
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           const SizedBox(height: 20),
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: exAccent.withValues(alpha: 0.15),
//               shape: BoxShape.circle,
//               border: Border.all(color: exAccent.withValues(alpha: 0.4)),
//             ),
//             child: const Icon(Icons.psychology, color: exAccent, size: 48),
//           ),
//           const SizedBox(height: 20),
//           Text(
//             t('تم إنشاء حسابك بنجاح!', 'Account Created Successfully!',
//                 appState),
//             style: GoogleFonts.cairo(
//                 color: primaryText(context),
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 6),
//           Text(
//             t(
//                 'إليك توقعات الذكاء الاصطناعي لمعرضك القادم',
//                 'Here are AI predictions for your upcoming exhibition',
//                 appState),
//             style:
//                 GoogleFonts.cairo(color: secondaryText(context), fontSize: 13),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 32),

//           // Prediction Cards
//           _buildPredictionCard(
//             context: context,
//             icon: Icons.people_outline,
//             title: t('الجمهور المتوقع', 'Predicted Audience', appState),
//             value: _predictedVisitors,
//             subtitle: t('زائر', 'visitors', appState),
//             color: exAccent,
//           ),
//           const SizedBox(height: 14),
//           _buildPredictionCard(
//             context: context,
//             icon: Icons.calendar_today_outlined,
//             title: t('أفضل أيام المعرض', 'Best Exhibition Days', appState),
//             value: _bestDay,
//             subtitle: t('أعلى تفاعل', 'Peak engagement', appState),
//             color: const Color(0xFFD4A017),
//           ),
//           const SizedBox(height: 14),
//           _buildPredictionCard(
//             context: context,
//             icon: Icons.whatshot,
//             title: t('الأعلى طلباً في منطقتك', 'Trending Craft in Your Area',
//                 appState),
//             value: _trendingCraft,
//             subtitle: t('+40% هذا الشهر', '+40% this month', appState),
//             color: Colors.redAccent,
//           ),
//           const SizedBox(height: 32),

//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.green.withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.lightbulb_outline,
//                     color: Colors.green, size: 22),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     t(
//                       'نصيحة AI: جهّز خصومات حصرية لأول 50 زائر لرفع التفاعل الاجتماعي بمعدل 3x',
//                       'AI Tip: Prepare exclusive discounts for the first 50 visitors to boost social engagement by 3x',
//                       appState,
//                     ),
//                     style: GoogleFonts.cairo(
//                         color: Colors.green, fontSize: 12, height: 1.5),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 28),

//           SizedBox(
//             width: double.infinity,
//             height: 54,
//             child: ElevatedButton.icon(
//               onPressed: _proceedToDashboard,
//               icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
//               label: Text(
//                 t('انطلق إلى لوحة التحكم', 'Go to Dashboard', appState),
//                 style: GoogleFonts.cairo(
//                     color: Colors.white,
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: exAccent,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16)),
//                 elevation: 0,
//               ),
//             ),
//           ),
//           const SizedBox(height: 32),
//         ],
//       ),
//     );
//   }

//   Widget _buildPredictionCard({
//     required BuildContext context,
//     required IconData icon,
//     required String title,
//     required String value,
//     required String subtitle,
//     required Color color,
//   }) {
//     final appState = context.watch<AppState>();
//     final surface =
//         appState.isDarkMode ? const Color(0xFF131929) : Colors.white;
//     final secondaryText = appState.isDarkMode ? Colors.white60 : Colors.black45;
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: color.withValues(alpha: 0.25)),
//         boxShadow: [
//           BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12)
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: color.withValues(alpha: 0.12),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: Icon(icon, color: color, size: 26),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(title,
//                     style: GoogleFonts.cairo(
//                         color: secondaryText,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600)),
//                 const SizedBox(height: 2),
//                 Text(value,
//                     style: GoogleFonts.cairo(
//                         color: color,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold)),
//                 Text(subtitle,
//                     style:
//                         GoogleFonts.cairo(color: secondaryText, fontSize: 11)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTab(
//       BuildContext context, String label, bool selected, VoidCallback onTap) {
//     final appState = context.watch<AppState>();
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         decoration: BoxDecoration(
//           color: selected ? exAccent : Colors.transparent,
//           borderRadius: BorderRadius.circular(26),
//         ),
//         child: Text(
//           label,
//           textAlign: TextAlign.center,
//           style: GoogleFonts.cairo(
//             color: selected ? Colors.white : secondaryText(context),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLabel(BuildContext context, String text) => Text(
//         text,
//         style: GoogleFonts.cairo(
//             color: secondaryText(context),
//             fontSize: 13,
//             fontWeight: FontWeight.w600),
//       );

//   Widget _buildField({
//     required BuildContext context,
//     required TextEditingController controller,
//     required String hint,
//     required IconData icon,
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     final appState = context.watch<AppState>();
//     final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
//     final secondaryText = appState.isDarkMode ? Colors.white60 : Colors.black45;
//     final borderColor = appState.isDarkMode
//         ? Colors.white.withValues(alpha: 0.1)
//         : Colors.black.withValues(alpha: 0.08);
//     final surface2 =
//         appState.isDarkMode ? const Color(0xFF1C2640) : const Color(0xFFF8F5FF);

//     return TextField(
//       controller: controller,
//       keyboardType: keyboardType,
//       style: GoogleFonts.cairo(color: primaryText),
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: GoogleFonts.cairo(color: secondaryText),
//         prefixIcon: Icon(icon, color: exAccent, size: 20),
//         filled: true,
//         fillColor: surface2,
//         border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: borderColor)),
//         enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: borderColor)),
//         focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: const BorderSide(color: exAccent, width: 1.5)),
//         contentPadding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       ),
//     );
//   }

//   Widget _buildPasswordField({
//     required BuildContext context,
//     required TextEditingController controller,
//     required bool obscure,
//     required VoidCallback onToggle,
//   }) {
//     final appState = context.watch<AppState>();
//     final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
//     final secondaryText = appState.isDarkMode ? Colors.white60 : Colors.black45;
//     final borderColor = appState.isDarkMode
//         ? Colors.white.withValues(alpha: 0.1)
//         : Colors.black.withValues(alpha: 0.08);
//     final surface2 =
//         appState.isDarkMode ? const Color(0xFF1C2640) : const Color(0xFFF8F5FF);

//     return TextField(
//       controller: controller,
//       obscureText: obscure,
//       style: GoogleFonts.cairo(color: primaryText),
//       decoration: InputDecoration(
//         hintText: '••••••••',
//         hintStyle: GoogleFonts.cairo(color: secondaryText),
//         prefixIcon: const Icon(Icons.lock_outline, color: exAccent, size: 20),
//         suffixIcon: IconButton(
//           icon: Icon(
//               obscure
//                   ? Icons.visibility_off_outlined
//                   : Icons.visibility_outlined,
//               color: secondaryText,
//               size: 20),
//           onPressed: onToggle,
//         ),
//         filled: true,
//         fillColor: surface2,
//         border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: borderColor)),
//         enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: borderColor)),
//         focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: const BorderSide(color: exAccent, width: 1.5)),
//         contentPadding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       ),
//     );
//   }

//   Widget _topBtn({
//     required BuildContext context,
//     required IconData icon,
//     String? label,
//     required VoidCallback onTap,
//   }) {
//     final appState = context.watch<AppState>();
//     final primaryText = appState.isDarkMode ? Colors.white : Colors.black87;
//     final surface =
//         appState.isDarkMode ? const Color(0xFF131929) : Colors.white;
//     final borderColor = appState.isDarkMode
//         ? Colors.white.withValues(alpha: 0.1)
//         : Colors.black.withValues(alpha: 0.08);

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(
//             horizontal: label != null ? 12 : 10, vertical: 8),
//         decoration: BoxDecoration(
//           color: surface,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: borderColor),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 16, color: primaryText),
//             if (label != null) ...[
//               const SizedBox(width: 6),
//               Text(label,
//                   style: GoogleFonts.cairo(
//                       color: primaryText,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600)),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
