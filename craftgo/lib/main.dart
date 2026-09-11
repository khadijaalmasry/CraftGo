import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/role_selection_screen.dart';
import 'screens/custom_order/custom_order_provider.dart';
import 'screens/hire_order/hire_order_provider.dart';
import 'app_state.dart';
import 'widgets/customer_login_screen.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ar');

  final appState = AppState();

  // Load session first
  await appState.loadSession();

  // Check if theme was already saved; if not, use system theme
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('settings_is_dark_mode')) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    appState.setTheme(isDark);
    await SessionService.saveSettings(
      isArabic: appState.isArabic,
      isDarkMode: isDark,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => CustomOrderProvider()),
        ChangeNotifierProvider(create: (_) => HireOrderProvider()),
      ],
      child: const CraftGoApp(),
    ),
  );
}

class CraftGoApp extends StatelessWidget {
  const CraftGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We’ll use a Consumer to listen to AppState changes
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CraftGo',
          theme: ThemeData(
            scaffoldBackgroundColor: appState.isDarkMode
                ? const Color(0xFF0D1420)
                : const Color(0xFFF5F6F8),
            useMaterial3: true,
          ),
          // 🚀 Dynamically decide the initial route
          home: appState.isLoggedIn
              ? appState.getShellForActiveRole()
              : const OnboardingScreen(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const CustomerLoginScreen(),
            '/roleSelection': (context) => const RoleSelectionScreen(),
          },
        );
      },
    );
  }
}

