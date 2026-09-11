import 'dart:async';
import 'dart:ui';
import 'product_details_page.dart';
import 'artisan_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'search_results_screen.dart';
import 'gift_quiz_screen.dart';
import '../../services/customer_service.dart';
import '../../services/exhibitions_service.dart';
import '../customer/customer_explore_exhibitions.dart';
import 'customer_exhibition_detail_screen.dart';

class ClientDashboard extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final bool isGuest;

  const ClientDashboard({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    this.isGuest = false,
  });

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  late bool isArabic;
  late bool isDarkMode;

  // Selected filter category (null means "All")
  int? selectedFilterIndex;

  // ---- Advanced search / filter state ----
  Set<int> advancedCategoryFilters = {};
  Set<String> materialFilters = {};
  Set<String> craftFilters = {};
  RangeValues priceRange = const RangeValues(0, 200);
  double minRating = 0;
  String sortBy = 'rating';
  String? deliveryTime;
  bool ecoFriendly = false;

  // ---- Products section state ----
  int productTabIndex = 0;

  // ---- Search state ----
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  // ---- Real Data State ----
  List<dynamic> _realCraftsmen = [];
  List<dynamic> _realProducts = [];
  List<dynamic> _realExhibitions = [];
  bool _isLoadingCraftsmen = true;
  bool _isLoadingProducts = true;
  bool _isLoadingExhibitions = true;
  String? _craftsmenError;
  String? _productsError;
  final Set<String> _favoriteProductIds = <String>{};
  final Set<String> _addingToCartIds = <String>{};
  final Set<String> _cartProductIds = <String>{};

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchTopArtisans(),
      _fetchProducts(),
      _fetchExhibitions(),
    ]);
  }

  Future<void> _fetchExhibitions() async {
    try {
      final list = await ExhibitionsService.getAllExhibitions();
      if (!mounted) return;

      final now = DateTime.now();
      // Keep only exhibitions that are active or upcoming
      final filtered = list.where((item) {
        final start = DateTime.tryParse(item['startDate']?.toString() ?? '');
        final end = DateTime.tryParse(item['endDate']?.toString() ?? '');
        if (start == null || end == null) return false;
        // Keep if the exhibition hasn't ended yet (end is today or in future)
        return end.isAfter(now) || end.isAtSameMomentAs(now);
      }).toList();

      setState(() {
        _realExhibitions = filtered;
        _isLoadingExhibitions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingExhibitions = false);
    }
  }

  Future<void> _fetchTopArtisans() async {
    if (mounted) {
      setState(() {
        _isLoadingCraftsmen = true;
        _craftsmenError = null;
      });
    }

    try {
      final list = await CustomerService.fetchTopArtisans();
      if (!mounted) return;
      setState(() {
        _realCraftsmen = list;
        _isLoadingCraftsmen = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _realCraftsmen = [];
        _isLoadingCraftsmen = false;
        _craftsmenError = e.toString();
      });
    }
  }

  Future<void> _fetchProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _productsError = null;
      });
    }

    String? sortQuery;
    if (productTabIndex == 0) {
      sortQuery = 'most_liked';
    } else if (productTabIndex == 1) {
      sortQuery = 'new';
    } else if (productTabIndex == 2) {
      sortQuery = 'recommended';
    }

    String? categoryQuery;
    if (selectedFilterIndex != null) {
      final cat = categories[selectedFilterIndex!];
      final value = isArabic ? cat['titleAr'] : cat['titleEn'];
      if (value != 'الكل' && value != 'لك' && value != 'For You') {
        categoryQuery = value?.toString();
      }
    }

    try {
      final result = await CustomerService.fetchProductsWithState(
        category: categoryQuery,
        sort: sortBy == 'rating' ? sortQuery : sortBy,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        materials: materialFilters.toList(),
        crafts: craftFilters.toList(),
        minPrice: priceRange.start,
        maxPrice: priceRange.end,
        minRating: minRating,
        deliveryTime: deliveryTime,
        ecoFriendly: ecoFriendly,
      );

      if (!mounted) return;
      setState(() {
        _realProducts = result.products;
        _favoriteProductIds.clear();
        _favoriteProductIds.addAll(result.favoriteIds);
        _cartProductIds.clear();
        _cartProductIds.addAll(result.cartIds);
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _realProducts = [];
        _favoriteProductIds.clear();
        _cartProductIds.clear();
        _isLoadingProducts = false;
        _productsError = error.toString();
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _fetchProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ClientDashboard old) {
    super.didUpdateWidget(old);
    if (old.isArabic != widget.isArabic) {
      setState(() => isArabic = widget.isArabic);
    }
    if (old.isDarkMode != widget.isDarkMode) {
      setState(() => isDarkMode = widget.isDarkMode);
    }
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

  Future<void> _handleVisualSearch() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery); // Or ImageSource.camera

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFD4A017)),
                const SizedBox(height: 16),
                Text(
                  isArabic ? "جاري تحليل الصورة..." : "Analyzing image...",
                  style: TextStyle(color: primaryTextColor),
                ),
              ],
            ),
          ),
        ),
      );

      final result = await CustomerService.visualSearch(imageFile);

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      if (result != null && result["products"] != null) {
        final keywords = (result["keywords"] as List).join(", ");
        final products = result["products"] as List;

        // Navigate to search results with the fetched products
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchResultsScreen(
              query: keywords,
              isArabic: isArabic,
              isDarkMode: isDarkMode,
              isGuest: widget.isGuest,
              initialProducts:
                  products, // Need to add this to SearchResultsScreen later
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isArabic ? "فشل البحث بالصورة" : "Visual search failed")),
        );
      }
    }
  }

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

  // Category filter items (static, NO auto-scroll)
  List<Map<String, dynamic>> get categories => [
        {"icon": Icons.auto_awesome, "titleAr": "لك", "titleEn": "For You"},
        {
          "icon": Icons.new_releases_outlined,
          "titleAr": "جديد",
          "titleEn": "New"
        },
        {
          "icon": Icons.favorite_border,
          "titleAr": "الأكثر إعجاباً",
          "titleEn": "Most Liked"
        },
        {
          "icon": Icons.local_offer_outlined,
          "titleAr": "عروض",
          "titleEn": "Offer"
        },
        {
          "icon": Icons.location_on_outlined,
          "titleAr": "قريب منك",
          "titleEn": "Near You"
        },
      ];

  List<dynamic> get filteredProducts => _realProducts;

  // ── Open Advanced Search / Filters Bottom Sheet ────────────────────
  void _openAdvancedSearch() {
    Set<int> tempCategories = {...advancedCategoryFilters};
    Set<String> tempMaterials = {...materialFilters};
    Set<String> tempCrafts = {...craftFilters};
    RangeValues tempPriceRange = priceRange;
    double tempMinRating = minRating;
    String tempSortBy = sortBy;
    String? tempDeliveryTime = deliveryTime;
    bool tempEcoFriendly = ecoFriendly;

    final materialOptions = [
      'خشب',
      'صوف',
      'قطن',
      'فخار',
      'فضة',
      'ذهب',
      'زجاج',
      'جلد'
    ];
    final craftOptions = [
      'خياطة',
      'تطريز',
      'فخار',
      'خشب',
      'مجوهرات',
      'رسم',
      'نسج'
    ];
    final deliveryOptions = ['1-2 أيام', '3-5 أيام', '5-7 أيام', '7+ أيام'];

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
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
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

                        // ── Categories ──────────────────────────────────
                        _buildFilterSection(
                          title: t('الفئات', 'Categories'),
                          children: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(categories.length, (index) {
                              if (index == 0) return const SizedBox.shrink();
                              final cat = categories[index];
                              final selected = tempCategories.contains(index);
                              return _buildFilterChip(
                                label:
                                    isArabic ? cat["titleAr"] : cat["titleEn"],
                                selected: selected,
                                onTap: () {
                                  setModalState(() {
                                    if (selected) {
                                      tempCategories.remove(index);
                                    } else {
                                      tempCategories.add(index);
                                    }
                                  });
                                },
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Materials ──────────────────────────────────
                        _buildFilterSection(
                          title: t('المواد', 'Materials'),
                          children: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: materialOptions.map((opt) {
                              final selected = tempMaterials.contains(opt);
                              return _buildFilterChip(
                                label: opt,
                                selected: selected,
                                onTap: () {
                                  setModalState(() {
                                    if (selected) {
                                      tempMaterials.remove(opt);
                                    } else {
                                      tempMaterials.add(opt);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Craft types ─────────────────────────────────
                        _buildFilterSection(
                          title: t('نوع الحرفة', 'Craft Type'),
                          children: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: craftOptions.map((opt) {
                              final selected = tempCrafts.contains(opt);
                              return _buildFilterChip(
                                label: opt,
                                selected: selected,
                                onTap: () {
                                  setModalState(() {
                                    if (selected) {
                                      tempCrafts.remove(opt);
                                    } else {
                                      tempCrafts.add(opt);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Delivery time ───────────────────────────────
                        _buildFilterSection(
                          title: t('وقت التوصيل', 'Delivery Time'),
                          children: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: deliveryOptions.map((opt) {
                              final selected = tempDeliveryTime == opt;
                              return _buildFilterChip(
                                label: isArabic ? opt : opt,
                                selected: selected,
                                onTap: () {
                                  setModalState(() {
                                    tempDeliveryTime = selected ? null : opt;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Eco-friendly toggle ─────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.eco, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  t('صديق للبيئة فقط', 'Eco-friendly only'),
                                  style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Switch(
                              value: tempEcoFriendly,
                              onChanged: (v) =>
                                  setModalState(() => tempEcoFriendly = v),
                              activeThumbColor: const Color(0xFFD4A017),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Price range ─────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic ? "نطاق السعر" : "Price Range",
                              style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${tempPriceRange.start.round()} - ${tempPriceRange.end.round()} JOD",
                              style: const TextStyle(
                                  color: Color(0xFFD4A017),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFD4A017),
                            inactiveTrackColor: cardBorderColor,
                            thumbColor: const Color(0xFFD4A017),
                            overlayColor:
                                const Color(0xFFD4A017).withValues(alpha: 0.15),
                          ),
                          child: RangeSlider(
                            min: 0,
                            max: 300,
                            divisions: 60,
                            values: tempPriceRange,
                            onChanged: (values) {
                              setModalState(() => tempPriceRange = values);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Minimum rating ─────────────────────────────
                        Text(
                          isArabic ? "الحد الأدنى للتقييم" : "Minimum Rating",
                          style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
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

                        // ── Sort by ──────────────────────────────────────
                        Text(
                          isArabic ? "الترتيب حسب" : "Sort By",
                          style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _sortChip(
                                tempSortBy,
                                'rating',
                                t("الأعلى تقييماً", "Top Rated"),
                                setModalState,
                                (v) => tempSortBy = v),
                            _sortChip(
                                tempSortBy,
                                'price_low',
                                t("السعر: الأقل", "Price: Low to High"),
                                setModalState,
                                (v) => tempSortBy = v),
                            _sortChip(
                                tempSortBy,
                                'price_high',
                                t("السعر: الأعلى", "Price: High to Low"),
                                setModalState,
                                (v) => tempSortBy = v),
                            _sortChip(
                                tempSortBy,
                                'newest',
                                t("الأحدث", "Newest"),
                                setModalState,
                                (v) => tempSortBy = v),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Action buttons ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: cardBorderColor),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26)),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    tempCategories = {};
                                    tempMaterials = {};
                                    tempCrafts = {};
                                    tempPriceRange = const RangeValues(0, 200);
                                    tempMinRating = 0;
                                    tempSortBy = 'rating';
                                    tempDeliveryTime = null;
                                    tempEcoFriendly = false;
                                  });
                                },
                                child: Text(
                                  isArabic ? "إعادة تعيين" : "Reset",
                                  style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold),
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
                                      Color(0xFFD89A00)
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
                                      materialFilters = tempMaterials;
                                      craftFilters = tempCrafts;
                                      priceRange = tempPriceRange;
                                      minRating = tempMinRating;
                                      sortBy = tempSortBy;
                                      deliveryTime = tempDeliveryTime;
                                      ecoFriendly = tempEcoFriendly;
                                    });
                                    Navigator.pop(context);
                                    _fetchProducts();
                                  },
                                  child: Text(
                                    isArabic
                                        ? "تطبيق الفلاتر"
                                        : "Apply Filters",
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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

  Widget _buildFilterSection(
      {required String title, required Widget children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        children,
      ],
    );
  }

  Widget _buildFilterChip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
              color: selected ? const Color(0xFFD4A017) : cardBorderColor),
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

  Widget _sortChip(
      String currentValue,
      String value,
      String label,
      void Function(void Function()) setModalState,
      void Function(String) onSelect) {
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
              color: selected ? const Color(0xFFD4A017) : cardBorderColor),
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
    int count = advancedCategoryFilters.length +
        materialFilters.length +
        craftFilters.length;
    if (priceRange.start != 0 || priceRange.end != 200) count++;
    if (minRating > 0) count++;
    if (sortBy != 'rating') count++;
    if (deliveryTime != null) count++;
    if (ecoFriendly) count++;
    return count;
  }

  void _showGuestPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4A017).withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Color(0xFFD4A017), size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                isArabic ? "ميزة للأعضاء فقط" : "Members Only Feature",
                style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? "يرجى تسجيل الدخول للاستفادة من هذه الميزة والتواصل مع أمهر الحرفيين."
                    : "Please log in to use this feature and connect with the best craftsmen.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A017),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isArabic ? "حسناً، فهمت" : "Got it",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.black : Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showGiftAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GiftQuizScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }

  String t(String ar, String en) => isArabic ? ar : en;

  String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _productId(Map<String, dynamic> product) =>
      _firstNonEmpty([product['id'], product['_id']]);

  Future<void> _addProductToCart(Map<String, dynamic> product) async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }

    final id = _productId(product);
    if (id.isEmpty || _addingToCartIds.contains(id)) return;

    setState(() => _addingToCartIds.add(id));
    final saved = await CustomerService.addToCart(id);

    if (!mounted) return;
    setState(() {
      _addingToCartIds.remove(id);
      if (saved) {
        _cartProductIds.add(id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? t('تمت إضافة المنتج إلى السلة', 'Product added to cart')
              : t('تعذر إضافة المنتج إلى السلة',
                  'Could not add product to cart'),
        ),
        backgroundColor: saved ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _toggleProductFavorite(
    Map<String, dynamic> product,
  ) async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }

    final id = _productId(product);
    if (id.isEmpty) return;

    final wasFavorite = _favoriteProductIds.contains(id);
    setState(() {
      if (wasFavorite) {
        _favoriteProductIds.remove(id);
      } else {
        _favoriteProductIds.add(id);
      }
    });

    final saved = await CustomerService.setProductFavorite(
      productId: id,
      isFavorite: !wasFavorite,
    );

    if (!saved && mounted) {
      setState(() {
        if (wasFavorite) {
          _favoriteProductIds.add(id);
        } else {
          _favoriteProductIds.remove(id);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تعذر تحديث المفضلة', 'Could not update favorites'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
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
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 14.5),
                    ),
                    const SizedBox(height: 20),

                    // ── Search Bar ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: cardBorderColor, width: 1),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: primaryTextColor),
                              decoration: InputDecoration(
                                hintText: isArabic
                                    ? "ابحث عن منتج أو حرفي..."
                                    : "Search products or craftsmen...",
                                hintStyle: TextStyle(
                                    color: secondaryTextColor.withValues(
                                        alpha: 0.5)),
                                prefixIcon: Icon(Icons.search,
                                    color: secondaryTextColor),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.close,
                                            color: secondaryTextColor,
                                            size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: _onSearchChanged,
                              onSubmitted: (query) {
                                _searchDebounce?.cancel();
                                setState(() => _searchQuery = query);
                                _fetchProducts();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Filter button
                        _SearchActionBtn(
                          icon: Icons.tune,
                          badgeCount: activeFilterCount,
                          color: activeFilterCount > 0
                              ? const Color(0xFFD4A017)
                              : topIconColor,
                          bg: activeFilterCount > 0
                              ? const Color(0xFFD4A017).withValues(alpha: 0.15)
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white),
                          border: activeFilterCount > 0
                              ? const Color(0xFFD4A017)
                              : cardBorderColor,
                          onTap: _openAdvancedSearch,
                        ),
                        const SizedBox(width: 8),
                        // Gift Assistant
                        _SearchActionBtn(
                          icon: Icons.card_giftcard_outlined,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          bg: isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          border: cardBorderColor,
                          onTap: widget.isGuest
                              ? _showGuestPrompt
                              : _showGiftAssistant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── Craft Exhibitions Carousel ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_outlined,
                                color: Color(0xFFD4A017), size: 22),
                            const SizedBox(width: 6),
                            Text(
                              isArabic
                                  ? "المعارض الفنية والتراثية"
                                  : "Craft Exhibitions",
                              style: GoogleFonts.arefRuqaa(
                                color: primaryTextColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CustomerExploreExhibitionsScreen(),
                              ),
                            );
                          },
                          child: Text(
                            isArabic ? "استكشف الكل" : "Explore All",
                            style: const TextStyle(
                                color: Color(0xFFD4A017),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _isLoadingExhibitions
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFD4A017)))
                          : _realExhibitions.isEmpty
                              ? Center(
                                  child: Text(
                                    isArabic
                                        ? "لا توجد معارض قادمة حالياً"
                                        : "No upcoming exhibitions yet",
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _realExhibitions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final ex = Map<String, dynamic>.from(
                                        _realExhibitions[index] as Map);
                                    final exName = isArabic
                                        ? (ex['name'] ?? ex['nameEn'] ?? '')
                                        : (ex['nameEn'] ?? ex['name'] ?? '');
                                    final exLoc = isArabic
                                        ? (ex['location'] ?? ex['city'] ?? '')
                                        : (ex['locationEn'] ??
                                            ex['city'] ??
                                            '');
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CustomerExhibitionDetailScreen(
                                              exhibition: ex,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 260,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDarkMode
                                                ? [
                                                    const Color(0xFF1E2A38),
                                                    const Color(0xFF151D28)
                                                  ]
                                                : [
                                                    Colors.white,
                                                    const Color(0xFFF9F6F0)
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFD4A017)
                                                .withOpacity(0.3),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFD4A017)
                                                            .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    ex['eventType'] ??
                                                        t('معرض', 'Exhibition'),
                                                    style: const TextStyle(
                                                      color: Color(0xFFD4A017),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                const Icon(Icons.star,
                                                    color: Color(0xFFD4A017),
                                                    size: 14),
                                                const SizedBox(width: 2),
                                                const Text('4.9',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                            Text(
                                              exName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.cairo(
                                                color: primaryTextColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on_outlined,
                                                    size: 14,
                                                    color: secondaryTextColor),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    exLoc,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color:
                                                            secondaryTextColor,
                                                        fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 24),

                    // ── Featured Craftsmen ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? "أبرز الحرفيين" : "Featured Craftsmen",
                          style: GoogleFonts.arefRuqaa(
                            color: primaryTextColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isArabic ? "الكل" : "View All",
                          style: const TextStyle(
                              color: Color(0xFFD4A017),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 200,
                      child: _isLoadingCraftsmen
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: const Color(0xFFD4A017)))
                          : _craftsmenError != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_off_outlined,
                                          color: const Color(0xFFD4A017),
                                          size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        t('تعذر تحميل الحرفيين',
                                            'Could not load craftsmen'),
                                        style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 13),
                                      ),
                                      TextButton.icon(
                                        onPressed: _fetchTopArtisans,
                                        icon: const Icon(Icons.refresh,
                                            color: Color(0xFFD4A017), size: 16),
                                        label: Text(
                                            t('إعادة المحاولة', 'Retry'),
                                            style: const TextStyle(
                                                color: Color(0xFFD4A017))),
                                      ),
                                    ],
                                  ),
                                )
                              : _realCraftsmen.isEmpty
                                  ? Center(
                                      child: Text(
                                        isArabic
                                            ? "لا يوجد حرفيون متاحون حالياً"
                                            : "No craftsmen available yet",
                                        style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _realCraftsmen.length,
                                      itemBuilder: (context, index) {
                                        final raw = _realCraftsmen[index];
                                        final maker = raw is Map
                                            ? Map<String, dynamic>.from(raw)
                                            : <String, dynamic>{};
                                        final profile =
                                            maker['ArtisanProfile'] is Map
                                                ? Map<String, dynamic>.from(
                                                    maker['ArtisanProfile'],
                                                  )
                                                : maker['artisanProfile'] is Map
                                                    ? Map<String, dynamic>.from(
                                                        maker['artisanProfile'],
                                                      )
                                                    : <String, dynamic>{};

                                        final name = _firstNonEmpty([
                                          maker['name'],
                                          maker['nameAr'],
                                          maker['nameEn'],
                                        ], fallback: t('حرفي', 'Artisan'));

                                        final craftAr = _firstNonEmpty([
                                          profile['primaryCategoryAr'],
                                          profile['craftAr'],
                                          profile['primaryCategory'],
                                          maker['craftAr'],
                                        ], fallback: 'حرفي');

                                        final craftEn = _firstNonEmpty([
                                          profile['primaryCategoryEn'],
                                          profile['craftEn'],
                                          profile['primaryCategory'],
                                          maker['craftEn'],
                                        ], fallback: 'Artisan');

                                        final imageUrl = _firstNonEmpty([
                                          profile['profileImage'],
                                          maker['profileImage'],
                                          maker['imageUrl'],
                                          maker['image'],
                                        ]);

                                        final rating = _toDouble(
                                          profile['averageRating'] ??
                                              profile['rating'] ??
                                              maker['averageRating'] ??
                                              maker['rating'],
                                        );

                                        final jobs = _toDouble(
                                          profile['completedOrders'] ??
                                              profile['jobsCount'] ??
                                              maker['completedOrders'] ??
                                              maker['jobsCount'],
                                        ).round();

                                        final artisanForPage =
                                            Map<String, dynamic>.from(maker)
                                              ..['nameAr'] =
                                                  maker['nameAr'] ?? name
                                              ..['nameEn'] =
                                                  maker['nameEn'] ?? name
                                              ..['craftAr'] = craftAr
                                              ..['craftEn'] = craftEn
                                              ..['image'] = imageUrl;

                                        return GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ArtisanProfilePage(
                                                isArabic: isArabic,
                                                isDarkMode: isDarkMode,
                                                artisan: artisanForPage,
                                              ),
                                            ),
                                          ),
                                          child: Container(
                                            width: 140,
                                            decoration: BoxDecoration(
                                              color: topButtonBackground,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: cardBorderColor),
                                              boxShadow: [
                                                if (!isDarkMode)
                                                  BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.03),
                                                      blurRadius: 10,
                                                      offset:
                                                          const Offset(0, 4)),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                  child: imageUrl
                                                          .toString()
                                                          .isNotEmpty
                                                      ? Image.network(
                                                          imageUrl,
                                                          height: 100,
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Container(
                                                          height: 100,
                                                          width:
                                                              double.infinity,
                                                          color: const Color(
                                                                  0xFFD4A017)
                                                              .withValues(
                                                                  alpha: 0.10),
                                                          child: const Icon(
                                                            Icons
                                                                .person_outline,
                                                            color: Color(
                                                                0xFFD4A017),
                                                            size: 42,
                                                          ),
                                                        ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: TextStyle(
                                                            color:
                                                                primaryTextColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        isArabic
                                                            ? craftAr
                                                            : craftEn,
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFFD4A017),
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.star,
                                                              color: Color(
                                                                  0xFFD4A017),
                                                              size: 12),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            rating > 0
                                                                ? rating
                                                                    .toStringAsFixed(
                                                                        1)
                                                                : '—',
                                                            style: TextStyle(
                                                                color:
                                                                    primaryTextColor,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          const Spacer(),
                                                          Text(
                                                            isArabic
                                                                ? '$jobs طلب'
                                                                : '$jobs jobs',
                                                            style: TextStyle(
                                                                color:
                                                                    secondaryTextColor,
                                                                fontSize: 10),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                    ),
                    ),
                    const SizedBox(height: 30),

                    // ── Products ────────────────────────────────────────
                    Text(
                      isArabic ? "المنتجات" : "Products",
                      style: GoogleFonts.arefRuqaa(
                        color: primaryTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildProductTab(
                            0, isArabic ? "الأكثر طلباً" : "Popular"),
                        const SizedBox(width: 8),
                        _buildProductTab(1, isArabic ? "جديد" : "New"),
                        const SizedBox(width: 8),
                        _buildProductTab(
                            2, isArabic ? "موصى به" : "Recommended"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingProducts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: const Color(0xFFD4A017),
                          ),
                        ),
                      )
                    else if (_productsError != null)
                      _buildProductsMessage(
                        icon: Icons.cloud_off_outlined,
                        message: t(
                          'تعذر تحميل المنتجات حاليًا',
                          'Products could not be loaded',
                        ),
                        showRetry: true,
                      )
                    else if (filteredProducts.isEmpty)
                      _buildProductsMessage(
                        icon: Icons.inventory_2_outlined,
                        message: t(
                          'لا توجد منتجات مطابقة حاليًا',
                          'No matching products found',
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          // Responsive: more columns on wider screens
                          final int crossAxisCount = width >= 1200
                              ? 5
                              : width >= 900
                                  ? 4
                                  : width >= 600
                                      ? 3
                                      : 2;
                          // Adjust aspect ratio slightly for more columns
                          final double aspectRatio = crossAxisCount >= 4
                              ? 0.72
                              : crossAxisCount == 3
                                  ? 0.70
                                  : 0.68;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: aspectRatio,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final raw = filteredProducts[index];
                              final product = raw is Map
                                  ? Map<String, dynamic>.from(raw)
                                  : <String, dynamic>{};

                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailsPage(
                                      product: product,
                                      isArabic: isArabic,
                                      isDarkMode: isDarkMode,
                                      isGuest: widget.isGuest,
                                    ),
                                  ),
                                ),
                                child: _buildSmallProductCard(product),
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
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
      onTap: () {
        setState(() => productTabIndex = index);
        _fetchProducts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A017)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? const Color(0xFFD4A017) : cardBorderColor),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.black
                : (isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallCraftsmanCard({
    required String name,
    required String craft,
    required String rating,
    required String jobs,
    required String imagePath,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1),
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(imagePath,
                  fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  craft,
                  style: TextStyle(
                      color: const Color(0xFFD4A017),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF7B500), size: 12),
                    const SizedBox(width: 3),
                    Text(rating,
                        style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      "$jobs ${isArabic ? 'طلب' : 'Jobs'}",
                      style: TextStyle(color: secondaryTextColor, fontSize: 9),
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

  Widget _buildProductsMessage({
    required IconData icon,
    required String message,
    bool showRetry = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: topButtonBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFFD4A017)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryTextColor, fontSize: 14),
          ),
          if (showRetry) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchProducts,
              icon: const Icon(
                Icons.refresh,
                color: Color(0xFFD4A017),
              ),
              label: Text(
                t('إعادة المحاولة', 'Retry'),
                style: const TextStyle(color: Color(0xFFD4A017)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallProductCard(Map<String, dynamic> product) {
    final nameAr = _firstNonEmpty([
      product['titleAr'],
      product['nameAr'],
      product['title'],
      product['name'],
    ], fallback: 'منتج');

    final nameEn = _firstNonEmpty([
      product['titleEn'],
      product['nameEn'],
      product['title'],
      product['name'],
      nameAr,
    ], fallback: 'Product');

    final name = isArabic ? nameAr : nameEn;
    final price = _toDouble(product['price']);
    final rating = _toDouble(
      product['averageRating'] ?? product['rating'],
    );
    final imageUrl = _firstNonEmpty([
      product['imageUrl'],
      product['image'],
      product['thumbnail'],
      product['images'] is List && (product['images'] as List).isNotEmpty
          ? (product['images'] as List).first
          : null,
    ]);

    final id = _productId(product);
    final isFavorite = _favoriteProductIds.contains(id);
    final isAdding = _addingToCartIds.contains(id);
    final isInCart = _cartProductIds.contains(id);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFD4A017).withValues(alpha: 0.08),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 38,
                        color: Color(0xFFD4A017),
                      ),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFFD4A017).withValues(alpha: 0.08),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: Color(0xFFD4A017),
                    ),
                  ),
                PositionedDirectional(
                  top: 7,
                  end: 7,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _toggleProductFavorite(product),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: isFavorite ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF7B500),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : '—',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${price.toStringAsFixed(
                        price % 1 == 0 ? 0 : 2,
                      )} JOD',
                      style: const TextStyle(
                        color: Color(0xFFD4A017),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: id.isEmpty || isAdding || isInCart
                        ? null
                        : () => _addProductToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isInCart ? Colors.green : const Color(0xFFD4A017),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: isInCart
                          ? Colors.green.withValues(alpha: 0.8)
                          : const Color(0xFFD4A017).withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: isAdding
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            isInCart
                                ? (isArabic ? 'في السلة' : 'In Cart')
                                : (isArabic ? 'أضف للسلة' : 'Add to Cart'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isInCart ? Colors.white : Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF0D1420).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: cardBorderColor, width: 1.5),
            ),
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? "التعليقات (12)" : "Comments (12)",
                        style: GoogleFonts.cairo(
                            color: primaryTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: secondaryTextColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildCommentRow(
                          "User 1",
                          "8 days ago",
                          isArabic
                              ? "منتج رائع جداً، هل يتوفر لون أزرق؟"
                              : "Nice product, is it available in blue?",
                          true,
                        ),
                        // Mock Smart Reply AI block
                        if (!widget.isGuest)
                          Container(
                            margin: const EdgeInsets.only(
                                top: 8, bottom: 16, right: 40),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      Colors.blueAccent.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome,
                                        color: Colors.blueAccent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      isArabic
                                          ? "الرد الذكي (AI)"
                                          : "Smart Reply (AI)",
                                      style: GoogleFonts.cairo(
                                          color: Colors.blueAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic
                                      ? "نعم يتوفر لون أزرق، يمكنك طلبه من خيارات الألوان."
                                      : "Yes blue is available, you can choose it from the colors option.",
                                  style: GoogleFonts.cairo(
                                      color: primaryTextColor, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: isArabic
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      minimumSize: const Size(60, 26),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: Text(isArabic ? "إرسال" : "Send",
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildCommentRow(
                          "rafa",
                          "7 days ago",
                          isArabic ? "شكراً لك 🤍" : "Thank you 🤍",
                          false,
                        ),
                        // Hidden Comment Example
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.security,
                                  color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                isArabic
                                    ? "تم إخفاء هذا التعليق بواسطة الـ AI لمخالفته الشروط."
                                    : "Comment hidden by AI for violating rules.",
                                style: GoogleFonts.cairo(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFD4A017),
                          child: const Text("U",
                              style: TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: isArabic
                                ? "اكتب تعليقاً..."
                                : "Write a comment...",
                            hintStyle: TextStyle(
                                color: secondaryTextColor, fontSize: 13),
                            filled: true,
                            fillColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            suffixIcon: const Icon(Icons.send,
                                color: Color(0xFFE88A74), size: 18),
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
      },
    );
  }

  Widget _buildCommentRow(
      String user, String time, String text, bool canReply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: Text(user[0].toUpperCase(),
                style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user,
                        style: GoogleFonts.cairo(
                            color: primaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(time,
                        style: GoogleFonts.cairo(
                            color: secondaryTextColor, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(text,
                    style: GoogleFonts.cairo(
                        color: primaryTextColor, fontSize: 13)),
                if (canReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isArabic ? "رد" : "Reply",
                      style: GoogleFonts.cairo(
                          color: const Color(0xFFE88A74),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.favorite_border, color: Colors.grey, size: 14),
        ],
      ),
    );
  }

  void _showStoryViewer(String name, String imageUrl, bool isAdd) {
    if (isAdd) {
      _showStoryCreatorSheet();
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Story Background (mocked as dark container with image)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(imageUrl),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.3),
                              BlendMode.darken))
                      : null,
                ),
                child: Center(
                  child: Text(
                    isArabic ? "قصة من $name" : "Story by $name",
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Close Button
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // AI Shoppable Product Link
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.checkroom, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic
                                  ? "اكتشفه الذكاء الاصطناعي 🤖"
                                  : "AI Detected Product 🤖",
                              style: GoogleFonts.cairo(
                                  color: Colors.purpleAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isArabic
                                  ? "حقيبة جلدية مطرزة"
                                  : "Embroidered Leather Bag",
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "45.0 JOD",
                              style: GoogleFonts.cairo(
                                  color: const Color(0xFFD4A017), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE88A74),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isArabic ? "شراء" : "Buy",
                            style: GoogleFonts.cairo(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStoryCreatorSheet() {
    int selectedType = 0; // 0=product, 1=offer, 2=behind scenes
    bool captionGenerated = false;
    final List<String> typeLabelsAr = ['منتج جديد', 'عرض خاص', 'وراء الكواليس'];
    final List<String> typeLabelsEn = [
      'New Product',
      'Special Offer',
      'Behind the Scenes'
    ];
    final List<IconData> typeIcons = [
      Icons.inventory_2_outlined,
      Icons.local_offer_outlined,
      Icons.videocam_outlined
    ];
    final List<String> aiCaptionsAr = [
      '✨ أطلّت بإبداع جديد! هذا المنتج اليدوي نُسِج بحب وشغف، ليحمل قصة فريدة بين يديك. 🧵 #حرف_يدوية #صنع_بحب',
      '🔥 عرض لا يُفوّت! احجز الآن واستمتع بخصم رائع على أجمل منتجاتنا اليدوية المميزة ✂️ #عروض #خصومات',
      '🎬 وراء كل تحفة فنية، جهد وإبداع. هذه لمحة من عملي اليومي لأقدم لكم أجمل ما صنعته يداي 🤲 #خلف_الكواليس',
    ];
    final List<String> aiCaptionsEn = [
      '✨ A new creation just dropped! This handcrafted piece was made with love and passion 🧵 #handmade #craftwork',
      '🔥 Limited time offer! Grab amazing deals on our finest handmade products ✂️ #sale #deals',
      '🎬 Behind every masterpiece is hard work. Here is a peek into my daily creative process 🤲 #behindthescenes',
    ];
    final List<String> bestTimesAr = [
      '6:00 - 8:00 م (أعلى تفاعل)',
      '12:00 - 1:00 م',
      '9:00 - 10:00 ص'
    ];
    final List<String> bestTimesEn = [
      '6:00 - 8:00 PM (Peak engagement)',
      '12:00 - 1:00 PM',
      '9:00 - 10:00 AM'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF0D1420).withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Directionality(
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.auto_awesome,
                                    color: Colors.purpleAccent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isArabic
                                    ? 'منشئ القصص الذكي'
                                    : 'AI Story Creator',
                                style: GoogleFonts.cairo(
                                    color: primaryTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: secondaryTextColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Story Type Selector
                      Text(
                        isArabic ? 'نوع القصة' : 'Story Type',
                        style: GoogleFonts.cairo(
                            color: secondaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(3, (i) {
                          final sel = selectedType == i;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                selectedType = i;
                                captionGenerated = false;
                              }),
                              child: Container(
                                margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.purpleAccent
                                          .withValues(alpha: 0.15)
                                      : (isDarkMode
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black
                                              .withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel
                                          ? Colors.purpleAccent
                                          : cardBorderColor),
                                ),
                                child: Column(
                                  children: [
                                    Icon(typeIcons[i],
                                        color: sel
                                            ? Colors.purpleAccent
                                            : secondaryTextColor,
                                        size: 20),
                                    const SizedBox(height: 4),
                                    Text(
                                      isArabic
                                          ? typeLabelsAr[i]
                                          : typeLabelsEn[i],
                                      style: GoogleFonts.cairo(
                                          color: sel
                                              ? Colors.purpleAccent
                                              : secondaryTextColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      // AI Caption Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              setModalState(() => captionGenerated = true),
                          icon: const Icon(Icons.auto_awesome,
                              color: Colors.white, size: 16),
                          label: Text(
                            isArabic
                                ? 'اكتب لي النص بالذكاء الاصطناعي 🤖'
                                : 'Generate AI Caption 🤖',
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (captionGenerated) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    Colors.purpleAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome,
                                      color: Colors.purpleAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    isArabic
                                        ? 'النص المقترح'
                                        : 'AI Suggested Caption',
                                    style: GoogleFonts.cairo(
                                        color: Colors.purpleAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isArabic
                                    ? aiCaptionsAr[selectedType]
                                    : aiCaptionsEn[selectedType],
                                style: GoogleFonts.cairo(
                                    color: primaryTextColor,
                                    fontSize: 13,
                                    height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD4A017).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFD4A017)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule,
                                  color: Color(0xFFD4A017), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? '⏰ أفضل وقت للنشر اليوم'
                                          : '⏰ Best Time to Post Today',
                                      style: GoogleFonts.cairo(
                                          color: const Color(0xFFD4A017),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      isArabic
                                          ? bestTimesAr[selectedType]
                                          : bestTimesEn[selectedType],
                                      style: GoogleFonts.cairo(
                                          color: primaryTextColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      isArabic
                                          ? '✅ تم نشر القصة بنجاح!'
                                          : '✅ Story published successfully!',
                                      style: GoogleFonts.cairo()),
                                  backgroundColor: Colors.purpleAccent,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE88A74),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              isArabic
                                  ? 'نشر القصة الآن 🚀'
                                  : 'Publish Story Now 🚀',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStoryCircle(
      {required String imageUrl, required String name, required bool isAdd}) {
    return GestureDetector(
      onTap: () {
        _showStoryViewer(name, imageUrl, isAdd);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAdd ? const Color(0xFFE88A74) : Colors.purpleAccent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: isAdd
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE88A74).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Color(0xFFE88A74), size: 28),
                      )
                    : CircleAvatar(
                        backgroundImage:
                            imageUrl.isNotEmpty ? AssetImage(imageUrl) : null,
                        backgroundColor: Colors.grey.shade300,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: isAdd ? const Color(0xFFE88A74) : secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStoryCircle() {
    return GestureDetector(
      onTap: () => _showLiveCommerceViewer(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: CircleAvatar(
                  backgroundImage: const AssetImage('assets/images/user1.jpg'),
                  backgroundColor: Colors.grey.shade300,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('LIVE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'أمجد الخطيب' : 'Amjad',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveCommerceViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              // Fake live video background
              Positioned.fill(
                child: Image.asset('assets/images/plate.jpg',
                    fit: BoxFit.cover,
                    color: Colors.black45,
                    colorBlendMode: BlendMode.darken),
              ),
              // Top Bar
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    CircleAvatar(
                        backgroundImage:
                            const AssetImage('assets/images/user1.jpg'),
                        radius: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أمجد الخطيب',
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            children: [
                              Icon(Icons.visibility,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('1,204',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              // Product Overlay
              Positioned(
                bottom: 120,
                right: 20,
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Image.asset('assets/images/plate.jpg',
                          height: 80, fit: BoxFit.cover),
                      const SizedBox(height: 4),
                      Text('طقم خشبي',
                          style: GoogleFonts.cairo(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      Text('45 JOD',
                          style: const TextStyle(
                              color: Color(0xFFD4A017),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4A017),
                          minimumSize: const Size(double.infinity, 30),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(isArabic ? 'شراء' : 'Buy',
                            style: GoogleFonts.cairo(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              // Chat Fake
              Positioned(
                bottom: 20,
                left: 20,
                right: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سارة: هل يتوفر بلون آخر؟',
                        style: GoogleFonts.cairo(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('أحمد: عمل رائع!',
                        style: GoogleFonts.cairo(color: Colors.white)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          isArabic ? 'اكتب تعليقاً...' : 'Add a comment...',
                          style: GoogleFonts.cairo(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVoiceAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5)
                  ],
                ),
                child:
                    const Icon(Icons.mic, color: Colors.purpleAccent, size: 60),
              ),
              const SizedBox(height: 30),
              Text(
                isArabic ? 'أنا أستمع...' : 'I am listening...',
                style: GoogleFonts.cairo(
                    color: primaryTextColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                isArabic
                    ? 'جرب أن تقول: "أبحث عن وشاح أحمر هدية لأمي"'
                    : 'Try saying: "I am looking for a red scarf for my mother"',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.cairo(color: secondaryTextColor, fontSize: 14),
              ),
              const SizedBox(height: 30),
              // Animated waveform
              const _AnimatedWaveform(),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform();

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(15, (index) {
            final factor =
                (index % 3 == 0) ? 0.6 : (index % 2 == 0 ? 0.3 : 1.0);
            final currentHeight = 10.0 + (25.0 * _controller.value * factor);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: currentHeight,
              decoration: BoxDecoration(
                color: Colors.purpleAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SearchActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg, border;
  final int badgeCount;
  final VoidCallback onTap;

  const _SearchActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  "$badgeCount",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
