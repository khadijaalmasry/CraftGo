import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/customer_service.dart';
import 'order_confirmation_screen.dart';
import '../../widgets/location_picker_screen.dart';
import '../../services/products_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CartScreen — سلة الشراء
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final String id;
  final String interactionId;
  final String titleAr;
  final String titleEn;
  final String craftsmanAr;
  final String craftsmanEn;
  final String craftsmanId;
  final double price;
  final String? imagePath;
  int quantity;

  CartItem({
    required this.id,
    required this.interactionId,
    required this.titleAr,
    required this.titleEn,
    required this.craftsmanAr,
    required this.craftsmanEn,
    required this.craftsmanId,
    required this.price,
    this.imagePath,
    this.quantity = 1,
  });
}

class RecommendedProduct {
  final String id;
  final String titleAr;
  final String titleEn;
  final String craftsmanName;
  final double price;
  final String? imageUrl;
  final String category;
  final String reason;

  RecommendedProduct({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.craftsmanName,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.reason,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    return RecommendedProduct(
      id: json['id']?.toString() ?? '',
      titleAr: (json['titleAr'] ?? json['title'] ?? '').toString(),
      titleEn: (json['titleEn'] ?? json['title'] ?? '').toString(),
      craftsmanName: (json['craftsmanName'] ??
              json['Craftsman']?['name'] ??
              json['artisan'] ??
              '')
          .toString(),
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse(json['price']?.toString() ?? '') ??
          0.0,
      imageUrl: json['imageUrl']?.toString(),
      category: (json['category'] ?? '').toString(),
      reason: (json['reason'] ?? json['recommendationReason'] ?? '').toString(),
    );
  }
}

class CartScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const CartScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _deliveryAddress = "";
  String _customerPhone = "";
  String _paymentMethod = "";

  List<CartItem> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isUpdating = false;

  List<RecommendedProduct> _recommendations = [];
  bool _isRecommendationsLoading = false;
  bool _recommendationsAreBestSellers = false;
  String? _recommendationsError;

  @override
  void initState() {
    super.initState();
    _deliveryAddress = widget.isArabic ? "نابلس، فلسطين" : "Nablus, Palestine";
    _paymentMethod = widget.isArabic
        ? "الدفع الإلكتروني (Escrow)"
        : "Online Payment (Escrow)";
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await ApiService.get('/interactions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final interactions = data is List
            ? data
            : (data['interactions'] ?? data['data'] ?? []) as List;

        final cartInteractions = interactions
            .where((i) => i['type'] == 'cart' || i['interactionType'] == 'cart')
            .toList();

        _items = cartInteractions.map((item) {
          final p = item['Product'] ?? item;
          final craftsman = p['Craftsman'] ?? {};
          return CartItem(
            id: p['id']?.toString() ?? '',
            interactionId: item['id']?.toString() ?? '',
            titleAr: p['titleAr'] ?? p['nameAr'] ?? p['title'] ?? '—',
            titleEn: p['titleEn'] ?? p['nameEn'] ?? p['title'] ?? '—',
            craftsmanAr: craftsman['name'] ?? p['artisan'] ?? '',
            craftsmanEn: craftsman['name'] ?? p['artisan'] ?? '',
            craftsmanId: p['craftsmanId'] ?? craftsman['id'] ?? '',
            price: (p['price'] as num?)?.toDouble() ??
                double.tryParse(p['price']?.toString() ?? '') ??
                0.0,
            imagePath: p['imageUrl'] as String?,
            quantity: item['quantity'] as int? ?? 1,
          );
        }).toList();

        await _fetchRecommendations();
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() {
      _isRecommendationsLoading = true;
      _recommendationsError = null;
    });

    try {
      final response = await ApiService.post(
        '/ai/cart-recommendations',
        body: {
          'cartProductIds': _items.map((item) => item.id).toList(),
          'language': widget.isArabic ? 'ar' : 'en',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawRecommendations =
            data is Map<String, dynamic> ? data['recommendations'] : null;
        final parsed = rawRecommendations is List
            ? rawRecommendations
                .whereType<Map>()
                .map((item) => RecommendedProduct.fromJson(
                    Map<String, dynamic>.from(item)))
                .where((item) => item.id.isNotEmpty)
                .toList()
            : <RecommendedProduct>[];

        if (mounted) {
          setState(() {
            _recommendations = parsed
                .where(
                    (rec) => !_items.any((cartItem) => cartItem.id == rec.id))
                .toList();
            _recommendationsAreBestSellers = data is Map<String, dynamic> &&
                (data['mode'] == 'best_sellers' ||
                    data['type'] == 'best_sellers');
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _recommendations = [];
            _recommendationsError =
                'Recommendations unavailable (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
      if (mounted) {
        setState(() {
          _recommendations = [];
          _recommendationsError = 'Recommendations unavailable';
        });
      }
    } finally {
      if (mounted) setState(() => _isRecommendationsLoading = false);
    }
  }

  String _imageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    final apiRoot = ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (value.startsWith('/')) return '$apiRoot$value';
    return '$apiRoot/$value';
  }

  // Theme colors
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent =>
      widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  double get subtotal =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  // Flat delivery fee per distinct craftsman in the cart. Keep in sync with backend `DELIVERY_FLAT_FEE_JOD`.
  double get delivery {
    if (_items.isEmpty) return 0;
    const double flatFee = 15.0; // JOD
    final uniqueCraftsmen = _items.map((i) => i.craftsmanId).toSet().length;
    return flatFee * uniqueCraftsmen;
  }

  double get total => subtotal + delivery;

  void _increment(CartItem item) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    final newQty = item.quantity + 1;
    final success =
        await CustomerService.updateCartQuantity(item.interactionId, newQty);
    if (mounted) {
      setState(() => _isUpdating = false);
      if (success) {
        setState(() => item.quantity = newQty);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('فشل التحديث', 'Update failed'))));
      }
    }
  }

