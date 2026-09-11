import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/products_service.dart';
import '../../services/session_service.dart';
import 'add_product_screen.dart';

class CraftsmanProductsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const CraftsmanProductsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<CraftsmanProductsScreen> createState() => _CraftsmanProductsScreenState();
}

class _CraftsmanProductsScreenState extends State<CraftsmanProductsScreen> {
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _craftsmanId;
  final TextEditingController _searchController =
  TextEditingController();

  String _visibilityFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    _craftsmanId = await SessionService.getUserId();
    if (_craftsmanId != null) {
      final data = await ProductsService.getProductsByCraftsman(_craftsmanId!);
      if (mounted) {
        setState(() {
          _products = data.map((p) => Map<String, dynamic>.from(p)).toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      final titleAr =
      (product['titleAr'] ?? '').toString().toLowerCase();

      final titleEn =
      (product['titleEn'] ?? '').toString().toLowerCase();

      final category =
      (product['category'] ?? '').toString().toLowerCase();

      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch =
          query.isEmpty ||
              titleAr.contains(query) ||
              titleEn.contains(query) ||
              category.contains(query);

      final isPublic = product['isPublic'] ?? true;

      final matchesFilter =
          _visibilityFilter == 'all' ||
              (_visibilityFilter == 'public' && isPublic) ||
              (_visibilityFilter == 'private' && !isPublic);

      return matchesSearch && matchesFilter;
    }).toList();
  }
  int get _publicProductsCount {
    return _products
        .where((product) => product['isPublic'] ?? true)
        .length;
  }

  int get _privateProductsCount {
    return _products
        .where((product) => !(product['isPublic'] ?? true))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddProductScreen(
                  isArabic: widget.isArabic,
                  isDarkMode: widget.isDarkMode,
                  craftsmanId: _craftsmanId ?? '',
                  onProductSaved: () => _loadProducts(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: Text(t('منتج جديد', 'New Product')),
          backgroundColor: accent,
          foregroundColor: Colors.black,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _products.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: dim),
              const SizedBox(height: 16),
              Text(
                t('لا توجد منتجات مضافة', 'No products added yet'),
                style: GoogleFonts.cairo(color: dim, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
                label: Text(t('تحديث', 'Refresh')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.black),
              ),
            ],
          ),
        )
: RefreshIndicator(
onRefresh: _loadProducts,
color: accent,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
children: [
// ── Statistics ─────────────────────────────
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

// ── Search ─────────────────────────────────
TextField(
controller: _searchController,
onChanged: (value) {
setState(() {
_searchQuery = value;
});
},
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

setState(() {
_searchQuery = '';
});
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
borderSide: BorderSide(
color: accent,
width: 1.5,
),
),
),
),

const SizedBox(height: 14),

// ── Visibility Filters ─────────────────────
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

if (_filteredProducts.isEmpty)
Container(
padding: const EdgeInsets.symmetric(
horizontal: 20,
vertical: 45,
),
decoration: BoxDecoration(
color: surface,
borderRadius: BorderRadius.circular(18),
border: Border.all(color: border),
),
child: Column(
children: [
Icon(
Icons.search_off_rounded,
size: 55,
color: dim,
),
const SizedBox(height: 12),
Text(
t(
'لا توجد منتجات مطابقة',
'No matching products found',
),
textAlign: TextAlign.center,
style: GoogleFonts.cairo(
color: dim,
fontSize: 15,
fontWeight: FontWeight.w600,
),
),
],
),
)
else
GridView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 2,
crossAxisSpacing: 14,
mainAxisSpacing: 14,
childAspectRatio: 0.78,
),
itemCount: _filteredProducts.length,
itemBuilder: (context, index) {
final p = _filteredProducts[index];

final originalIndex = _products.indexWhere(
(product) =>
product['id'].toString() ==
p['id'].toString(),
);

final name = widget.isArabic
? (p['titleAr'] ?? p['titleEn'] ?? '')
: (p['titleEn'] ?? p['titleAr'] ?? '');

final category = p['category'] ?? '';
final price = p['price'] ?? 0;
final isAvailable =
p['isAvailable'] ?? true;

final imageUrl =
p['imageUrl']?.toString().trim();

return Container(
decoration: BoxDecoration(
color: surface,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: isAvailable
? Colors.green.withValues(alpha: 0.4)
: border,
width: isAvailable ? 2 : 1,
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
child: ClipRRect(
borderRadius:
const BorderRadius.vertical(
top: Radius.circular(15),
),
child: imageUrl != null &&
imageUrl.isNotEmpty
? Image.network(
imageUrl,
width: double.infinity,
fit: BoxFit.cover,
errorBuilder:
(_, __, ___) =>
_imgPlaceholder(),
)
: _imgPlaceholder(),
),
),
Padding(
padding: const EdgeInsets.all(11),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
name.toString(),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: GoogleFonts.cairo(
color: text,
fontWeight: FontWeight.bold,
fontSize: 13,
),
),
const SizedBox(height: 3),
Text(
category.toString(),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: GoogleFonts.cairo(
color: dim,
fontSize: 11,
),
),
const SizedBox(height: 7),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 3,
),
decoration: BoxDecoration(
color:
(p['isPublic'] ?? true)
? Colors.green
.withValues(
alpha: 0.10,
)
: Colors.grey
.withValues(
alpha: 0.15,
),
borderRadius:
BorderRadius.circular(8),
),
child: Text(
(p['isPublic'] ?? true)
? t('عام', 'Public')
: t('خاص', 'Private'),
style: GoogleFonts.cairo(
color:
(p['isPublic'] ?? true)
? Colors.green
: dim,
fontSize: 10,
fontWeight:
FontWeight.bold,
),
),
),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: Text(
'$price JOD',
maxLines: 1,
style: GoogleFonts.cairo(
color: accent,
fontWeight:
FontWeight.bold,
fontSize: 13,
),
),
),
IconButton(
tooltip: t(
'تعديل المنتج',
'Edit Product',
),
onPressed:
originalIndex == -1
? null
: () =>
_editProduct(
originalIndex,
),
icon: Icon(
Icons.edit_outlined,
size: 17,
color: accent,
),
visualDensity:
VisualDensity.compact,
padding: EdgeInsets.zero,
constraints:
const BoxConstraints(),
),
const SizedBox(width: 7),
IconButton(
tooltip:
(p['isPublic'] ??
true)
? t(
'إخفاء المنتج',
'Hide Product',
)
: t(
'إظهار المنتج',
'Show Product',
),
onPressed:
originalIndex == -1
? null
: () =>
_toggleProductVisibility(
originalIndex,
),
icon: Icon(
(p['isPublic'] ?? true)
? Icons
.visibility_outlined
: Icons
.visibility_off_outlined,
size: 17,
color:
(p['isPublic'] ?? true)
? Colors.green
: dim,
),
visualDensity:
VisualDensity.compact,
padding: EdgeInsets.zero,
constraints:
const BoxConstraints(),
),
const SizedBox(width: 7),
IconButton(
tooltip: t(
'حذف المنتج',
'Delete Product',
),
onPressed:
originalIndex == -1
? null
: () =>
_deleteProduct(
originalIndex,
),
icon: const Icon(
Icons.delete_outline,
size: 17,
color: Colors.redAccent,
),
visualDensity:
VisualDensity.compact,
padding: EdgeInsets.zero,
constraints:
const BoxConstraints(),
),
],
),
],
),
),
],
),
);
},
),
],
),
        ),
      ),
        );
          }
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 10,
            ),
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
        onTap: () {
          setState(() {
            _visibilityFilter = value;
          });
        },
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? accent : surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? accent : border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.black : dim,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: selected ? Colors.black : text,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _imgPlaceholder() => Container(
    color: accent.withValues(alpha: 0.05),
    child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: dim)),
  );

  Future<void> _editProduct(int index) async {
    final product = _products[index];

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          craftsmanId: _craftsmanId ?? '',
          product: product,
          onProductSaved: _loadProducts,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadProducts();
    }
  }

  Future<void> _toggleProductVisibility(int index) async {
    final product = _products[index];
    final productId = product['id'].toString();
    final currentVisibility = product['isPublic'] ?? true;
    final newVisibility = !currentVisibility;

    setState(() {
      _products[index]['isPublic'] = newVisibility;
    });

    final result = await ProductsService.updateProduct(
      productId,
      {'isPublic': newVisibility},
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _products[index]['isPublic'] = currentVisibility;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذر تغيير حالة ظهور المنتج',
              'Could not change product visibility',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newVisibility
              ? t(
            '👁 أصبح المنتج ظاهراً للزبائن',
            '👁 Product is now visible to customers',
          )
              : t(
            '🙈 تم إخفاء المنتج',
            '🙈 Product has been hidden',
          ),
          style: GoogleFonts.cairo(),
        ),
        backgroundColor:
        newVisibility ? Colors.green : Colors.grey.shade700,
      ),
    );
  }

  void _deleteProduct(int index) {
    final p = _products[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('حذف المنتج', 'Delete Product'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('هل أنت متأكد من حذف هذا المنتج؟',
              'Are you sure you want to delete this product?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok =
              await ProductsService.deleteProduct(p['id'].toString());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? t('? تم حذف المنتج', '? Product deleted')
                      : t('? فشل الحذف', '? Delete failed')),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
                if (ok) _loadProducts();
              }
            },
            child: Text(t('حذف', 'Delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