// ==============================================================
// OnboardingScreen – Gold/Navy Theme with 5-Image Collage
// ==============================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late PageController _carouselController;
  int _carouselPage = 0;

  static const List<String> _carouselImages = [
    'assets/images/plate.jpg',
    'assets/images/pottery.jpg',
    'assets/images/jewelry.jpg',
    'assets/images/basket.jpg',
    'assets/images/crochet.jpg',
  ];

  static const List<String> _carouselLabels = [
    'Ceramics & Plates',
    'Pottery',
    'Jewelry',
    'Woven Baskets',
    'Crochet & Textiles',
  ];

  // ── Gold/Navy Theme Colors ──────────────────────────────────────
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
    _carouselController =
        PageController(viewportFraction: 0.72, initialPage: 1000);
    _carouselPage = 0;
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final next = _carouselController.page != null
          ? (_carouselController.page!.round() + 1)
          : 1001;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
      _startCarouselTimer();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  // ── Theme-aware getters ────────────────────────────────────────
  Color backgroundColor(AppState state) =>
      state.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color primaryTextColor(AppState state) =>
      state.isDarkMode ? Colors.white : Colors.black87;

  Color secondaryTextColor(AppState state) =>
      state.isDarkMode ? Colors.white70 : Colors.black54;

  Color topButtonBackground(AppState state) =>
      state.isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color topIconColor(AppState state) =>
      state.isDarkMode ? Colors.white : Colors.black87;

  Color chipBorderColor(AppState state) =>
      state.isDarkMode ? Colors.white12 : Colors.black12;

  Color cardBorderColor(AppState state) =>
      state.isDarkMode ? Colors.white24 : Colors.black26;

  // Login button: outlined with navy in light mode, gold in dark mode
  Color loginButtonColor(AppState state) =>
      state.isDarkMode ? goldBright : navy;

  // Sign-up button gradient: gold gradient in dark mode, navy gradient in light mode
  List<Color> signUpGradient(AppState state) =>
      state.isDarkMode ? [goldBrightLight, goldBright] : [navyLight, navy];

  Color signUpTextColor_(AppState state) =>
      state.isDarkMode ? Colors.black : Colors.white;

  // Logo shimmer: gold tones for dark mode, navy/gold for light mode
  List<Color> logoShimmerColors(AppState state) => state.isDarkMode
      ? [goldBright, goldBrightLight, Colors.white, goldBrightLight, goldBright]
      : [goldDark, goldBright, Colors.white, goldBright, goldDark];

  // Feature chips accent color: gold in dark mode, navy in light mode
  Color chipIconColor(AppState state) => state.isDarkMode ? goldBright : navy;

  String titleText(AppState state) =>
      state.isArabic ? "فن حقيقي بأيد موثوقة" : "Real Craft, Trusted Hands";

  String descriptionText(AppState state) => state.isArabic
      ? "منصة تجمع الحرفيين المبدعين مع عشاق الفن اليدوي، لتجربة تسوق فريدة تجمع بين الأصالة والجودة."
      : "A platform connecting creative artisans with handcraft lovers, for a unique shopping experience that blends authenticity and quality.";

  String loginText(AppState state) =>
      state.isArabic ? "تسجيل الدخول" : "Log In";

  String signUpText(AppState state) =>
      state.isArabic ? "ابدأ رحلتك" : "Start Your Journey";

  String guestText(AppState state) =>
      state.isArabic ? "تصفح كزائر" : "Browse as Guest";

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerLoginScreen(),
      ),
    );
  }

  void _navigateToSignUp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RoleSelectionScreen(),
      ),
    );
  }

  void _navigateAsGuest(BuildContext context) {
    final appState = context.read<AppState>();
    appState.setGuest();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => appState.getShellForActiveRole()),
    );
  }
  // void _navigateAsGuest(BuildContext context) {
  //   final appState = context.read<AppState>();
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => ClientDashboard(
  //         isArabic: appState.isArabic,
  //         isDarkMode: appState.isDarkMode,
  //         onToggleLanguage: () => appState.toggleLanguage(),
  //         onToggleTheme: () => appState.toggleTheme(),
  //         isGuest: true,
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // ── Read appState ────────────────────────────────────────────
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    // ── Compute all colors and text BEFORE using them ──────────
    final bg = backgroundColor(appState);
    final primaryText = primaryTextColor(appState);
    final secondaryText = secondaryTextColor(appState);
    final shimmerColors = logoShimmerColors(appState);
    final chipIcon = chipIconColor(appState);
    final topBg = topButtonBackground(appState);
    final topIcon = topIconColor(appState);
    final chipBorder = chipBorderColor(appState);
    final title = titleText(appState);
    final description = descriptionText(appState);
    final loginLabel = loginText(appState);
    final guestLabel = guestText(appState);
    final signUpGrad = signUpGradient(appState);
    final signUpTextColor = signUpTextColor_(appState);
    final topBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.18);

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width > 900) {
                // ── Desktop Layout (> 900px) ──────────────────────────────
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Top Bar (Desktop)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: topBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: topBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome, size: 16, color: isDarkMode ? goldBright : goldDark),
                                        const SizedBox(width: 8),
                                        Text(
                                          isArabic ? "منصة الحرف اليدوية الأصيلة" : "Authentic Handcraft Platform",
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _topBarButton(
                                    icon: Icons.language,
                                    label: isArabic ? "EN" : "عربي",
                                    bg: topBg,
                                    iconColor: topIcon,
                                    borderColor: topBorder,
                                    onTap: () => appState.toggleLanguage(),
                                  ),
                                  const SizedBox(width: 10),
                                  _topBarButton(
                                    icon: isDarkMode
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    label: "",
                                    bg: topBg,
                                    iconColor: topIcon,
                                    borderColor: topBorder,
                                    onTap: () => appState.toggleTheme(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Main Desktop Split Content
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left Column: Logo, Titles, Description, Chips & CTAs
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: isArabic ? 0 : 28,
                                    left: isArabic ? 28 : 0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildShimmerLogo(shimmerColors, height: 110),
                                      const SizedBox(height: 20),
                                      Text(
                                        title,
                                        textDirection: direction,
                                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                        style: GoogleFonts.elMessiri(
                                          color: isDarkMode ? goldBright : goldDark,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          height: 1.25,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        description,
                                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                        style: TextStyle(
                                          color: secondaryText,
                                          fontSize: 15,
                                          height: 1.7,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _featureChip(
                                            icon: Icons.lightbulb_outline,
                                            text: isArabic ? "طلبات ذكية بالـ AI" : "AI Smart Orders",
                                            chipBg: topBg,
                                            borderColor: chipBorder,
                                            textColor: primaryText,
                                            iconColor: chipIcon,
                                          ),
                                          _featureChip(
                                            icon: Icons.balance,
                                            text: isArabic ? "عروض تنافسية" : "Competitive Bids",
                                            chipBg: topBg,
                                            borderColor: chipBorder,
                                            textColor: primaryText,
                                            iconColor: chipIcon,
                                          ),
                                          _featureChip(
                                            icon: Icons.shield_outlined,
                                            text: isArabic ? "ضمان دفع آمن" : "Secure Escrow",
                                            chipBg: topBg,
                                            borderColor: chipBorder,
                                            textColor: primaryText,
                                            iconColor: chipIcon,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),

                                      // Actions
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: AnimatedStartButton(
                                              text: guestLabel,
                                              gradient: signUpGrad,
                                              glowColor: isDarkMode ? goldBright : navy,
                                              textColor: signUpTextColor,
                                              onPressed: () => _navigateAsGuest(context),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            flex: 5,
                                            child: SizedBox(
                                              height: 48,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: primaryText,
                                                  side: BorderSide(
                                                    color: isDarkMode ? goldBright : navy,
                                                    width: 1.5,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                ),
                                                onPressed: () => _navigateToLogin(context),
                                                child: Text(
                                                  loginLabel,
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      Align(
                                        alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _navigateToSignUp(context),
                                          icon: Icon(Icons.person_add_outlined, size: 18, color: secondaryText),
                                          label: Text(
                                            isArabic
                                                ? "إنشاء حساب / اختيار نوع الحساب"
                                                : "Create Account / Select Role",
                                            style: GoogleFonts.cairo(
                                              color: secondaryText,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right Column: Showcase Card Frame
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF141E2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? goldBright.withValues(alpha: 0.35)
                                          : goldDark.withValues(alpha: 0.25),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDarkMode
                                            ? goldBright.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: topBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: chipBorder),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.palette_outlined, size: 16, color: chipIcon),
                                            const SizedBox(width: 8),
                                            Text(
                                              isArabic ? "معرض أعمال الحرفيين المميزة" : "Featured Craftsmen Showcase",
                                              style: GoogleFonts.elMessiri(
                                                color: primaryText,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      _buildCarousel(
                                        height: 330,
                                        isDarkMode: isDarkMode,
                                        isArabic: isArabic,
                                      ),
                                      const SizedBox(height: 16),

                                      _buildDotIndicators(isDarkMode: isDarkMode),
                                      const SizedBox(height: 16),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _badgeTag(
                                            icon: Icons.verified_outlined,
                                            label: isArabic ? "صناع موثوقون" : "Verified Artisans",
                                            chipIcon: chipIcon,
                                            secondaryText: secondaryText,
                                          ),
                                          const SizedBox(width: 16),
                                          _badgeTag(
                                            icon: Icons.brush_outlined,
                                            label: isArabic ? "صناعة يدوية 100%" : "100% Handmade",
                                            chipIcon: chipIcon,
                                            secondaryText: secondaryText,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (width >= 600) {
                // ── Tablet Layout (600px - 900px) ─────────────────────────
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 680),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _topBarButton(
                                icon: Icons.language,
                                label: isArabic ? "EN" : "عربي",
                                bg: topBg,
                                iconColor: topIcon,
                                borderColor: topBorder,
                                onTap: () => appState.toggleLanguage(),
                              ),
                              const SizedBox(width: 10),
                              _topBarButton(
                                icon: isDarkMode
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                label: "",
                                bg: topBg,
                                iconColor: topIcon,
                                borderColor: topBorder,
                                onTap: () => appState.toggleTheme(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildShimmerLogo(shimmerColors, height: 120),
                          const SizedBox(height: 16),

                          Text(
                            title,
                            textDirection: direction,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.elMessiri(
                              color: isDarkMode ? goldBright : goldDark,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildCarousel(
                            height: 280,
                            isDarkMode: isDarkMode,
                            isArabic: isArabic,
                          ),
                          const SizedBox(height: 12),

                          _buildDotIndicators(isDarkMode: isDarkMode),
                          const SizedBox(height: 20),

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _featureChip(
                                icon: Icons.lightbulb_outline,
                                text: isArabic ? "طلبات ذكية بالـ AI" : "AI Smart Orders",
                                chipBg: topBg,
                                borderColor: chipBorder,
                                textColor: primaryText,
                                iconColor: chipIcon,
                              ),
                              _featureChip(
                                icon: Icons.balance,
                                text: isArabic ? "عروض تنافسية" : "Competitive Bids",
                                chipBg: topBg,
                                borderColor: chipBorder,
                                textColor: primaryText,
                                iconColor: chipIcon,
                              ),
                              _featureChip(
                                icon: Icons.shield_outlined,
                                text: isArabic ? "ضمان دفع آمن" : "Secure Escrow",
                                chipBg: topBg,
                                borderColor: chipBorder,
                                textColor: primaryText,
                                iconColor: chipIcon,
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: AnimatedStartButton(
                                  text: guestLabel,
                                  gradient: signUpGrad,
                                  glowColor: isDarkMode ? goldBright : navy,
                                  textColor: signUpTextColor,
                                  onPressed: () => _navigateAsGuest(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryText,
                                      side: BorderSide(
                                          color: isDarkMode ? goldBright : navy,
                                          width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: () => _navigateToLogin(context),
                                    child: Text(
                                      loginLabel,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextButton.icon(
                            onPressed: () => _navigateToSignUp(context),
                            icon: Icon(Icons.person_add_outlined,
                                size: 18, color: secondaryText),
                            label: Text(
                              isArabic
                                  ? "إنشاء حساب / اختيار نوع الحساب"
                                  : "Create Account / Select Role",
                              style: GoogleFonts.cairo(
                                color: secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // ── Mobile Layout (< 600px) ────────────────────────────────
              // Kept EXACT mobile layout as before
              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _topBarButton(
                              icon: Icons.language,
                              label: isArabic ? "EN" : "عربي",
                              bg: topBg,
                              iconColor: topIcon,
                              borderColor: topBorder,
                              onTap: () => appState.toggleLanguage(),
                            ),
                            const SizedBox(width: 10),
                            _topBarButton(
                              icon: isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              label: "",
                              bg: topBg,
                              iconColor: topIcon,
                              borderColor: topBorder,
                              onTap: () => appState.toggleTheme(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Logo
                        _buildShimmerLogo(shimmerColors, height: 120),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          title,
                          textDirection: direction,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.elMessiri(
                            color: isDarkMode ? goldBright : goldDark,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Animated Carousel
                        _buildCarousel(
                          height: 240,
                          isDarkMode: isDarkMode,
                          isArabic: isArabic,
                        ),
                        const SizedBox(height: 12),

                        // Dot Indicators
                        _buildDotIndicators(isDarkMode: isDarkMode),
                        const SizedBox(height: 20),

                        // Feature Chips
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _featureChip(
                              icon: Icons.lightbulb_outline,
                              text: isArabic ? "طلبات ذكية بالـ AI" : "AI Smart Orders",
                              chipBg: topBg,
                              borderColor: chipBorder,
                              textColor: primaryText,
                              iconColor: chipIcon,
                            ),
                            _featureChip(
                              icon: Icons.balance,
                              text: isArabic ? "عروض تنافسية" : "Competitive Bids",
                              chipBg: topBg,
                              borderColor: chipBorder,
                              textColor: primaryText,
                              iconColor: chipIcon,
                            ),
                            _featureChip(
                              icon: Icons.shield_outlined,
                              text: isArabic ? "ضمان دفع آمن" : "Secure Escrow",
                              chipBg: topBg,
                              borderColor: chipBorder,
                              textColor: primaryText,
                              iconColor: chipIcon,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // 3 Clear Pathways
                        AnimatedStartButton(
                          text: guestLabel,
                          gradient: signUpGrad,
                          glowColor: isDarkMode ? goldBright : navy,
                          textColor: signUpTextColor,
                          onPressed: () => _navigateAsGuest(context),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryText,
                              side: BorderSide(
                                  color: isDarkMode ? goldBright : navy,
                                  width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: () => _navigateToLogin(context),
                            child: Text(
                              loginLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextButton.icon(
                          onPressed: () => _navigateToSignUp(context),
                          icon: Icon(Icons.person_add_outlined,
                              size: 18, color: secondaryText),
                          label: Text(
                            isArabic
                                ? "إنشاء حساب / اختيار نوع الحساب"
                                : "Create Account / Select Role",
                            style: GoogleFonts.cairo(
                              color: secondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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

  // ── Helper widgets ────────────────────────────────────────────────────

  Widget _buildShimmerLogo(List<Color> shimmerColors, {double height = 120}) {
    return AnimatedBuilder(
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
            height: height,
          ),
        );
      },
    );
  }

  Widget _buildCarousel({
    required double height,
    required bool isDarkMode,
    required bool isArabic,
  }) {
    return Semantics(
      label: isArabic
          ? 'معرض أعمال الحرفيين من فخار ومجوهرات وسلال وغيرها'
          : 'Showcase of craftsmen works',
      child: SizedBox(
        height: height,
        child: PageView.builder(
          controller: _carouselController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) {
            setState(() => _carouselPage = i % _carouselImages.length);
          },
          itemBuilder: (context, index) {
            final imageIndex = index % _carouselImages.length;
            return AnimatedBuilder(
              animation: _carouselController,
              builder: (context, child) {
                double page = _carouselController.hasClients
                    ? (_carouselController.page ?? index.toDouble())
                    : index.toDouble();
                double delta = (index - page).abs().clamp(0.0, 1.0);
                double scale = 1.0 - (delta * 0.18);
                double opacity = 1.0 - (delta * 0.45);
                double translateY = delta * 22;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..scale(scale)
                    ..translate(0.0, translateY),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDarkMode
                          ? goldBright.withValues(alpha: 0.55)
                          : goldDark.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? goldBright.withValues(alpha: 0.22)
                            : navy.withValues(alpha: 0.18),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          _carouselImages[imageIndex],
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                            child: Text(
                              isArabic
                                  ? _carouselImages[imageIndex].contains('plate')
                                      ? 'السيراميك والأطباق'
                                      : _carouselImages[imageIndex].contains('pottery')
                                          ? 'الفخار'
                                          : _carouselImages[imageIndex].contains('jewelry')
                                              ? 'المجوهرات'
                                              : _carouselImages[imageIndex].contains('basket')
                                                  ? 'السلال المنسوجة'
                                                  : 'الكروشيه والمنسوجات'
                                  : _carouselLabels[imageIndex],
                              style: GoogleFonts.elMessiri(
                                color: goldBrightLight,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  const Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDotIndicators({required bool isDarkMode}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_carouselImages.length, (i) {
        final active = i == _carouselPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? (isDarkMode ? goldBright : goldDark)
                : (isDarkMode ? Colors.white30 : Colors.black26),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: isDarkMode
                          ? goldBright.withValues(alpha: 0.5)
                          : goldDark.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
        );
      }),
    );
  }

  Widget _badgeTag({
    required IconData icon,
    required String label,
    required Color chipIcon,
    required Color secondaryText,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipIcon),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: secondaryText,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
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
                style: TextStyle(
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

  Widget _featureChip({
    required IconData icon,
    required String text,
    required Color chipBg,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: textColor, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Custom Animated Start Button ─────────────────────────────────────────────
class AnimatedStartButton extends StatefulWidget {
  final String text;
  final List<Color> gradient;
  final Color glowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const AnimatedStartButton({
    super.key,
    required this.text,
    required this.gradient,
    required this.glowColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  State<AnimatedStartButton> createState() => _AnimatedStartButtonState();
}

class _AnimatedStartButtonState extends State<AnimatedStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glowVal = _glowAnimation.value;
            return Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: widget.gradient),
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor
                        .withValues(alpha: 0.2 + (glowVal * 0.25)),
                    blurRadius: 10 + (glowVal * 10),
                    spreadRadius: 1 + (glowVal * 2),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapUp: (_) => setState(() => _isPressed = false),
                  onTapCancel: () => setState(() => _isPressed = false),
                  onTap: widget.onPressed,
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: widget.textColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