  void _decrement(CartItem item) async {
    if (_isUpdating) return;
    if (item.quantity > 1) {
      setState(() => _isUpdating = true);
      final newQty = item.quantity - 1;
      final success =
          await CustomerService.updateCartQuantity(item.interactionId, newQty);
      if (mounted) {
        setState(() => _isUpdating = false);
        if (success) {
          setState(() => item.quantity = newQty);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('فشل التحديث', 'Update failed'))));
        }
      }
    }
  }

  void _removeItem(CartItem item) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final response =
          await ApiService.delete('/interactions/${item.interactionId}');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _items.remove(item));
          await _fetchRecommendations();
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('فشل الحذف', 'Delete failed'))));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('فشل الحذف', 'Delete failed'))));
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
                widget.isArabic
                    ? Icons.arrow_forward_ios
                    : Icons.arrow_back_ios,
                color: text,
                size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('سلة الشراء', 'My Cart'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            if (_items.isNotEmpty && !_hasError)
              TextButton(
                onPressed: _isUpdating
                    ? null
                    : () async {
                        setState(() => _isUpdating = true);
                        final success = await CustomerService.clearCart();
                        if (mounted) {
                          setState(() => _isUpdating = false);
                          if (success) {
                            setState(() => _items.clear());
                            await _fetchRecommendations();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(t('فشل إفراغ السلة',
                                    'Failed to clear cart'))));
                          }
                        }
                      },
                child: Text(
                  t('إفراغ', 'Clear'),
                  style: GoogleFonts.cairo(
                      color: _isUpdating ? dim : Colors.redAccent,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _hasError
                ? _buildErrorState()
                : (_items.isEmpty ? _buildEmptyState() : _buildCartList()),
        bottomNavigationBar: (_isLoading || _hasError || _items.isEmpty)
            ? null
            : _buildBottomSummary(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 80, color: Colors.redAccent.withValues(alpha: 0.7)),
          const SizedBox(height: 24),
          Text(
            t('حدث خطأ', 'Something went wrong'),
            style: GoogleFonts.cairo(
                color: text, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _fetchCart,
            icon: const Icon(Icons.refresh, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            label: Text(
              t('إعادة المحاولة', 'Retry'),
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 80, color: accent),
          ),
          const SizedBox(height: 24),
          Text(
            t('سلتك فارغة!', 'Your cart is empty!'),
            style: GoogleFonts.cairo(
                color: text, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            t('تصفح منتجات حرفيينا وأضف ما يعجبك',
                'Browse our craftsmen products and add some items'),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: dim, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              t('تصفح الآن', 'Shop Now'),
              style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(height: 28),
          _buildRecommendationsSection(showBestSellerTitle: true),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: item.imagePath != null && item.imagePath!.isNotEmpty
                    ? Image.network(
                        item.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image, color: accent, size: 32),
                      )
                    : Icon(Icons.shopping_bag_outlined,
                        color: accent, size: 32),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(item.titleAr, item.titleEn),
                      style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      t('بواسطة ${item.craftsmanAr}', 'By ${item.craftsmanEn}'),
                      style: GoogleFonts.cairo(color: dim, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.price} JD',
                      style: GoogleFonts.cairo(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
              // Controls
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => _removeItem(item),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _decrement(item),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Icon(Icons.remove, size: 16),
                          ),
                        ),
                        Text(
                          '${item.quantity}',
                          style: GoogleFonts.cairo(
                              color: text, fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          onTap: () => _increment(item),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Icon(Icons.add, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectPaymentMethod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final methods = [
          {
            'nameAr': 'الدفع الإلكتروني (Escrow) 🔒',
            'nameEn': 'Online Payment (Escrow) 🔒',
            'icon': Icons.shield_outlined,
            'recommended': true
          },
          {
            'nameAr': 'بطاقة ائتمان / مدى',
            'nameEn': 'Credit / Debit Card',
            'icon': Icons.credit_card,
            'recommended': false
          },
        ];

        return Directionality(
          textDirection:
              widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('اختر طريقة الدفع', 'Select Payment Method'),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ...methods.map((m) {
                  final name = t(m['nameAr'] as String, m['nameEn'] as String);
                  final isSel = _paymentMethod == name;
                  final isRecommended = m['recommended'] as bool;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRecommended) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A017)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFD4A017)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              t('مدفوعاتك محمية حتى تتم الخدمة',
                                  'Your payment protected until service is done'),
                              style: GoogleFonts.cairo(
                                  color: const Color(0xFFD4A017),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(m['icon'] as IconData,
                            color: isSel ? accent : dim),
                        title: Text(
                          name,
                          style: GoogleFonts.cairo(
                            color: text,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSel
                            ? Icon(Icons.check_circle, color: accent)
                            : null,
                        onTap: () {
                          setState(() => _paymentMethod = name);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isCheckingOut = false;

  Future<bool> _showCheckoutDetailsDialog() async {
    final addressCtrl = TextEditingController(text: _deliveryAddress);
    final phoneCtrl = TextEditingController(text: _customerPhone);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t('تفاصيل التوصيل والمعلومات', 'Delivery Details'),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: addressCtrl,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: t('عنوان التوصيل', 'Delivery Address'),
                  labelStyle: TextStyle(color: dim),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.location_on_outlined, color: accent),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? t('يرجى إدخال العنوان', 'Please enter delivery address')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  labelText: t('رقم الهاتف للتواصل', 'Contact Phone Number'),
                  labelStyle: TextStyle(color: dim),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.phone_outlined, color: accent),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? t('يرجى إدخال رقم الهاتف', 'Please enter contact phone number')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _deliveryAddress = addressCtrl.text.trim();
                _customerPhone = phoneCtrl.text.trim();
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t('إرسال الطلب', 'Place Order'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showSuccessOrder() async {
    if (_items.isEmpty) return;

    final confirmedDetails = await _showCheckoutDetailsDialog();
    if (!confirmedDetails) return;

    setState(() => _isCheckingOut = true);

    try {
      final orderItems = _items
          .map((i) => {
                'productId': i.id,
                'quantity': i.quantity,
                'interactionId': i.interactionId,
              })
          .toList();

      // Create orders with pending_artisan status with customer delivery address and phone
      final responseData = await ProductsService.createCheckoutOrders(
        items: List<Map<String, dynamic>>.from(orderItems),
        deliveryAddress: _deliveryAddress,
        customerPhone: _customerPhone,
      );

      if (responseData != null && responseData['success'] == true) {
        final List<Map<String, dynamic>> orders =
            List<Map<String, dynamic>>.from(responseData['orders'] ?? []);

        setState(() {
          _items.clear();
          _isCheckingOut = false;
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderConfirmationScreen(
                isArabic: widget.isArabic,
                isDarkMode: widget.isDarkMode,
                orders: orders,
              ),
            ),
          );
        }
      } else {
        throw Exception('Checkout failed');
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      setState(() => _isCheckingOut = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(t('حدث خطأ أثناء الطلب', 'Error placing order: $e'))),
        );
      }
    }
  }



  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location Selection Row
            InkWell(
              onTap: () async {
                final address = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      isArabic: widget.isArabic,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
                if (address != null && address.isNotEmpty) {
                  setState(() {
                    _deliveryAddress = address;
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _deliveryAddress.isEmpty
                            ? t('اختر موقع التوصيل', 'Choose Delivery Location')
                            : _deliveryAddress,
                        style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: dim, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Payment Selection Row
            InkWell(
              onTap: _selectPaymentMethod,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment_outlined, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _paymentMethod,
                        style: GoogleFonts.cairo(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: dim, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Real AI recommendations from backend
            _buildRecommendationsSection(),
            const SizedBox(height: 4),

            // Promo Code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      hintText: t('كود الخصم', 'Promo Code'),
                      hintStyle: TextStyle(color: dim),
                      filled: true,
                      fillColor: bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: text,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: Text(
                    t('تطبيق', 'Apply'),
                    style: GoogleFonts.cairo(
                        color: surface, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('المجموع الفرعي', 'Subtotal'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 13)),
                Text('$subtotal JD',
                    style: GoogleFonts.cairo(
                        color: text, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            // Delivery
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (() {
                    final unique =
                        _items.map((i) => i.craftsmanId).toSet().length;
                    const fee = 15.0;
                    return widget.isArabic
                        ? 'التوصيل ($unique × ${fee.toStringAsFixed(0)} JOD)'
                        : 'Delivery ($unique × ${fee.toStringAsFixed(0)} JOD)';
                  })(),
                  style: GoogleFonts.cairo(color: dim, fontSize: 13),
                ),
                Text('$delivery JD',
                    style: GoogleFonts.cairo(
                        color: text, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: border),
            const SizedBox(height: 12),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('الإجمالي', 'Total'),
                    style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  '$total JD',
                  style: GoogleFonts.cairo(
                      color: accent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Checkout Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _showSuccessOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isCheckingOut
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : Text(
                        t('إتمام الشراء', 'Checkout'),
                        style: GoogleFonts.cairo(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection({bool showBestSellerTitle = false}) {
    final title = showBestSellerTitle || _recommendationsAreBestSellers
        ? t('🔥 الأكثر مبيعًا', '🔥 Best Sellers')
        : t('🤖 الذكاء الاصطناعي يقترح لإكمال طلبك',
            '🤖 AI suggests to complete your order');

    if (_isRecommendationsLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.purpleAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.purpleAccent)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('جاري تجهيز اقتراحات مناسبة...',
                    'Finding suitable recommendations...'),
                style: GoogleFonts.cairo(color: dim, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_outlined,
                color: Colors.purpleAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text(
              _recommendationsError != null
                  ? t('اقتراحات الذكاء الاصطناعي غير متاحة حالياً',
                      'AI recommendations are unavailable right now')
                  : t('لا توجد اقتراحات متاحة حالياً',
                      'No recommendations available yet'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: dim, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.purpleAccent.withValues(alpha: 0.08),
          const Color(0xFFD4A017).withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                showBestSellerTitle || _recommendationsAreBestSellers
                    ? Icons.local_fire_department_outlined
                    : Icons.auto_awesome,
                color: showBestSellerTitle || _recommendationsAreBestSellers
                    ? const Color(0xFFD4A017)
                    : Colors.purpleAccent,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: showBestSellerTitle || _recommendationsAreBestSellers
                        ? const Color(0xFFD4A017)
                        : Colors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildRecommendationCard(_recommendations[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendedProduct product) {
    final localizedName = widget.isArabic ? product.titleAr : product.titleEn;
    final displayName = localizedName.trim().isEmpty
        ? (product.titleEn.trim().isNotEmpty
            ? product.titleEn
            : product.titleAr)
        : localizedName;
    final image = _imageUrl(product.imageUrl);

    return Container(
      width: 132,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 66,
              width: double.infinity,
              color: bg,
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.broken_image_outlined, color: dim),
                    )
                  : Icon(Icons.shopping_bag_outlined, color: accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                color: text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            '${product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2)} JD',
            style: GoogleFonts.cairo(
                color: const Color(0xFFD4A017),
                fontSize: 10.5,
                fontWeight: FontWeight.bold),
          ),
          if (!_recommendationsAreBestSellers && product.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(color: dim, fontSize: 9),
            ),
          ],
          const Spacer(),
          InkWell(
            onTap: () => _addRecommendedProduct(product),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A017),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRecommendedProduct(RecommendedProduct product) async {
    if (_isUpdating || product.id.isEmpty) return;
    setState(() => _isUpdating = true);

    try {
      final success = await CustomerService.addToCart(product.id);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isArabic
                  ? '✅ تمت إضافة "${product.titleAr}" إلى السلة'
                  : '✅ "${product.titleEn}" added to your cart',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchCart();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t('تعذر إضافة المنتج إلى السلة',
                  'Could not add product to cart'))),
        );
      }
    } catch (e) {
      debugPrint('Add recommended product error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t('حدث خطأ أثناء إضافة المنتج',
                  'Error adding product to cart'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}
