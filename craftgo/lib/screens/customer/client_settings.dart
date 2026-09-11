import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientDashboard extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const ClientDashboard({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  late bool isArabic;
  late bool isDarkMode;

  // Selected filter category (null means "All") — quick chip row under search bar
  int? selectedFilterIndex;

  // ---- Advanced search / filter state ----
  Set<int> advancedCategoryFilters = {};
  RangeValues priceRange = const RangeValues(0, 200);
  double minRating = 0;
  // 'rating' | 'price_low' | 'price_high' | 'newest'
  String sortBy = 'rating';

  // ---- Products section state ----
  // 0 = Popular, 1 = New, 2 = Recommended
  int productTabIndex = 0;

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;
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

  Color get sheetBackground => isDarkMode
      ? const Color(0xFF0D1420).withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.95);

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

  // Category filter items
  List<Map<String, dynamic>> get categories => [
    {"icon": Icons.all_inclusive, "titleAr": "الكل", "titleEn": "All"},
    {
      "icon": Icons.checkroom_outlined,
      "titleAr": "تطريز",
      "titleEn": "Crochet",
    },
    {
      "icon": Icons.local_cafe_outlined,
      "titleAr": "فخار",
      "titleEn": "Pottery",
    },
    {"icon": Icons.watch_outlined, "titleAr": "مجوهرات", "titleEn": "Jewelry"},
    {"icon": Icons.chair_outlined, "titleAr": "خشب", "titleEn": "Wood"},
  ];

  // Mock Craftsmen
  List<Map<String, dynamic>> get craftsmen => [
    {
      "nameAr": "أمجد الخطيب",
      "nameEn": "Amjad Al-Khateeb",
      "rating": "4.9",
      "jobs": "52",
      "craftAr": "أعمال الخشب والأثاث",
      "craftEn": "Woodworking",
      "image": "assets/images/plate.jpg",
    },
    {
      "nameAr": "فاطمة محمود",
      "nameEn": "Fatima Mahmoud",
      "rating": "4.8",
      "jobs": "74",
      "craftAr": "خياطة وتطريز",
      "craftEn": "Crochet & Knitting",
      "image": "assets/images/crochet.jpg",
    },
    {
      "nameAr": "إياد الكردي",
      "nameEn": "Iyad Al-Kurdi",
      "rating": "5.0",
      "jobs": "31",
      "craftAr": "الفخار والخزف",
      "craftEn": "Pottery & Ceramics",
      "image": "assets/images/pottery.jpg",
    },
  ];

  // Mock products feed — replace with real API data later.
  // tag is one of: popular, new, recommended (a product can carry more than one).
  List<Map<String, dynamic>> get products => [
    {
      "nameAr": "سجادة صوفية مطرزة",
      "nameEn": "Embroidered Wool Rug",
      "price": 52.0,
      "rating": "4.9",
      "icon": Icons.checkroom_outlined,
      "tags": ["popular", "recommended"],
    },
    {
      "nameAr": "إبريق فخاري تقليدي",
      "nameEn": "Traditional Clay Pitcher",
      "price": 28.0,
      "rating": "4.7",
      "icon": Icons.local_cafe_outlined,
      "tags": ["popular"],
    },
    {
      "nameAr": "خاتم فضة مصنوع يدوياً",
      "nameEn": "Handmade Silver Ring",
      "price": 35.0,
      "rating": "5.0",
      "icon": Icons.watch_outlined,
      "tags": ["new", "recommended"],
    },
    {
      "nameAr": "صندوق خشبي محفور",
      "nameEn": "Carved Wooden Box",
      "price": 60.0,
      "rating": "4.8",
      "icon": Icons.chair_outlined,
      "tags": ["new"],
    },
    {
      "nameAr": "وشاح صوف منسوج يدوياً",
      "nameEn": "Hand-Woven Wool Scarf",
      "price": 22.0,
      "rating": "4.6",
      "icon": Icons.checkroom_outlined,
      "tags": ["recommended"],
    },
    {
      "nameAr": "طبق خزفي مرسوم",
      "nameEn": "Hand-Painted Ceramic Plate",
      "price": 40.0,
      "rating": "4.9",
      "icon": Icons.local_cafe_outlined,
      "tags": ["popular", "new"],
    },
  ];

  List<Map<String, dynamic>> get filteredProducts {
    const tags = ['popular', 'new', 'recommended'];
    final activeTag = tags[productTabIndex];
    return products
        .where((p) => (p["tags"] as List).contains(activeTag))
        .toList();
  }

  // Open AI Order Creator Bottom Sheet
  void _openAIOrderCreator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF0D1420).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                ),
                child: Directionality(
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? "طلب ذكي بالـ AI" : "AI Smart Order",
                            style: GoogleFonts.arefRuqaa(
                              color: const Color(0xFFD4A017),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: primaryTextColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? "اكتب ما تحتاجه وسيقوم الذكاء الاصطناعي بتصنيفه وتحديد السعر الموصى به."
                            : "Write what you need and the AI will categorize it and recommend a price.",
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Text Field
                      TextField(
                        maxLines: 3,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? "أحتاج إلى سجادة صوفية صغيرة بنقش تقليدي أحمر..."
                              : "I need a small wool rug with red traditional patterns...",
                          hintStyle: TextStyle(
                            color: secondaryTextColor.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.white10
                              : Colors.black12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFD4A017),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Estimated Price Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A017).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(
                              0xFFD4A017,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFD4A017),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic
                                        ? "السعر الموصى به"
                                        : "Recommended Price Range",
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isArabic
                                        ? "45 - 60 دينار أردني"
                                        : "45 - 60 JOD",
                                    style: const TextStyle(
                                      color: Color(0xFFD4A017),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Post Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? "تم نشر طلبك بنجاح وسيتواصل معك الحرفيون قريباً!"
                                      : "Order posted successfully! Craftsmen will bid soon.",
                                ),
                              ),
                            );
                          },
                          child: Text(
                            isArabic ? "نشر الطلب" : "Post Order",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Open Advanced Search / Filters Bottom Sheet
  void _openAdvancedSearch() {
    // Local copies so changes only apply when the user taps "Apply"
    Set<int> tempCategories = {...advancedCategoryFilters};
    RangeValues tempPriceRange = priceRange;
    double tempMinRating = minRating;
    String tempSortBy = sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                decoration: BoxDecoration(
                  color: sheetBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                ),
                child: Directionality(
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? "تصفية متقدمة" : "Advanced Filters",
                              style: GoogleFonts.arefRuqaa(
                                color: const Color(0xFFD4A017),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: primaryTextColor),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Categories (multi-select)
                        Text(
                          isArabic ? "الفئات" : "Categories",
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(categories.length, (index) {
                            if (index == 0) {
                              return const SizedBox.shrink(); // skip "All"
                            }
                            final cat = categories[index];
                            final selected = tempCategories.contains(index);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (selected) {
                                    tempCategories.remove(index);
                                  } else {
                                    tempCategories.add(index);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFD4A017)
                                      : (isDarkMode
                                            ? Colors.white.withValues(
                                                alpha: 0.04,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.03,
                                              )),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFD4A017)
                                        : cardBorderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat["icon"],
                                      size: 15,
                                      color: selected
                                          ? Colors.black
                                          : (isDarkMode
                                                ? Colors.white70
                                                : Colors.black87),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic
                                          ? cat["titleAr"]
                                          : cat["titleEn"],
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: selected
                                            ? Colors.black
                                            : (isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Price range
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? "نطاق السعر" : "Price Range",
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${tempPriceRange.start.round()} - ${tempPriceRange.end.round()} JOD",
                              style: const TextStyle(
                                color: Color(0xFFD4A017),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFD4A017),
                            inactiveTrackColor: cardBorderColor,
                            thumbColor: const Color(0xFFD4A017),
                            overlayColor: const Color(
                              0xFFD4A017,
                            ).withValues(alpha: 0.15),
                          ),
                          child: RangeSlider(
                            min: 0,
                            max: 300,
                            divisions: 60,
                            values: tempPriceRange,
                            onChanged: (values) {
                              setModalState(() {
                                tempPriceRange = values;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Minimum rating
                        Text(
                          isArabic ? "الحد الأدنى للتقييم" : "Minimum Rating",
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (i) {
                            final starValue = i + 1;
                            final filled = starValue <= tempMinRating;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  tempMinRating = (tempMinRating == starValue)
                                      ? 0
                                      : starValue.toDouble();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  color: const Color(0xFFF7B500),
                                  size: 28,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Sort by
                        Text(
                          isArabic ? "الترتيب حسب" : "Sort By",
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _sortChip(
                              tempSortBy,
                              'rating',
                              isArabic ? "الأعلى تقييماً" : "Top Rated",
                              setModalState,
                              (v) => tempSortBy = v,
                            ),
                            _sortChip(
                              tempSortBy,
                              'price_low',
                              isArabic ? "السعر: الأقل" : "Price: Low to High",
                              setModalState,
                              (v) => tempSortBy = v,
                            ),
                            _sortChip(
                              tempSortBy,
                              'price_high',
                              isArabic ? "السعر: الأعلى" : "Price: High to Low",
                              setModalState,
                              (v) => tempSortBy = v,
                            ),
                            _sortChip(
                              tempSortBy,
                              'newest',
                              isArabic ? "الأحدث" : "Newest",
                              setModalState,
                              (v) => tempSortBy = v,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: cardBorderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    tempCategories = {};
                                    tempPriceRange = const RangeValues(0, 200);
                                    tempMinRating = 0;
                                    tempSortBy = 'rating';
                                  });
                                },
                                child: Text(
                                  isArabic ? "إعادة تعيين" : "Reset",
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF7B500),
                                      Color(0xFFD89A00),
                                    ],
                                  ),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      advancedCategoryFilters = tempCategories;
                                      priceRange = tempPriceRange;
                                      minRating = tempMinRating;
                                      sortBy = tempSortBy;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    isArabic
                                        ? "تطبيق الفلاتر"
                                        : "Apply Filters",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortChip(
    String currentValue,
    String value,
    String label,
    void Function(void Function()) setModalState,
    void Function(String) onSelect,
  ) {
    final selected = currentValue == value;
    return GestureDetector(
      onTap: () => setModalState(() => onSelect(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFD4A017)
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFD4A017) : cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: selected
                ? Colors.black
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  int get activeFilterCount {
    int count = advancedCategoryFilters.length;
    if (priceRange.start != 0 || priceRange.end != 200) count++;
    if (minRating > 0) count++;
    if (sortBy != 'rating') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        // Floating Action Button to post smart job
        floatingActionButton: FloatingActionButton(
          onPressed: _openAIOrderCreator,
          backgroundColor: const Color(0xFFD4A017),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar is handled by MainShell — nothing here.

                  // Header title
                  Text(
                    isArabic
                        ? "ابحث عن الفن الجميل"
                        : "Explore Beautiful Craft",
                    style: GoogleFonts.arefRuqaa(
                      color: primaryTextColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabic
                        ? "تواصل مع أمهر الحرفيين في منطقتك"
                        : "Connect with the finest local craftsmen",
                    style: TextStyle(color: secondaryTextColor, fontSize: 14.5),
                  ),
                  const SizedBox(height: 20),

                  // Search Bar + Advanced Filter Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            style: TextStyle(color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: isArabic
                                  ? "ابحث عن حرفة أو حرفي..."
                                  : "Search for a craft or craftsman...",
                              hintStyle: TextStyle(
                                color: secondaryTextColor.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: secondaryTextColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Advanced search / filter button with a badge showing active filter count
                      GestureDetector(
                        onTap: _openAdvancedSearch,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: activeFilterCount > 0
                                    ? const Color(0xFFD4A017)
                                    : (isDarkMode
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black.withValues(
                                              alpha: 0.02,
                                            )),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: activeFilterCount > 0
                                      ? const Color(0xFFD4A017)
                                      : cardBorderColor,
                                ),
                              ),
                              child: Icon(
                                Icons.tune,
                                color: activeFilterCount > 0
                                    ? Colors.black
                                    : topIconColor,
                              ),
                            ),
                            if (activeFilterCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    "$activeFilterCount",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Categories Filter Chips Row
                  SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected =
                            selectedFilterIndex == index ||
                            (selectedFilterIndex == null && index == 0);
                        return _buildCategoryChip(
                          icon: cat["icon"],
                          title: isArabic ? cat["titleAr"] : cat["titleEn"],
                          isSelected: isSelected,
                          index: index,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Section 1: Featured Craftsmen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? "أبرز الحرفيين" : "Featured Craftsmen",
                        style: GoogleFonts.arefRuqaa(
                          color: primaryTextColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isArabic ? "الكل" : "View All",
                        style: const TextStyle(
                          color: Color(0xFFD4A017),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Horizontal list of craftsmen
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: craftsmen.length,
                      itemBuilder: (context, index) {
                        final maker = craftsmen[index];
                        return _buildCraftsmanCard(
                          name: isArabic ? maker["nameAr"] : maker["nameEn"],
                          craft: isArabic ? maker["craftAr"] : maker["craftEn"],
                          rating: maker["rating"],
                          jobs: maker["jobs"],
                          imagePath: maker["image"],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Section 2: Products (Popular / New / Recommended)
                  Text(
                    isArabic ? "المنتجات" : "Products",
                    style: GoogleFonts.arefRuqaa(
                      color: primaryTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tab switcher
                  Row(
                    children: [
                      _buildProductTab(
                        0,
                        isArabic ? "الأكثر طلباً" : "Popular",
                      ),
                      const SizedBox(width: 10),
                      _buildProductTab(1, isArabic ? "جديد" : "New"),
                      const SizedBox(width: 10),
                      _buildProductTab(2, isArabic ? "موصى به" : "Recommended"),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Product grid — wrapped in a non-scrollable GridView since the
                  // parent is already a SingleChildScrollView (lets the whole
                  // page, search bar and all, scroll together).
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductTab(int index, String title) {
    final isSelected = productTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => productTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A017)
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4A017) : cardBorderColor,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.black
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.5),
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder — swap for Image.asset/Image.network once
          // real product photos are available.
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A017).withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Icon(
                  product["icon"],
                  size: 34,
                  color: const Color(0xFFD4A017),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? product["nameAr"] : product["nameEn"],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${product["price"].toStringAsFixed(0)} JOD",
                      style: const TextStyle(
                        color: Color(0xFFD4A017),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF7B500),
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          product["rating"],
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required IconData icon,
    required String title,
    required bool isSelected,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilterIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A017)
              : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4A017) : cardBorderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.black
                  : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.black
                    : (isDarkMode ? Colors.white70 : Colors.black87),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCraftsmanCard({
    required String name,
    required String craft,
    required String rating,
    required String jobs,
    required String imagePath,
  }) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(left: 16, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorderColor, width: 1.5),
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(imagePath, fit: BoxFit.cover),
                ),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      craft,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFD4A017),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Rating and jobs count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF7B500),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "$jobs ${isArabic ? 'طلب' : 'Jobs'}",
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
}
