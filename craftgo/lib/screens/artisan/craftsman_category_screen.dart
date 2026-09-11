import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/craftsman_registration_screen.dart'; // changed import
import 'add_craft_details_screen.dart';

class CraftsmanCategoryScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  /// When true, selecting a craft fires [onCraftAdded] instead of pushing registration.
  final bool addCraftMode;
  final void Function(Map<String, dynamic> category)? onCraftAdded;

  const CraftsmanCategoryScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    this.addCraftMode = false,
    this.onCraftAdded,
  });

  @override
  State<CraftsmanCategoryScreen> createState() =>
      _CraftsmanCategoryScreenState();
}

class _CraftsmanCategoryScreenState extends State<CraftsmanCategoryScreen>
    with TickerProviderStateMixin {
  late bool isArabic;
  late bool isDarkMode;

  // Selected category index
  int? selectedIndex;

  // Animations
  late AnimationController _entranceController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // Colors mapping
  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;

  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;

  Color get cardBorderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

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

  // Categories definition – added "Other (Custom)" at the end
  List<Map<String, dynamic>> get categories => [
        {
          "icon": Icons.checkroom_outlined,
          "titleAr": "خياطة وتطريز",
          "titleEn": "Crochet & Knitting",
          "descAr": "ملابس، دمى، وأقمشة مطرزة يدوياً.",
          "descEn": "Handmade clothes, toys, and embroidered fabrics.",
        },
        {
          "icon": Icons.local_cafe_outlined,
          "titleAr": "الفخار والخزف",
          "titleEn": "Pottery & Ceramics",
          "descAr": "أواني فخارية، لوحات سيراميك، وتحف طينية.",
          "descEn": "Clay pots, ceramic plates, and earthen masterpieces.",
        },
        {
          "icon": Icons.watch_outlined,
          "titleAr": "الحلي والمجوهرات",
          "titleEn": "Jewelry & Accessories",
          "descAr": "خواتم، أساور، وعقود يدوية فاخرة.",
          "descEn": "Premium handmade rings, bracelets, and necklaces.",
        },
        {
          "icon": Icons.chair_outlined,
          "titleAr": "أعمال الخشب والأثاث",
          "titleEn": "Woodworking",
          "descAr": "حفر على الخشب، إطارات، وهدايا خشبية.",
          "descEn": "Wood carving, custom frames, and wooden gifts.",
        },
        {
          "icon": Icons.shopping_basket_outlined,
          "titleAr": "صناعة السلال والقش",
          "titleEn": "Weaving & Baskets",
          "descAr": "سلال قش، مقاعد تقليدية، وحصائر يدوية.",
          "descEn": "Straw baskets, traditional stools, and handmade mats.",
        },
        {
          "icon": Icons.brush_outlined,
          "titleAr": "الرسم والزخرفة",
          "titleEn": "Painting & Decoration",
          "descAr": "لوحات فنية، خط عربي، وزخرفة الزجاج.",
          "descEn": "Artistic paintings, Arabic calligraphy, and glass decor.",
        },
        // NEW: Other / Custom category
        {
          "icon": Icons.add_circle_outline,
          "titleAr": "أخرى (حدد بنفسك)",
          "titleEn": "Other (Custom)",
          "descAr": "أدخل حرفتك الخاصة",
          "descEn": "Enter your own craft",
        },
      ];

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _topBarButton(
                        icon: isArabic
                            ? Icons.arrow_forward_ios
                            : Icons.arrow_back_ios,
                        label: "",
                        onTap: () => Navigator.pop(context),
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
                  const SizedBox(height: 25),

                  // Title area
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      final dx = _shimmerController.value;
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              primaryTextColor,
                              const Color(0xFFD4A017),
                              Colors.white,
                              primaryTextColor,
                            ],
                            begin: Alignment(-1.0 + dx * 2, -0.5),
                            end: Alignment(1.0 + dx * 2, 0.5),
                            tileMode: TileMode.mirror,
                          ).createShader(bounds);
                        },
                        child: Text(
                          isArabic
                              ? "ما هي حرفتك الإبداعية؟"
                              : "What is your creative craft?",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.arefRuqaa(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? "اختر مجالك الرئيسي لنوجهك للطلبات المناسبة"
                        : "Select your main craft to guide you to the right orders",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                  const SizedBox(height: 25),

                  // Grid of Categories
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = selectedIndex == index;
                          final delay = index * 100;

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 600 + delay),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: CategoryGridCard(
                              heroTag: 'craft-icon-${cat["titleEn"]}',
                              icon: cat["icon"],
                              title: isArabic ? cat["titleAr"] : cat["titleEn"],
                              description:
                                  isArabic ? cat["descAr"] : cat["descEn"],
                              isSelected: isSelected,
                              isDarkMode: isDarkMode,
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                              cardBorderColor: cardBorderColor,
                              onTap: () {
                                setState(() {
                                  selectedIndex = index;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button – now directly navigates to registration
                  AnimatedOpacity(
                    opacity: selectedIndex != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                        ),
                        boxShadow: selectedIndex != null
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF7B500,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: selectedIndex != null
                            ? () {
                                final selectedCat = categories[selectedIndex!];
                                if (widget.addCraftMode) {
                                  // Keep addCraftMode functionality unchanged
                                  Navigator.push(
                                    context,
                                    _buildPageRoute(
                                      isArabic: isArabic,
                                      child: AddCraftDetailsScreen(
                                        selectedCategory: selectedCat,
                                        isArabic: isArabic,
                                        isDarkMode: isDarkMode,
                                        onToggleLanguage: toggleLanguage,
                                        onToggleTheme: toggleTheme,
                                        onConfirmed: (enriched) {
                                          widget.onCraftAdded?.call(enriched);
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  // Directly navigate to registration screen (not login)
                                  Navigator.push(
                                    context,
                                    _buildPageRoute(
                                      isArabic: isArabic,
                                      child: CraftsmanRegistrationScreen(
                                        selectedCategory: selectedCat,
                                        isArabic: isArabic,
                                        isDarkMode: isDarkMode,
                                        onToggleLanguage: toggleLanguage,
                                        onToggleTheme: toggleTheme,
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Text(
                          isArabic ? "متابعة" : "Continue",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  PageRouteBuilder _buildPageRoute({
    required bool isArabic,
    required Widget child,
  }) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final begin =
            isArabic ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var slideTween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween =
            Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }
}

class CategoryGridCard extends StatefulWidget {
  final String heroTag;
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool isDarkMode;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color cardBorderColor;
  final VoidCallback onTap;

  const CategoryGridCard({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.isDarkMode,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.cardBorderColor,
    required this.onTap,
  });

  @override
  State<CategoryGridCard> createState() => _CategoryGridCardState();
}

class _CategoryGridCardState extends State<CategoryGridCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _currentScale {
    if (_isPressed) return 0.96;
    if (_isHovered) return 1.03;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFD4A017);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _currentScale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _isHovered && !_isPressed ? -6 : 0,
              0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isSelected
                    ? activeColor
                    : (_isHovered
                        ? activeColor.withValues(alpha: 0.6)
                        : widget.cardBorderColor),
                width: widget.isSelected || _isHovered ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? activeColor.withValues(alpha: 0.2)
                      : (_isHovered
                          ? activeColor.withValues(alpha: 0.12)
                          : (widget.isDarkMode
                              ? activeColor.withValues(alpha: 0.02)
                              : Colors.black.withValues(alpha: 0.03))),
                  blurRadius: _isHovered || widget.isSelected ? 20 : 12,
                  offset: _isHovered || widget.isSelected
                      ? const Offset(0, 8)
                      : const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isSelected
                          ? [
                              activeColor.withValues(alpha: 0.15),
                              activeColor.withValues(alpha: 0.03),
                            ]
                          : (widget.isDarkMode
                              ? [
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.white.withValues(alpha: 0.015),
                                ]
                              : [
                                  Colors.black.withValues(alpha: 0.03),
                                  Colors.black.withValues(alpha: 0.005),
                                ]),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: widget.heroTag,
                        flightShuttleBuilder: (_, animation, __, ___, ____) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (_, __) => Container(
                              width: 48 + (32 * animation.value),
                              height: 48 + (32 * animation.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF7B500),
                                    Color(0xFFD89A00)
                                  ],
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                size: 22 + (18 * animation.value),
                                color: Colors.black,
                              ),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: widget.isSelected
                                  ? [
                                      const Color(0xFFF7B500),
                                      const Color(0xFFD89A00),
                                    ]
                                  : [
                                      activeColor.withValues(alpha: 0.2),
                                      activeColor.withValues(alpha: 0.05),
                                    ],
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 22,
                            color:
                                widget.isSelected ? Colors.black : activeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.primaryTextColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.secondaryTextColor,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../widgets/craftsman_login_screen.dart';
// import 'add_craft_details_screen.dart';

// class CraftsmanCategoryScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onToggleLanguage;
//   final VoidCallback onToggleTheme;

//   /// When true, selecting a craft fires [onCraftAdded] instead of pushing registration.
//   final bool addCraftMode;
//   final void Function(Map<String, dynamic> category)? onCraftAdded;

//   const CraftsmanCategoryScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onToggleLanguage,
//     required this.onToggleTheme,
//     this.addCraftMode = false,
//     this.onCraftAdded,
//   });

//   @override
//   State<CraftsmanCategoryScreen> createState() =>
//       _CraftsmanCategoryScreenState();
// }

// class _CraftsmanCategoryScreenState extends State<CraftsmanCategoryScreen>
//     with TickerProviderStateMixin {
//   late bool isArabic;
//   late bool isDarkMode;

//   // Selected category index
//   int? selectedIndex;

//   // Animations
//   late AnimationController _entranceController;
//   late AnimationController _shimmerController;

//   @override
//   void initState() {
//     super.initState();
//     isArabic = widget.isArabic;
//     isDarkMode = widget.isDarkMode;

//     _entranceController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     );

//     _shimmerController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     )..repeat();

//     _entranceController.forward();
//   }

//   @override
//   void dispose() {
//     _entranceController.dispose();
//     _shimmerController.dispose();
//     super.dispose();
//   }

//   // Colors mapping
//   Color get backgroundColor =>
//       isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

//   Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;

//   Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;

//   Color get cardBorderColor => isDarkMode
//       ? Colors.white.withValues(alpha: 0.12)
//       : Colors.black.withValues(alpha: 0.08);

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

//   // Categories definition
//   List<Map<String, dynamic>> get categories => [
//     {
//       "icon": Icons.checkroom_outlined,
//       "titleAr": "خياطة وتطريز",
//       "titleEn": "Crochet & Knitting",
//       "descAr": "ملابس، دمى، وأقمشة مطرزة يدوياً.",
//       "descEn": "Handmade clothes, toys, and embroidered fabrics.",
//     },
//     {
//       "icon": Icons.local_cafe_outlined, // fits pottery cup shape
//       "titleAr": "الفخار والخزف",
//       "titleEn": "Pottery & Ceramics",
//       "descAr": "أواني فخارية، لوحات سيراميك، وتحف طينية.",
//       "descEn": "Clay pots, ceramic plates, and earthen masterpieces.",
//     },
//     {
//       "icon": Icons.watch_outlined,
//       "titleAr": "الحلي والمجوهرات",
//       "titleEn": "Jewelry & Accessories",
//       "descAr": "خواتم، أساور، وعقود يدوية فاخرة.",
//       "descEn": "Premium handmade rings, bracelets, and necklaces.",
//     },
//     {
//       "icon": Icons.chair_outlined,
//       "titleAr": "أعمال الخشب والأثاث",
//       "titleEn": "Woodworking",
//       "descAr": "حفر على الخشب، إطارات، وهدايا خشبية.",
//       "descEn": "Wood carving, custom frames, and wooden gifts.",
//     },
//     {
//       "icon": Icons.shopping_basket_outlined,
//       "titleAr": "صناعة السلال والقش",
//       "titleEn": "Weaving & Baskets",
//       "descAr": "سلال قش، مقاعد تقليدية، وحصائر يدوية.",
//       "descEn": "Straw baskets, traditional stools, and handmade mats.",
//     },
//     {
//       "icon": Icons.brush_outlined,
//       "titleAr": "الرسم والزخرفة",
//       "titleEn": "Painting & Decoration",
//       "descAr": "لوحات فنية، خط عربي، وزخرفة الزجاج.",
//       "descEn": "Artistic paintings, Arabic calligraphy, and glass decor.",
//     },
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

//     return Directionality(
//       textDirection: direction,
//       child: Scaffold(
//         backgroundColor: backgroundColor,
//         body: SafeArea(
//           child: Center(
//             child: Container(
//               constraints: const BoxConstraints(maxWidth: 430),
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//               child: Column(
//                 children: [
//                   // Top Bar
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       _topBarButton(
//                         icon: isArabic
//                             ? Icons.arrow_forward_ios
//                             : Icons.arrow_back_ios,
//                         label: "",
//                         onTap: () => Navigator.pop(context),
//                       ),
//                       Row(
//                         children: [
//                           _topBarButton(
//                             icon: Icons.language,
//                             label: isArabic ? "EN" : "عربي",
//                             onTap: toggleLanguage,
//                           ),
//                           const SizedBox(width: 10),
//                           _topBarButton(
//                             icon: isDarkMode
//                                 ? Icons.light_mode_outlined
//                                 : Icons.dark_mode_outlined,
//                             label: "",
//                             onTap: toggleTheme,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 25),

//                   // Title area
//                   AnimatedBuilder(
//                     animation: _shimmerController,
//                     builder: (context, child) {
//                       final dx = _shimmerController.value;
//                       return ShaderMask(
//                         blendMode: BlendMode.srcIn,
//                         shaderCallback: (bounds) {
//                           return LinearGradient(
//                             colors: [
//                               primaryTextColor,
//                               const Color(0xFFD4A017),
//                               Colors.white,
//                               primaryTextColor,
//                             ],
//                             begin: Alignment(-1.0 + dx * 2, -0.5),
//                             end: Alignment(1.0 + dx * 2, 0.5),
//                             tileMode: TileMode.mirror,
//                           ).createShader(bounds);
//                         },
//                         child: Text(
//                           isArabic
//                               ? "ما هي حرفتك الإبداعية؟"
//                               : "What is your creative craft?",
//                           textAlign: TextAlign.center,
//                           style: GoogleFonts.arefRuqaa(
//                             color: Colors.white,
//                             fontSize: 26,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     isArabic
//                         ? "اختر مجالك الرئيسي لنوجهك للطلبات المناسبة"
//                         : "Select your main craft to guide you to the right orders",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: secondaryTextColor, fontSize: 14),
//                   ),
//                   const SizedBox(height: 25),

//                   // Grid of Categories
//                   Expanded(
//                     child: Scrollbar(
//                       thumbVisibility: true,
//                       child: GridView.builder(
//                         physics: const BouncingScrollPhysics(),
//                         gridDelegate:
//                             const SliverGridDelegateWithFixedCrossAxisCount(
//                               crossAxisCount: 2,
//                               crossAxisSpacing: 16,
//                               mainAxisSpacing: 16,
//                               childAspectRatio: 0.9,
//                             ),
//                         itemCount: categories.length,
//                         itemBuilder: (context, index) {
//                           final cat = categories[index];
//                           final isSelected = selectedIndex == index;
//                           final delay = index * 100;

//                           return TweenAnimationBuilder<double>(
//                             tween: Tween(begin: 0.0, end: 1.0),
//                             duration: Duration(milliseconds: 600 + delay),
//                             curve: Curves.easeOutCubic,
//                             builder: (context, value, child) {
//                               return Transform.scale(
//                                 scale: value,
//                                 child: Opacity(opacity: value, child: child),
//                               );
//                             },
//                             child: CategoryGridCard(
//                               heroTag: 'craft-icon-${cat["titleEn"]}',
//                               icon: cat["icon"],
//                               title: isArabic ? cat["titleAr"] : cat["titleEn"],
//                               description: isArabic
//                                   ? cat["descAr"]
//                                   : cat["descEn"],
//                               isSelected: isSelected,
//                               isDarkMode: isDarkMode,
//                               primaryTextColor: primaryTextColor,
//                               secondaryTextColor: secondaryTextColor,
//                               cardBorderColor: cardBorderColor,
//                               onTap: () {
//                                 setState(() {
//                                   selectedIndex = index;
//                                 });
//                               },
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),

//                   // Confirm button
//                   AnimatedOpacity(
//                     opacity: selectedIndex != null ? 1.0 : 0.4,
//                     duration: const Duration(milliseconds: 300),
//                     child: Container(
//                       width: double.infinity,
//                       height: 55,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(30),
//                         gradient: const LinearGradient(
//                           colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
//                         ),
//                         boxShadow: selectedIndex != null
//                             ? [
//                                 BoxShadow(
//                                   color: const Color(
//                                     0xFFF7B500,
//                                   ).withValues(alpha: 0.3),
//                                   blurRadius: 15,
//                                   spreadRadius: 1,
//                                   offset: const Offset(0, 5),
//                                 ),
//                               ]
//                             : null,
//                       ),
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.transparent,
//                           shadowColor: Colors.transparent,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                         ),
//                         onPressed: selectedIndex != null
//                             ? () {
//                                 final selectedCat = categories[selectedIndex!];
//                                 if (widget.addCraftMode) {
//                                   Navigator.push(
//                                     context,
//                                     _buildPageRoute(
//                                       isArabic: isArabic,
//                                       child: AddCraftDetailsScreen(
//                                         selectedCategory: selectedCat,
//                                         isArabic: isArabic,
//                                         isDarkMode: isDarkMode,
//                                         onToggleLanguage: toggleLanguage,
//                                         onToggleTheme: toggleTheme,
//                                         onConfirmed: (enriched) {
//                                           widget.onCraftAdded?.call(enriched);
//                                           Navigator.pop(context);
//                                         },
//                                       ),
//                                     ),
//                                   );
//                                 } else {
//                                   final heroTag = 'craft-icon-${selectedCat["titleEn"]}';
//                                   Navigator.push(
//                                     context,
//                                     _buildPageRoute(
//                                       isArabic: isArabic,
//                                       child: CraftsmanLoginScreen(
//                                         selectedCategory: selectedCat,
//                                         heroTag: heroTag,
//                                         isArabic: isArabic,
//                                         isDarkMode: isDarkMode,
//                                         onToggleLanguage: toggleLanguage,
//                                         onToggleTheme: toggleTheme,
//                                       ),
//                                     ),
//                                   );
//                                 }
//                               }
//                             : null,
//                         child: Text(
//                           isArabic ? "متابعة" : "Continue",
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: isDarkMode ? Colors.black : Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
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

//   PageRouteBuilder _buildPageRoute({
//     required bool isArabic,
//     required Widget child,
//   }) {
//     return PageRouteBuilder(
//       transitionDuration: const Duration(milliseconds: 600),
//       reverseTransitionDuration: const Duration(milliseconds: 500),
//       pageBuilder: (context, animation, secondaryAnimation) => child,
//       transitionsBuilder: (context, animation, secondaryAnimation, child) {
//         // Slide from left to right for Arabic, right to left for English
//         final begin = isArabic ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
//         const end = Offset.zero;
//         const curve = Curves.easeInOutCubic;

//         var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
//         var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

//         return SlideTransition(
//           position: animation.drive(slideTween),
//           child: FadeTransition(
//             opacity: animation.drive(fadeTween),
//             child: child,
//           ),
//         );
//       },
//     );
//   }
// }

// class CategoryGridCard extends StatefulWidget {
//   final String heroTag;
//   final IconData icon;
//   final String title;
//   final String description;
//   final bool isSelected;
//   final bool isDarkMode;
//   final Color primaryTextColor;
//   final Color secondaryTextColor;
//   final Color cardBorderColor;
//   final VoidCallback onTap;

//   const CategoryGridCard({
//     super.key,
//     required this.heroTag,
//     required this.icon,
//     required this.title,
//     required this.description,
//     required this.isSelected,
//     required this.isDarkMode,
//     required this.primaryTextColor,
//     required this.secondaryTextColor,
//     required this.cardBorderColor,
//     required this.onTap,
//   });

//   @override
//   State<CategoryGridCard> createState() => _CategoryGridCardState();
// }

// class _CategoryGridCardState extends State<CategoryGridCard> {
//   bool _isHovered = false;
//   bool _isPressed = false;

//   double get _currentScale {
//     if (_isPressed) return 0.96;
//     if (_isHovered) return 1.03;
//     return 1.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final activeColor = const Color(0xFFD4A017);

//     return MouseRegion(
//       onEnter: (_) => setState(() => _isHovered = true),
//       onExit: (_) => setState(() => _isHovered = false),
//       child: AnimatedScale(
//         scale: _currentScale,
//         duration: const Duration(milliseconds: 150),
//         curve: Curves.easeOutCubic,
//         child: GestureDetector(
//           onTapDown: (_) => setState(() => _isPressed = true),
//           onTapUp: (_) => setState(() => _isPressed = false),
//           onTapCancel: () => setState(() => _isPressed = false),
//           onTap: widget.onTap,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             curve: Curves.easeOutCubic,
//             transform: Matrix4.translationValues(
//               0,
//               _isHovered && !_isPressed ? -6 : 0,
//               0,
//             ),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(22),
//               border: Border.all(
//                 color: widget.isSelected
//                     ? activeColor
//                     : (_isHovered
//                           ? activeColor.withValues(alpha: 0.6)
//                           : widget.cardBorderColor),
//                 width: widget.isSelected || _isHovered ? 2.0 : 1.5,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: widget.isSelected
//                       ? activeColor.withValues(alpha: 0.2)
//                       : (_isHovered
//                             ? activeColor.withValues(alpha: 0.12)
//                             : (widget.isDarkMode
//                                   ? activeColor.withValues(alpha: 0.02)
//                                   : Colors.black.withValues(alpha: 0.03))),
//                   blurRadius: _isHovered || widget.isSelected ? 20 : 12,
//                   offset: _isHovered || widget.isSelected
//                       ? const Offset(0, 8)
//                       : const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(20),
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 16,
//                   ),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: widget.isSelected
//                           ? [
//                               activeColor.withValues(alpha: 0.15),
//                               activeColor.withValues(alpha: 0.03),
//                             ]
//                           : (widget.isDarkMode
//                                 ? [
//                                     Colors.white.withValues(alpha: 0.06),
//                                     Colors.white.withValues(alpha: 0.015),
//                                   ]
//                                 : [
//                                     Colors.black.withValues(alpha: 0.03),
//                                     Colors.black.withValues(alpha: 0.005),
//                                   ]),
//                     ),
//                   ),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       // Circular Icon container — Hero for shared element transition
//                       Hero(
//                         tag: widget.heroTag,
//                         flightShuttleBuilder: (_, animation, __, ___, ____) {
//                           return AnimatedBuilder(
//                             animation: animation,
//                             builder: (_, __) => Container(
//                               width: 48 + (32 * animation.value),
//                               height: 48 + (32 * animation.value),
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 gradient: const LinearGradient(
//                                   colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
//                                 ),
//                               ),
//                               child: Icon(
//                                 widget.icon,
//                                 size: 22 + (18 * animation.value),
//                                 color: Colors.black,
//                               ),
//                             ),
//                           );
//                         },
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 200),
//                           width: 48,
//                           height: 48,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             gradient: LinearGradient(
//                               colors: widget.isSelected
//                                   ? [
//                                       const Color(0xFFF7B500),
//                                       const Color(0xFFD89A00),
//                                     ]
//                                   : [
//                                       activeColor.withValues(alpha: 0.2),
//                                       activeColor.withValues(alpha: 0.05),
//                                     ],
//                             ),
//                           ),
//                           child: Icon(
//                             widget.icon,
//                             size: 22,
//                             color: widget.isSelected ? Colors.black : activeColor,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),

//                       // Title
//                       Text(
//                         widget.title,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: widget.primaryTextColor,
//                           fontSize: 14.5,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 6),

//                       // Description
//                       Expanded(
//                         child: Text(
//                           widget.description,
//                           textAlign: TextAlign.center,
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                           style: TextStyle(
//                             color: widget.secondaryTextColor,
//                             fontSize: 10.5,
//                             height: 1.3,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
