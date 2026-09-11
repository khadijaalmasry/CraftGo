import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'artisan_profile_page.dart';
import 'order_confirmation_screen.dart';
import 'ai_chatbot_screen.dart' as import_chat;
import '../../services/api_service.dart';
import '../../services/products_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProductDetailsPage
//
// Receives a product Map from the dashboard. When real API data arrives,
// swap the Map for a typed Product model — the UI doesn't need to change.
//
// Sections:
//   • Image carousel (dots indicator)
//   • Title, price, rating
//   • Artisan shortcut card  → taps to ArtisanProfilePage
//   • Category chips
//   • Description
//   • Offer type badge  (ready-made / custom / hire)
//   • Quantity selector  (for ready-made)
//   • Delivery info row
//   • Sticky bottom bar  (Add to Cart + Buy Now)
// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isArabic;
  final bool isDarkMode;
  final bool isGuest;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.isArabic,
    required this.isDarkMode,
    this.isGuest = false,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late bool isArabic;
  late bool isDarkMode;

  int _carouselIndex = 0;
  int _quantity = 1;
  bool _inWishlist = false;

  final PageController _pageController = PageController();  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;

    // Register a real product view when this page opens.
    // Guests are skipped because interactions require authentication.
    if (!widget.isGuest) {
      _registerProductView();
    }
  }

  Future<void> _registerProductView() async {
    final productId = widget.product['id']?.toString();

    if (productId == null || productId.isEmpty || productId == 'null') {
      debugPrint('View interaction skipped: missing product id');
      return;
    }

    try {
      await ApiService.post('/interactions', body: {
        'productId': productId,
        'interactionType': 'view',
      });
      debugPrint('View interaction registered for product: $productId');
    } catch (e) {
      // Tracking failure must not stop the product page from opening.
      debugPrint('Error registering product view: $e');
    }
  }

  void _toggleWishlist() async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }
    setState(() => _inWishlist = !_inWishlist);
    try {
      await ApiService.post('/interactions', body: {
        'productId': widget.product['id'].toString(),
        'interactionType': 'like',
      });
    } catch (e) {
      debugPrint('Error wishlist: $e');
    }
  }

  void _addToCart() async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }
    try {
      for (int i = 0; i < _quantity; i++) {
        await ApiService.post('/interactions', body: {
          'productId': widget.product['id'].toString(),
          'interactionType': 'cart',
        });
      }
      _showSnack(t('تمت الإضافة للسلة', 'Added to cart'));
    } catch (e) {
      debugPrint('Error cart: $e');
      _showSnack(t('حدث خطأ', 'Error occurred'));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _gold = Color(0xFFD4A017);
  static const Color _navy = Color(0xFF0D1B33);

  Color get bg =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black45;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.07);
  Color get accent => isDarkMode ? _gold : _navy;
  Color get imgBg =>
      isDarkMode ? const Color(0xFF1C2431) : const Color(0xFFEEEEF2);

  String t(String ar, String en) => isArabic ? ar : en;

  String _localizedValue(String raw) {
    final value = raw.trim();
    final key = value.toLowerCase();
    const arToEn = {
      'زجاج': 'Glass', 'قماش': 'Fabric', 'خيط': 'Thread', 'خشب': 'Wood', 'طين': 'Clay',
      'فخار': 'Pottery', 'سيراميك': 'Ceramic', 'معدن': 'Metal', 'جلد': 'Leather', 'ورق': 'Paper',
      'حجر': 'Stone', 'راتنج': 'Resin', 'نحاس': 'Copper', 'خياطة': 'Sewing', 'تطريز': 'Embroidery',
      'كروشيه': 'Crochet', 'أحمر': 'Red', 'أصفر': 'Yellow', 'أزرق': 'Blue', 'أبيض': 'White',
      'أسود': 'Black', 'بني': 'Brown', 'بيج': 'Beige', 'أخضر': 'Green',
    };
    const enToAr = {
      'glass': 'زجاج', 'fabric': 'قماش', 'thread': 'خيط', 'wood': 'خشب', 'clay': 'طين',
      'pottery': 'فخار', 'ceramic': 'سيراميك', 'metal': 'معدن', 'leather': 'جلد', 'paper': 'ورق',
      'stone': 'حجر', 'resin': 'راتنج', 'copper': 'نحاس', 'sewing': 'خياطة',
      'embroidery': 'تطريز', 'crochet': 'كروشيه', 'handmade': 'عمل يدوي', 'red': 'أحمر',
      'yellow': 'أصفر', 'blue': 'أزرق', 'white': 'أبيض', 'black': 'أسود', 'brown': 'بني',
      'beige': 'بيج', 'green': 'أخضر',
    };
    return isArabic ? (enToAr[key] ?? value) : (arToEn[value] ?? value);
  }

  Future<void> _buyNow() async {
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t('معلومات الطلب والتوصيل', 'Order & Delivery Information'),
          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(
                  'يرجى إدخال عنوان التوصيل ورقم الهاتف. سيتم إرسال الطلب إلى الحرفي للمراجعة قبل الدفع.',
                  'Please enter your delivery address & phone number. Your order will be sent to the artisan for review before payment.',
                ),
                style: GoogleFonts.cairo(color: dim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                style: GoogleFonts.cairo(color: text),
                decoration: InputDecoration(
                  labelText: t('عنوان التوصيل', 'Delivery address'),
                  labelStyle: GoogleFonts.cairo(color: dim),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.location_on_outlined, color: accent),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? t('يرجى إدخال عنوان التوصيل', 'Please enter delivery address')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.cairo(color: text),
                decoration: InputDecoration(
                  labelText: t('رقم الهاتف', 'Customer Phone Number'),
                  labelStyle: GoogleFonts.cairo(color: dim),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.phone_outlined, color: accent),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? t('يرجى إدخال رقم الهاتف', 'Please enter phone number')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(t('إرسال الطلب', 'Place Order'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    final address = addressController.text.trim();
    final phone = phoneController.text.trim();

    if (confirmed != true || !mounted) {
      addressController.dispose();
      phoneController.dispose();
      return;
    }

    try {
      _showSnack(t('جاري إرسال الطلب...', 'Sending order request...'));
      final created = await ProductsService.createCheckoutOrders(
        items: [{
          'productId': widget.product['id'].toString(),
          'quantity': _quantity,
          'buyNow': true,
        }],
        deliveryAddress: address,
        customerPhone: phone,
      );

      final orders = List<Map<String, dynamic>>.from(
        (created?['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      if (orders.isEmpty) throw Exception('Order was not created');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderConfirmationScreen(
                  isArabic: isArabic,
                  isDarkMode: isDarkMode,
                  orders: orders,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) _showSnack(t('تعذر إنشاء الطلب: $e', 'Could not create order: $e'));
    } finally {
      addressController.dispose();
      phoneController.dispose();
    }
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
            border: Border.all(
              color: widget.isDarkMode ? Colors.white12 : Colors.black12,
            ),
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
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFD4A017),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isArabic ? "ميزة للأعضاء فقط" : "Members Only Feature",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isArabic
                    ? "يرجى تسجيل الدخول لاستخدام هذه الميزة والاستمتاع بجميع خدماتنا."
                    : "Please log in to use this feature and enjoy all our services.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A017),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    widget.isArabic ? "حسناً، فهمت" : "Got it",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.black : Colors.white,
                    ),
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

  String _firstText(Iterable<dynamic> values, [String fallback = '']) {
    for (final value in values) {
      final result = value?.toString().trim() ?? '';
      if (result.isNotEmpty && result.toLowerCase() != 'null') return result;
    }
    return fallback;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<String> _list(dynamic value) {
    if (value is Map) {
      final text = _firstText([
        value['nameEn'], value['nameAr'], value['name'], value['titleEn'],
        value['titleAr'], value['title'],
      ]);
      return text.isEmpty ? <String>[] : <String>[text];
    }
    if (value is List) {
      return value
          .map((e) => e is Map
          ? _firstText([e['nameEn'], e['nameAr'], e['name'], e['title']])
          : e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return [];
    return text
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((e) => e.replaceAll('"', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> get _images {
    final p = widget.product;
    final result = <String>[];
    void add(dynamic value) {
      final url = value is Map
          ? _firstText([value['url'], value['imageUrl'], value['secure_url'], value['path']])
          : _firstText([value]);
      if (url.isNotEmpty && !result.contains(url)) result.add(url);
    }

    for (final value in [
      p['imageUrl'], p['imageURL'], p['image'], p['productImage'],
      p['thumbnailUrl'], p['thumbnail'],
    ]) {
      add(value);
    }
    final multiple = p['images'] ?? p['imageUrls'] ?? p['Images'];
    if (multiple is List) {
      for (final value in multiple) add(value);
    }
    return result;
  }

  Map<String, dynamic> get _artisan {
    final p = widget.product;
    final nested = p['artisan'] ?? p['Artisan'] ?? p['craftsman'] ??
        p['Craftsman'] ?? p['User'] ?? p['user'];
    return _map(nested);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final nameAr = _firstText([p['titleAr'], p['nameAr'], p['title'], p['name']]);
    final nameEn = _firstText([p['titleEn'], p['nameEn'], p['title'], p['name'], nameAr], 'Handmade Product');
    final name = t(nameAr.isEmpty ? nameEn : nameAr, nameEn);
    final price = double.tryParse((p['price'] ?? p['productPrice'] ?? p['amount'] ?? 0).toString()) ?? 0.0;
    final rating = _firstText([p['rating'], p['averageRating'], p['avgRating']], '—');
    final descriptionAr = _firstText([p['descriptionAr'], p['description'], p['detailsAr']]);
    final descriptionEn = _firstText([p['descriptionEn'], p['description'], p['detailsEn'], descriptionAr], 'No description available.');
    final categories = _list(p['categories'] ?? p['category'] ?? p['categoryEn'] ?? p['categoryAr']);
    final materials = _list(p['materials'] ?? p['material']);
    final colors = _list(p['colors'] ?? p['color']);
    final artisan = _artisan;
    final artisanNameAr = _firstText([artisan['nameAr'], artisan['name'], artisan['fullName']]);
    final artisanNameEn = _firstText([artisan['nameEn'], artisan['name'], artisan['fullName'], artisanNameAr], 'Artisan');
    final artisanCraftAr = _firstText([artisan['primaryCategoryAr'], artisan['craftAr'], artisan['categoryAr']]);
    final artisanCraftEn = _firstText([artisan['primaryCategoryEn'], artisan['craftEn'], artisan['categoryEn'], artisan['primaryCategory']], 'Handcrafts');
    final artisanStats = _map(artisan['stats'] ?? artisan['Stats']);
    final artisanRating = _firstText([
      artisanStats['rating'], artisanStats['averageRating'], artisan['rating'],
      artisan['averageRating'], p['artisanRating'], rating,
    ], '—');
    final artisanImage = _firstText([artisan['profileImage'], artisan['profileImageUrl'], artisan['avatarUrl'], artisan['imageUrl'], artisan['image']]);
    final city = _firstText([artisan['city'], p['city']], 'Nablus');
    final images = _images;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,

        // ── Sticky bottom bar ──────────────────────────────────────────────
        bottomNavigationBar: _BottomBar(
          accent: accent,
          text: text,
          surface: surface,
          border: border,
          isArabic: isArabic,
          price: price,
          quantity: _quantity,
          onAddToCart: _addToCart,
          onBuyNow: widget.isGuest ? _showGuestPrompt : _buyNow,
        ),

        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SliverAppBar with image carousel ────────────────────────
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: surface,
              leading: _CircleBtn(
                icon: isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                onTap: () => Navigator.pop(context),
                bg: surface,
                iconColor: text,
                border: border,
              ),
              actions: [
                _CircleBtn(
                  icon: _inWishlist
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onTap: _toggleWishlist,
                  bg: surface,
                  iconColor: _inWishlist ? Colors.redAccent : text,
                  border: border,
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Image PageView
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.isEmpty ? 1 : images.length,
                      onPageChanged: (i) => setState(() => _carouselIndex = i),
                      itemBuilder: (_, i) {
                        if (images.isEmpty) {
                          return Container(
                            color: imgBg,
                            alignment: Alignment.center,
                            child: Icon(Icons.inventory_2_outlined,
                                size: 100, color: accent.withValues(alpha: 0.5)),
                          );
                        }
                        final imageUrl = images[i];
                        final isNetwork = imageUrl.startsWith('http://') ||
                            imageUrl.startsWith('https://') ||
                            imageUrl.startsWith('blob:') ||
                            imageUrl.startsWith('data:');
                        return Container(
                          color: imgBg,
                          child: isNetwork
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 80, color: accent.withValues(alpha: 0.5)),
                            ),
                          )
                              : Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 80, color: accent.withValues(alpha: 0.5)),
                            ),
                          ),
                        );
                      },
                    ),
                    // Dots indicator
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.isEmpty ? 1 : images.length,
                              (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _carouselIndex ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _carouselIndex
                                  ? accent
                                  : accent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body content ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title + rating row ──────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.arefRuqaa(
                              color: text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${price.toStringAsFixed(0)} JOD',
                              style: TextStyle(
                                color: accent,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF7B500),
                                  size: 15,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ── Offer type badge ────────────────────────────────
                    Row(
                      children: [
                        _OfferBadge(
                          type: 'ready_made',
                          isArabic: isArabic,
                          accent: accent,
                        ),
                        const SizedBox(width: 8),
                        // ── Eco-Friendly AI Score ──────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.handyman_outlined, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                t('منتج يدوي أصيل', 'Authentic Handmade'),
                                style: GoogleFonts.cairo(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── AR & AI Negotiator Buttons ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showProductPreview(context),
                            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                            label: Text(
                              t('معاينة المنتج', 'Preview Product'),
                              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.isGuest ? _showGuestPrompt : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => import_chat.AiChatbotScreen(
                                    isArabic: isArabic,
                                    isDarkMode: isDarkMode,
                                    productName: name,
                                    productPrice: price,
                                    productId: p['id'].toString(),
                                    quantity: _quantity,
                                    productIcon: p['icon'] is IconData
                                        ? p['icon'] as IconData
                                        : null,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.support_agent, color: Colors.black87, size: 20),
                            label: Text(
                              t('فاوض السعر', 'Negotiate Price'),
                              style: GoogleFonts.cairo(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Artisan shortcut ────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtisanProfilePage(
                            artisan: artisan,
                            isArabic: isArabic,
                            isDarkMode: isDarkMode,
                            isGuest: widget.isGuest,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: accent.withValues(alpha: 0.2),
                              backgroundImage: artisanImage.isEmpty
                                  ? null
                                  : ((artisanImage.startsWith('http://') ||
                                  artisanImage.startsWith('https://'))
                                  ? NetworkImage(artisanImage)
                                  : AssetImage(artisanImage))
                              as ImageProvider<Object>,
                              child: artisanImage.isEmpty
                                  ? Text(
                                (isArabic ? artisanNameAr : artisanNameEn)
                                    .trim()
                                    .isEmpty
                                    ? '?'
                                    : (isArabic ? artisanNameAr : artisanNameEn)
                                    .trim()[0]
                                    .toUpperCase(),
                                style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold),
                              )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(artisanNameAr.isEmpty ? artisanNameEn : artisanNameAr, artisanNameEn),
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t(artisanCraftAr.isEmpty ? artisanCraftEn : artisanCraftAr, artisanCraftEn),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF7B500),
                                  size: 13,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  artisanRating,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: dim,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Category chips ──────────────────────────────────
                    Text(
                      t('الفئة', 'Category'),
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (categories.isEmpty ? <String>['Handmade'] : categories)
                          .map((category) => _Chip(
                        label: _localizedValue(category),
                        accent: accent,
                        surface: surface,
                        border: border,
                        text: text,
                      ))
                          .toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Description ─────────────────────────────────────
                    Text(
                      t('الوصف', 'Description'),
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(descriptionAr.isEmpty ? descriptionEn : descriptionAr, descriptionEn),
                      style: TextStyle(
                        color: dim,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),

                    if (materials.isNotEmpty || colors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      if (materials.isNotEmpty) ...[
                        Text(t('الخامات', 'Materials'),
                            style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: materials
                              .map((value) => _Chip(label: _localizedValue(value), accent: accent, surface: surface, border: border, text: text))
                              .toList(),
                        ),
                      ],
                      if (colors.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(t('الألوان', 'Colors'),
                            style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: colors
                              .map((value) => _Chip(label: _localizedValue(value), accent: accent, surface: surface, border: border, text: text))
                              .toList(),
                        ),
                      ],
                    ],

                    const SizedBox(height: 20),

                    // ── Delivery info ───────────────────────────────────
                    Text(
                      t('معلومات التوصيل', 'Delivery Info'),
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.local_shipping_outlined,
                            label: t('وقت التوصيل', 'Delivery Time'),
                            value: t('٣–٥ أيام عمل', '3–5 business days'),
                            text: text,
                            dim: dim,
                            accent: accent,
                          ),
                          Divider(height: 18, color: border),
                          _InfoRow(
                            icon: Icons.shield_outlined,
                            label: t('ضمان الدفع', 'Payment Guarantee'),
                            value: t(
                              'محمي بنظام الضمان',
                              'Protected by escrow',
                            ),
                            text: text,
                            dim: dim,
                            accent: accent,
                          ),
                          Divider(height: 18, color: border),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: t('الشحن من', 'Ships from'),
                            value: isArabic ? '$city، فلسطين' : '$city, Palestine',
                            text: text,
                            dim: dim,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Quantity selector ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('الكمية', 'Quantity'),
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _QuantitySelector(
                          value: _quantity,
                          accent: accent,
                          surface: surface,
                          border: border,
                          text: text,
                          onChanged: (v) => setState(() => _quantity = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProductPreview(BuildContext context) {
    if (_images.isEmpty) {
      _showSnack(t('لا توجد صورة لمعاينتها', 'No product image to preview'));
      return;
    }
    var selected = 0;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog.fullscreen(
          backgroundColor: const Color(0xFF080D15),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          t('معاينة المنتج', 'Product Preview'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Center(child: _previewImage(_images[selected])),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  color: const Color(0xFF151E2B),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pinch_outlined, color: Color(0xFFD4A017), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            t('قرّب بإصبعين واسحب لفحص التفاصيل', 'Pinch to zoom and drag to inspect details'),
                            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      if (_images.length > 1) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            itemCount: _images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) => GestureDetector(
                              onTap: () => setDialogState(() => selected = index),
                              child: Container(
                                width: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected == index ? accent : Colors.white24,
                                    width: selected == index ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _previewImage(_images[index], fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewImage(String source, {BoxFit fit = BoxFit.contain}) {
    final isNetwork = source.startsWith('http://') || source.startsWith('https://') ||
        source.startsWith('data:') || source.startsWith('blob:');
    final fallback = Icon(Icons.inventory_2_outlined, size: 100, color: accent);
    return isNetwork
        ? Image.network(source, fit: fit, errorBuilder: (_, __, ___) => fallback)
        : Image.asset(source, fit: fit, errorBuilder: (_, __, ___) => fallback);
  }

  // Kept only to avoid breaking old hot-reload frames; it is no longer used.
  void _showLegacyARSimulation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            height: 500,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5), width: 2),
              image: const DecorationImage(
                image: AssetImage('assets/images/camera_bg.jpg'), // Placeholder or just black
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simulating a 3D object in space
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: _images.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(80),
                        child: Image.network(
                          _images.first,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            size: 120,
                            color: Color(0xFFD4A017),
                          ),
                        ),
                      )
                          : const Icon(
                        Icons.inventory_2_outlined,
                        size: 120,
                        color: Color(0xFFD4A017),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'اسحب لتحريك المنتج' : 'Swipe to rotate',
                            style: GoogleFonts.cairo(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // AR scan lines
                Positioned(
                  bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isArabic ? 'جاري قياس الأبعاد (AR)...' : 'Measuring room (AR)...',
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg, iconColor, border;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.iconColor,
    required this.border,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    ),
  );
}

class _OfferBadge extends StatelessWidget {
  final String type;
  final bool isArabic;
  final Color accent;
  const _OfferBadge({
    required this.type,
    required this.isArabic,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) {
    final labels = {
      'ready_made': isArabic ? '✓ متاح للشراء الفوري' : '✓ Ready to ship',
      'custom': isArabic ? '✏️ طلب مخصص' : '✏️ Custom order',
      'hire': isArabic ? '📍 خدمة في الموقع' : '📍 On-site service',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        labels[type] ?? '',
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color accent, surface, border, text;
  const _Chip({
    required this.label,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color text, dim, accent;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.text,
    required this.dim,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: accent),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: TextStyle(color: dim, fontSize: 13)),
      ),
      Text(
        value,
        style: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QuantitySelector extends StatelessWidget {
  final int value;
  final Color accent, surface, border, text;
  final ValueChanged<int> onChanged;
  const _QuantitySelector({
    required this.value,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QBtn(
          icon: Icons.remove,
          onTap: () {
            if (value > 1) onChanged(value - 1);
          },
          accent: accent,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$value',
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _QBtn(
          icon: Icons.add,
          onTap: () => onChanged(value + 1),
          accent: accent,
        ),
      ],
    ),
  );
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  const _QBtn({required this.icon, required this.onTap, required this.accent});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(icon, size: 18, color: accent),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  final Color accent, text, surface, border;
  final bool isArabic;
  final double price;
  final int quantity;
  final VoidCallback onAddToCart, onBuyNow;
  const _BottomBar({
    required this.accent,
    required this.text,
    required this.surface,
    required this.border,
    required this.isArabic,
    required this.price,
    required this.quantity,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: BoxDecoration(
      color: surface,
      border: Border(top: BorderSide(color: border)),
    ),
    child: Row(
      children: [
        // Add to Cart
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onAddToCart,
            icon: Icon(Icons.shopping_cart_outlined, size: 18, color: accent),
            label: Text(
              t('أضف للسلة', 'Add to Cart'),
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Buy Now
        Expanded(
          child: ElevatedButton(
            onPressed: onBuyNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              '${t('شراء', 'Buy')}  •  ${(price * quantity).toStringAsFixed(0)} JOD',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
