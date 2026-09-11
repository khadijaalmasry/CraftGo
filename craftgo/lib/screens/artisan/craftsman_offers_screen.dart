// lib/features/artisan/screens/craftsman_offers_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../hire_order/hire_order_provider.dart';
import '../hire_order/hire_response_screen.dart';
import '../custom_order/artisan_templates_screen.dart';
import 'add_product_screen.dart';
import '../../services/products_service.dart';
import '../../services/payment_service.dart';
import '../../services/api_service.dart';

class CraftsmanOffersScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId;

  const CraftsmanOffersScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
  });

  @override
  State<CraftsmanOffersScreen> createState() => _CraftsmanOffersScreenState();
}

class _CraftsmanOffersScreenState extends State<CraftsmanOffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Products list — loaded from backend
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _visibilityFilter = 'all';

  // Mock data for hire enablement
  bool _hireEnabled = true;
  late Future<Map<String, dynamic>> _earningsFuture;

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProducts();
    _earningsFuture = _loadEarnings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.artisanId.trim().isEmpty) return;
      context.read<HireOrderProvider>().loadForArtisan(widget.artisanId);
    });
  }

  Future<Map<String, dynamic>> _loadEarnings() async {
    final response = await ApiService.get(
      '/payments/artisan/${widget.artisanId}/earnings',
    );
    if (response.statusCode != 200) return const {};
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final data = await ProductsService.getProductsByCraftsman(widget.artisanId);
    if (mounted) {
      setState(() {
        _products = data.map((p) => Map<String, dynamic>.from(p)).toList();
        _loadingProducts = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      final titleAr = (product['titleAr'] ?? '').toString().toLowerCase();
      final titleEn = (product['titleEn'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          titleAr.contains(query) ||
          titleEn.contains(query) ||
          category.contains(query);

      final isPublic = _readIsPublic(product['isPublic']);

      final matchesFilter = _visibilityFilter == 'all' ||
          (_visibilityFilter == 'public' && isPublic) ||
          (_visibilityFilter == 'private' && !isPublic);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  bool _readIsPublic(dynamic rawValue) {
    return rawValue == true ||
        rawValue == 1 ||
        rawValue?.toString().toLowerCase() == 'true' ||
        rawValue?.toString() == '1';
  }

  int get _publicProductsCount =>
      _products.where((product) => _readIsPublic(product['isPublic'])).length;

  int get _privateProductsCount => _products.length - _publicProductsCount;

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          craftsmanId: widget.artisanId,
        ),
      ),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _toggleProductVisibility(int index) async {
    final product = _products[index];
    final productId = product['id']?.toString();

    if (productId == null || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تعذر تحديد المنتج', 'Product ID was not found'),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rawValue = product['isPublic'];

    final currentValue =
        rawValue == true ||
            rawValue == 1 ||
            rawValue?.toString().toLowerCase() == 'true' ||
            rawValue?.toString() == '1';

    final newValue = !currentValue;

    // تغيير الواجهة مباشرة
    setState(() {
      _products[index]['isPublic'] = newValue;
    });

    final updated = await ProductsService.updateProduct(
      productId,
      {
        'isPublic': newValue,
      },
    );

    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _products[index] = {
          ..._products[index],
          ...updated,
          'isPublic': newValue,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? t(
              '👁 أصبح المنتج ظاهراً للزبائن',
              '👁 Product is now visible',
            )
                : t(
              '🙈 تم إخفاء المنتج عن الزبائن',
              '🙈 Product has been hidden',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor:
          newValue ? Colors.green : Colors.grey.shade700,
        ),
      );
    } else {
      // إرجاع الحالة القديمة عند فشل الطلب
      setState(() {
        _products[index]['isPublic'] = currentValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'فشل تغيير حالة ظهور المنتج',
              'Failed to change product visibility',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editProduct(int index) async {
    final product = _products[index];

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          craftsmanId: widget.artisanId,
          product: product,
          onProductSaved: _loadProducts,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadProducts();
    }
  }

  void _deleteProduct(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('حذف المنتج', 'Delete Product'),
            style: GoogleFonts.cairo(color: text)),
        content: Text(t('هل أنت متأكد؟', 'Are you sure?'),
            style: GoogleFonts.cairo(color: dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'),
                  style: GoogleFonts.cairo(color: dim))),
          TextButton(
            onPressed: () async {
              final productId = _products[index]['id']?.toString();
              if (productId == null || productId.isEmpty) return;

              final deleted = await ProductsService.deleteProduct(productId);
              if (!mounted) return;
              if (!ctx.mounted) return;

              Navigator.pop(ctx);

              if (deleted) {
                setState(() => _products.removeAt(index));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('تم حذف المنتج', 'Product deleted')),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('فشل حذف المنتج', 'Failed to delete product')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              t('حذف', 'Delete'),
              style: GoogleFonts.cairo(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: accent,
            unselectedLabelColor: dim,
            indicatorColor: accent,
            indicatorWeight: 3,
            labelStyle:
            GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
            tabs: [
              Tab(text: t('جاهز', 'Ready-Made')),
              Tab(text: t('طلبات مخصصة', 'Custom Orders')),
              Tab(text: t('عمل في الموقع', 'Hire/On-Site')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 0: Ready-Made Products
            _buildReadyMadeTab(),
            // Tab 1: Custom Order Templates – we'll use a custom widget without delete-all button
            _buildCustomTemplatesTab(),
            // Tab 2: Hire/On-Site management
            _buildHireTab(),
          ],
        ),
      ),
    );
  }

  // ── Ready-Made Products Tab ──────────────────────────────────────────
  Widget _buildReadyMadeTab() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('منتجاتك الجاهزة للبيع', 'Your ready-made products'),
                  style: GoogleFonts.cairo(color: dim, fontSize: 14),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, color: Colors.black, size: 18),
                label: Text(
                  t('إضافة منتج', 'Add Product'),
                  style: GoogleFonts.cairo(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.inventory_2_outlined,
                  value: _products.length.toString(),
                  title: t('المنتجات', 'Products'),
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.visibility_outlined,
                  value: _publicProductsCount.toString(),
                  title: t('عامة', 'Public'),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.visibility_off_outlined,
                  value: _privateProductsCount.toString(),
                  title: t('خاصة', 'Private'),
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: GoogleFonts.cairo(color: text),
            decoration: InputDecoration(
              hintText: t(
                'ابحث عن منتج أو تصنيف...',
                'Search products or categories...',
              ),
              hintStyle: GoogleFonts.cairo(color: dim),
              prefixIcon: Icon(Icons.search, color: dim),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(Icons.close, color: dim),
              )
                  : null,
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildFilterButton(
                value: 'all',
                label: t('الكل', 'All'),
                icon: Icons.apps_rounded,
              ),
              const SizedBox(width: 8),
              _buildFilterButton(
                value: 'public',
                label: t('عام', 'Public'),
                icon: Icons.visibility_outlined,
              ),
              const SizedBox(width: 8),
              _buildFilterButton(
                value: 'private',
                label: t('خاص', 'Private'),
                icon: Icons.visibility_off_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loadingProducts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator(color: accent)),
            )
          else if (_products.isEmpty)
            _buildEmptyProductsState()
          else if (_filteredProducts.isEmpty)
              _buildNoResultsState()
            else
              ..._filteredProducts.map((product) {
                final originalIndex = _products.indexWhere(
                      (item) => item['id']?.toString() == product['id']?.toString(),
                );
                return _buildProductCard(product, originalIndex);
              }),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final isPublic = _readIsPublic(product['isPublic']);
    final name = widget.isArabic
        ? (product['titleAr'] ?? product['titleEn'] ?? '')
        : (product['titleEn'] ?? product['titleAr'] ?? '');
    final imageUrl = product['imageUrl']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.broken_image_outlined, color: dim),
              )
                  : Icon(Icons.image_outlined, color: dim),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product['price']} JOD',
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isPublic ? Icons.visibility : Icons.visibility_off,
                      size: 14,
                      color: isPublic ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPublic ? t('عام', 'Public') : t('خاص', 'Private'),
                      style: GoogleFonts.cairo(
                        color: isPublic ? Colors.green : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('تعديل المنتج', 'Edit Product'),
            icon: Icon(Icons.edit_outlined, color: accent),
            onPressed: index < 0 ? null : () => _editProduct(index),
          ),
          IconButton(
            tooltip: isPublic
                ? t('إخفاء المنتج', 'Hide Product')
                : t('إظهار المنتج', 'Show Product'),
            icon: Icon(
              isPublic ? Icons.visibility : Icons.visibility_off,
              color: isPublic ? Colors.green : Colors.grey,
            ),
            onPressed: index < 0 ? null : () => _toggleProductVisibility(index),
          ),
          IconButton(
            tooltip: t('حذف المنتج', 'Delete Product'),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: index < 0 ? null : () => _deleteProduct(index),
          ),
        ],
      ),
    );
  }

  Widget _earningsValue(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.cairo(color: dim, fontSize: 10)),
      Text(value, style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(color: dim, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _visibilityFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _visibilityFilter = value),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? accent : border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.black : dim,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: selected ? Colors.black : text,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProductsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: dim),
          const SizedBox(height: 14),
          Text(
            t('لا توجد منتجات', 'No products yet'),
            style: GoogleFonts.cairo(color: dim, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 45),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 50, color: dim),
          const SizedBox(height: 12),
          Text(
            t('لا توجد منتجات مطابقة', 'No matching products found'),
            style: GoogleFonts.cairo(
              color: dim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Custom Templates Tab (without Delete All button) ──────────────────
  Widget _buildCustomTemplatesTab() {
    // We reuse ArtisanTemplatesScreen but we need to override the AppBar actions
    // or we can build a custom version. Since we can't easily remove the button
    // from ArtisanTemplatesScreen without modifying that file, we'll just
    // wrap it and provide a custom AppBar with the back button but no delete-all.
    // Actually, ArtisanTemplatesScreen has an AppBar that includes the delete-all
    // button. We'll instead create a custom implementation here.
    // For simplicity, we'll just use ArtisanTemplatesScreen but we need to
    // modify it separately. Since the user asked to remove that button,
    // we'll assume they'll modify that file. But to be safe, we'll create
    // a custom tab content using the same data and logic but without the button.
    // This is a mock, so we'll show a simple list.
    // In a real app, you'd copy the ArtisanTemplatesScreen logic here.
    return ArtisanTemplatesScreen(
      isArabic: widget.isArabic,
      isDarkMode: widget.isDarkMode,
      artisanId: widget.artisanId,
      hideDeleteAll: true, // We'll add this param in the next step
    );
    // For now, we'll just use the original screen and note that the button
    // will be removed in the separate file.
    // I'll provide a modified version of ArtisanTemplatesScreen as well.
  }

  // ── Hire/On-Site Tab ──────────────────────────────────────────────────
  Widget _buildHireTab() {
    final hireProvider = context.watch<HireOrderProvider>();

    final incomingRequests = hireProvider
        .requestsForArtisan(widget.artisanId)
        .where((request) => request.status == 'pending_artisan')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      color: accent,
      onRefresh: () =>
          context.read<HireOrderProvider>().loadForArtisan(widget.artisanId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _earningsFuture,
            builder: (context, snapshot) {
              final earnings = snapshot.data ?? const {};
              final held = double.tryParse(earnings['pending']?.toString() ?? '') ?? 0;
              final available = double.tryParse(earnings['available']?.toString() ?? '') ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: accent),
                    const SizedBox(width: 12),
                    Expanded(child: _earningsValue(
                      t('محجوز بالضمان', 'Held in Escrow'),
                      '${held.toStringAsFixed(2)} JOD',
                    )),
                    Container(width: 1, height: 38, color: border),
                    const SizedBox(width: 12),
                    Expanded(child: _earningsValue(
                      t('متاح للحرفي', 'Available'),
                      '${available.toStringAsFixed(2)} JOD',
                    )),
                    IconButton(
                      onPressed: () => setState(() => _earningsFuture = _loadEarnings()),
                      icon: Icon(Icons.refresh, color: accent),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final launched = await PaymentService.openPayoutOnboarding();
                        if (!launched && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('تعذر فتح صفحة السحب عبر Stripe', 'Could not open Stripe Payout page'))),
                          );
                        }
                      },
                      icon: const Icon(Icons.account_balance_outlined, size: 14),
                      label: Text(t('سحب', 'Payout'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(
                          'تفعيل طلبات العمل في الموقع',
                          'Enable On-Site Hire',
                        ),
                        style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        t(
                          'سيتمكن الزبائن من طلب خدماتك في موقعهم',
                          'Customers can request your services at their location',
                        ),
                        style: GoogleFonts.cairo(
                          color: dim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hireEnabled,
                  onChanged: (v) => setState(() => _hireEnabled = v),
                  activeThumbColor: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_hireEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('طلبات واردة', 'Incoming Hire Requests'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('تحديث', 'Refresh'),
                  onPressed: hireProvider.isLoading
                      ? null
                      : () => context
                      .read<HireOrderProvider>()
                      .loadForArtisan(widget.artisanId),
                  icon: Icon(Icons.refresh_rounded, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hireProvider.isLoading && incomingRequests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 45),
                child: Center(
                  child: CircularProgressIndicator(color: accent),
                ),
              )
            else if (hireProvider.error != null &&
                incomingRequests.isEmpty)
              _buildHireMessageCard(
                icon: Icons.error_outline_rounded,
                message: t(
                  'تعذر تحميل طلبات العمل في الموقع. اسحب للأسفل للمحاولة مجدداً.',
                  'Could not load hire requests. Pull down to try again.',
                ),
                iconColor: Colors.redAccent,
              )
            else if (incomingRequests.isEmpty)
                _buildHireMessageCard(
                  icon: Icons.handshake_outlined,
                  message: t(
                    'لا توجد طلبات واردة حالياً',
                    'No incoming hire requests',
                  ),
                  iconColor: accent,
                )
              else
                ...incomingRequests.map(_buildHireRequestCard),
          ],
        ],
      ),
    );
  }

  Widget _buildHireMessageCard({
    required IconData icon,
    required String message,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(color: dim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHireRequestCard(HireRequest request) {
    final customerName = request.customerName.trim().isEmpty
        ? t('زبون', 'Customer')
        : request.customerName;

    final location = request.location.trim().isEmpty
        ? t('لم يتم تحديد عنوان نصي', 'No text address provided')
        : request.location;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final sent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => HireResponseScreen(
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              request: request,
            ),
          ),
        );
        if (sent == true && mounted) {
          await context
              .read<HireOrderProvider>()
              .loadForArtisan(widget.artisanId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.handyman_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.jobDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: dim,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t('جديد', 'New'),
                    style: GoogleFonts.cairo(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _hireInfoRow(
              Icons.location_on_outlined,
              location,
            ),
            const SizedBox(height: 7),
            _hireInfoRow(
              Icons.calendar_month_outlined,
              '${_formatHireDate(request.startDate)}  →  '
                  '${_formatHireDate(request.endDate)}',
            ),
            const SizedBox(height: 7),
            _hireInfoRow(
              Icons.schedule_outlined,
              t(
                '${request.dailyHours} ساعات يومياً',
                '${request.dailyHours} hours/day',
              ),
            ),
            if (request.materials.isNotEmpty) ...[
              const SizedBox(height: 7),
              _hireInfoRow(
                Icons.inventory_2_outlined,
                request.materials
                    .map((m) => m.name)
                    .where((name) => name.trim().isNotEmpty)
                    .join(', '),
              ),
            ],
            if (request.toolsRequired.isNotEmpty) ...[
              const SizedBox(height: 7),
              _hireInfoRow(
                Icons.build_outlined,
                request.toolsRequired.join(', '),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t(
                  'تم استلام الطلب. الخطوة التالية هي إرسال عرض للزبون.',
                  'Request received. The next step is to send a proposal to the customer.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t('اضغط لإرسال عرض', 'Tap to send a proposal'),
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_ios, color: accent, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hireInfoRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatHireDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

}
