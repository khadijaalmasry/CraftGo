import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/exhibitions_service.dart';
import 'customer_exhibition_detail_screen.dart';
import 'product_details_page.dart';
import 'artisan_profile_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FavoritesScreen — المفضلة (Craftsmen, Products, Exhibitions)
// ─────────────────────────────────────────────────────────────────────────────

class FavoritesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const FavoritesScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _craftsmen = [];
  List<dynamic> _products = [];
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch interactions
      final response = await ApiService.get('/interactions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final interactions = data is List
            ? data
            : (data['interactions'] ?? data['data'] ?? []) as List;

        // 2. Product favorites (like interactions)
        final productFavs = interactions
            .where((i) =>
                i['interactionType'] == 'like' ||
                i['type'] == 'like' ||
                i['type'] == 'favorite_product' ||
                i['type'] == 'wishlist')
            .toList();

        // 3. Extract craftsmen from product favorites
        final Set<String> seenCraftsmen = {};
        final craftsmenFavs = productFavs.where((i) {
          final p = i['Product'] ?? {};
          final craftsmanId = p['craftsmanId']?.toString() ?? '';
          if (craftsmanId.isEmpty) return false;
          return seenCraftsmen.add(craftsmanId);
        }).toList();

        if (mounted) {
          setState(() {
            _craftsmen = craftsmenFavs;
            _products = productFavs;
          });
        }
      }

      // 4. Fetch interested exhibitions (and filter by active/upcoming)
      final exhibResponse = await ApiService.get('/interactions/exhibitions');
      if (exhibResponse.statusCode == 200) {
        final data = jsonDecode(exhibResponse.body);
        final exhibitions = data['exhibitions'] as List? ?? [];
        final now = DateTime.now();
        final filteredExhibitions = exhibitions
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((ex) {
          final end = DateTime.tryParse(ex['endDate']?.toString() ?? '');
          if (end == null) return false;
          return end.isAfter(now) || end.isAtSameMomentAs(now);
        }).toList();

        if (mounted) {
          setState(() {
            _exhibitions = filteredExhibitions;
          });
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleExhibitionInterest(
      Map<String, dynamic> exhibition) async {
    final id = exhibition['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final result = await ExhibitionsService.toggleInterest(id);

    if (mounted) {
      if (result) {
        // If added, keep it in the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('✅ تمت إضافة المعرض إلى المفضلة',
                  'Exhibition added to favorites'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // If removed, remove from the list
        setState(() {
          _exhibitions.removeWhere((e) => e['id']?.toString() == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('تمت إزالة المعرض من المفضلة',
                  'Exhibition removed from favorites'),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Refresh the list
      await _fetchFavorites();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            t('المفضلة', 'My Favorites'),
            style: GoogleFonts.cairo(
                color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: accent),
              onPressed: _fetchFavorites,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: dim,
            labelStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: t('الحرفيين', 'Craftsmen')),
              Tab(text: t('المنتجات', 'Products')),
              Tab(text: t('المعارض', 'Exhibitions')),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildCraftsmenList(),
                  _buildProductsList(),
                  _buildExhibitionsList(),
                ],
              ),
      ),
    );
  }

  // ─── Craftsmen List ──────────────────────────────────────────────────────
  Widget _buildCraftsmenList() {
    if (_craftsmen.isEmpty) {
      return _buildEmptyState(
          t('لا يوجد حرفيين مفضلين حالياً', 'No favorite craftsmen yet.'));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _craftsmen.length,
      itemBuilder: (context, index) {
        final interaction = _craftsmen[index];
        final p = interaction['Product'] ?? {};
        final c = p['Craftsman'] ?? interaction['Craftsman'] ?? interaction;
        final profile = c['ArtisanProfile'] ?? {};
        final name = c['name'] ?? '—';
        final craftAr = profile['craftAr'] ?? c['craftAr'] ?? '';
        final craftEn = profile['craftEn'] ?? c['craftEn'] ?? craftAr;
        final rating = profile['averageRating'] ?? c['rating'] ?? 0;
        final imageUrl = (profile['profileImage'] ?? c['avatar']) as String?;
        final id = (c['id'])?.toString() ?? '';

        // Build artisan map for detail navigation
        final artisanMap = {
          'id': id,
          'name': name,
          'nameEn': name,
          'craftAr': craftAr,
          'craftEn': craftEn,
          'rating': rating,
          'profileImage': imageUrl,
          'ArtisanProfile': profile,
        };

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtisanProfilePage(
                  artisan: artisanMap,
                  isArabic: widget.isArabic,
                  isDarkMode: widget.isDarkMode,
                  isGuest: false,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Icon(Icons.person, color: accent, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      Text(
                        t(craftAr, craftEn),
                        style: GoogleFonts.cairo(color: dim, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.cairo(
                                color: text,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: () => _removeFavorite('craftsman', id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Products List ──────────────────────────────────────────────────────
  Widget _buildProductsList() {
    if (_products.isEmpty) {
      return _buildEmptyState(
          t('لا يوجد منتجات مفضلة حالياً', 'No favorite products yet.'));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final interaction = _products[index];
        final p =
            interaction['Product'] ?? interaction['target'] ?? interaction;
        final nameAr = p['titleAr'] ?? p['nameAr'] ?? p['title'] ?? '—';
        final nameEn = p['titleEn'] ?? p['nameEn'] ?? nameAr;
        final price = p['price']?.toString() ?? '?';
        final imageUrl = p['imageUrl'] as String?;
        final craftsman = p['Craftsman']?['name'] ?? p['artisan'] ?? '';
        final id = (p['id'] ?? interaction['targetId'])?.toString() ?? '';

        // Build product map for detail navigation
        final productMap = Map<String, dynamic>.from(p)
          ..['id'] = id
          ..['titleAr'] = nameAr
          ..['titleEn'] = nameEn
          ..['imageUrl'] = imageUrl
          ..['craftsman'] = craftsman;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsPage(
                  product: productMap,
                  isArabic: widget.isArabic,
                  isDarkMode: widget.isDarkMode,
                  isGuest: false,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageUrl == null
                      ? Icon(Icons.shopping_bag_outlined,
                          color: accent, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(nameAr, nameEn),
                        style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (craftsman.isNotEmpty)
                        Text(
                          t('صنع بواسطة $craftsman', 'By $craftsman'),
                          style: GoogleFonts.cairo(color: dim, fontSize: 11),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '$price JOD',
                        style: GoogleFonts.cairo(
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: () => _removeFavorite('product', id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Exhibitions List ──────────────────────────────────────────────────
  Widget _buildExhibitionsList() {
    if (_exhibitions.isEmpty) {
      return _buildEmptyState(
          t('لا يوجد معارض مفضلة حالياً', 'No favorite exhibitions yet.'));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _exhibitions.length,
      itemBuilder: (context, index) {
        final ex = _exhibitions[index];
        final name = widget.isArabic
            ? (ex['name'] ?? ex['nameEn'] ?? 'معرض')
            : (ex['nameEn'] ?? ex['name'] ?? 'Exhibition');
        final location = widget.isArabic
            ? (ex['location'] ?? ex['city'] ?? '')
            : (ex['locationEn'] ?? ex['city'] ?? '');
        final startDate = ex['startDate']?.toString().split('T')[0] ?? '';
        final endDate = ex['endDate']?.toString().split('T')[0] ?? '';
        final status = ex['status'] ?? 'upcoming';
        final imageUrl = ex['imageUrl'] as String?;

        // Status color
        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'active':
            statusColor = Colors.green;
            statusLabel = t('نشط', 'Active');
            break;
          case 'upcoming':
            statusColor = Colors.blue;
            statusLabel = t('قادم', 'Upcoming');
            break;
          case 'past':
            statusColor = Colors.grey;
            statusLabel = t('منتهي', 'Past');
            break;
          default:
            statusColor = Colors.orange;
            statusLabel = status;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerExhibitionDetailScreen(
                  exhibition: ex,
                ),
              ),
            ).then((_) => _fetchFavorites());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageUrl == null
                      ? Icon(Icons.museum_outlined, color: accent, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: dim),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(color: dim, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: dim),
                          const SizedBox(width: 4),
                          Text(
                            '$startDate - $endDate',
                            style: TextStyle(color: dim, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent),
                  onPressed: () => _toggleExhibitionInterest(ex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeFavorite(String type, String id) async {
    try {
      await ApiService.post('/interactions', body: {
        'type':
            type == 'craftsman' ? 'unfavorite_craftsman' : 'unfavorite_product',
        'targetId': id,
      });
    } catch (_) {}
    setState(() {
      if (type == 'craftsman') {
        _craftsmen
            .removeWhere((c) => (c['targetId'] ?? c['id'])?.toString() == id);
      } else {
        _products
            .removeWhere((p) => (p['targetId'] ?? p['id'])?.toString() == id);
      }
    });
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: border,
            ),
            child: Icon(Icons.favorite_border, size: 60, color: dim),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: dim, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _fetchFavorites,
            icon: Icon(Icons.refresh, color: accent),
            label: Text(t('تحديث', 'Refresh'), style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'dart:convert';
// import '../../services/api_service.dart';
// import '../../services/exhibitions_service.dart';
// import 'customer_exhibition_detail_screen.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // FavoritesScreen — المفضلة (Craftsmen, Products, Exhibitions)
// // ─────────────────────────────────────────────────────────────────────────────

// class FavoritesScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;

//   const FavoritesScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//   });

//   @override
//   State<FavoritesScreen> createState() => _FavoritesScreenState();
// }

// class _FavoritesScreenState extends State<FavoritesScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;

//   List<dynamic> _craftsmen = [];
//   List<dynamic> _products = [];
//   List<Map<String, dynamic>> _exhibitions = [];
//   bool _isLoading = true;

//   // Theme colors
//   Color get bg =>
//       widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get surface =>
//       widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
//   Color get border => widget.isDarkMode
//       ? Colors.white.withValues(alpha: 0.1)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get accent =>
//       widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _fetchFavorites();
//   }

//   Future<void> _fetchFavorites() async {
//     setState(() => _isLoading = true);
//     try {
//       // 1. Fetch interactions
//       final response = await ApiService.get('/interactions');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final interactions = data is List
//             ? data
//             : (data['interactions'] ?? data['data'] ?? []) as List;

//         // 2. Product favorites (like interactions)
//         final productFavs = interactions
//             .where((i) =>
//                 i['interactionType'] == 'like' ||
//                 i['type'] == 'like' ||
//                 i['type'] == 'favorite_product' ||
//                 i['type'] == 'wishlist')
//             .toList();

//         // 3. Extract craftsmen from product favorites
//         final Set<String> seenCraftsmen = {};
//         final craftsmenFavs = productFavs.where((i) {
//           final p = i['Product'] ?? {};
//           final craftsmanId = p['craftsmanId']?.toString() ?? '';
//           if (craftsmanId.isEmpty) return false;
//           return seenCraftsmen.add(craftsmanId);
//         }).toList();

//         if (mounted) {
//           setState(() {
//             _craftsmen = craftsmenFavs;
//             _products = productFavs;
//           });
//         }
//       }

//       // 4. Fetch interested exhibitions
//       final exhibResponse = await ApiService.get('/interactions/exhibitions');
//       if (exhibResponse.statusCode == 200) {
//         final data = jsonDecode(exhibResponse.body);
//         final exhibitions = data['exhibitions'] as List? ?? [];
//         if (mounted) {
//           setState(() {
//             _exhibitions = exhibitions
//                 .map((e) => Map<String, dynamic>.from(e as Map))
//                 .toList();
//           });
//         }
//       }

//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       debugPrint('Error fetching favorites: $e');
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _toggleExhibitionInterest(
//       Map<String, dynamic> exhibition) async {
//     final id = exhibition['id']?.toString() ?? '';
//     if (id.isEmpty) return;

//     final result = await ExhibitionsService.toggleInterest(id);

//     if (mounted) {
//       if (result) {
//         // If added, keep it in the list
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               t('✅ تمت إضافة المعرض إلى المفضلة',
//                   'Exhibition added to favorites'),
//             ),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // If removed, remove from the list
//         setState(() {
//           _exhibitions.removeWhere((e) => e['id']?.toString() == id);
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               t('تمت إزالة المعرض من المفضلة',
//                   'Exhibition removed from favorites'),
//             ),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//       // Refresh the list
//       await _fetchFavorites();
//     }
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Directionality(
//       textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: surface,
//           elevation: 0,
//           leading: IconButton(
//             icon: Icon(
//                 widget.isArabic
//                     ? Icons.arrow_forward_ios
//                     : Icons.arrow_back_ios,
//                 color: text,
//                 size: 20),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: Text(
//             t('المفضلة', 'My Favorites'),
//             style: GoogleFonts.cairo(
//                 color: text, fontWeight: FontWeight.bold, fontSize: 18),
//           ),
//           centerTitle: true,
//           actions: [
//             IconButton(
//               icon: Icon(Icons.refresh, color: accent),
//               onPressed: _fetchFavorites,
//             ),
//           ],
//           bottom: TabBar(
//             controller: _tabController,
//             indicatorColor: accent,
//             labelColor: accent,
//             unselectedLabelColor: dim,
//             labelStyle:
//                 GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
//             tabs: [
//               Tab(text: t('الحرفيين', 'Craftsmen')),
//               Tab(text: t('المنتجات', 'Products')),
//               Tab(text: t('المعارض', 'Exhibitions')),
//             ],
//           ),
//         ),
//         body: _isLoading
//             ? Center(child: CircularProgressIndicator(color: accent))
//             : TabBarView(
//                 controller: _tabController,
//                 children: [
//                   _buildCraftsmenList(),
//                   _buildProductsList(),
//                   _buildExhibitionsList(),
//                 ],
//               ),
//       ),
//     );
//   }

//   // ─── Craftsmen List ──────────────────────────────────────────────────────
//   Widget _buildCraftsmenList() {
//     if (_craftsmen.isEmpty) {
//       return _buildEmptyState(
//           t('لا يوجد حرفيين مفضلين حالياً', 'No favorite craftsmen yet.'));
//     }
//     return ListView.builder(
//       physics: const BouncingScrollPhysics(),
//       padding: const EdgeInsets.all(16),
//       itemCount: _craftsmen.length,
//       itemBuilder: (context, index) {
//         final interaction = _craftsmen[index];
//         final p = interaction['Product'] ?? {};
//         final c = p['Craftsman'] ?? interaction['Craftsman'] ?? interaction;
//         final profile = c['ArtisanProfile'] ?? {};
//         final name = c['name'] ?? '—';
//         final craftAr = profile['craftAr'] ?? c['craftAr'] ?? '';
//         final craftEn = profile['craftEn'] ?? c['craftEn'] ?? craftAr;
//         final rating = profile['averageRating'] ?? c['rating'] ?? 0;
//         final imageUrl = (profile['profileImage'] ?? c['avatar']) as String?;
//         final id = (c['id'])?.toString() ?? '';

//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: border),
//           ),
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 28,
//                 backgroundColor: accent.withValues(alpha: 0.15),
//                 backgroundImage:
//                     imageUrl != null ? NetworkImage(imageUrl) : null,
//                 child: imageUrl == null
//                     ? Icon(Icons.person, color: accent, size: 28)
//                     : null,
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name,
//                       style: GoogleFonts.cairo(
//                           color: text,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 15),
//                     ),
//                     Text(
//                       t(craftAr, craftEn),
//                       style: GoogleFonts.cairo(color: dim, fontSize: 12),
//                     ),
//                     const SizedBox(height: 6),
//                     Row(
//                       children: [
//                         const Icon(Icons.star, color: Colors.amber, size: 14),
//                         const SizedBox(width: 4),
//                         Text(
//                           rating.toString(),
//                           style: GoogleFonts.cairo(
//                               color: text,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.favorite, color: Colors.redAccent),
//                 onPressed: () => _removeFavorite('craftsman', id),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // ─── Products List ──────────────────────────────────────────────────────
//   Widget _buildProductsList() {
//     if (_products.isEmpty) {
//       return _buildEmptyState(
//           t('لا يوجد منتجات مفضلة حالياً', 'No favorite products yet.'));
//     }
//     return ListView.builder(
//       physics: const BouncingScrollPhysics(),
//       padding: const EdgeInsets.all(16),
//       itemCount: _products.length,
//       itemBuilder: (context, index) {
//         final interaction = _products[index];
//         final p =
//             interaction['Product'] ?? interaction['target'] ?? interaction;
//         final nameAr = p['titleAr'] ?? p['nameAr'] ?? p['title'] ?? '—';
//         final nameEn = p['titleEn'] ?? p['nameEn'] ?? nameAr;
//         final price = p['price']?.toString() ?? '?';
//         final imageUrl = p['imageUrl'] as String?;
//         final craftsman = p['Craftsman']?['name'] ?? p['artisan'] ?? '';
//         final id = (p['id'] ?? interaction['targetId'])?.toString() ?? '';

//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: border),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 60,
//                 height: 60,
//                 decoration: BoxDecoration(
//                   color: accent.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   image: imageUrl != null
//                       ? DecorationImage(
//                           image: NetworkImage(imageUrl), fit: BoxFit.cover)
//                       : null,
//                 ),
//                 child: imageUrl == null
//                     ? Icon(Icons.shopping_bag_outlined, color: accent, size: 28)
//                     : null,
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       t(nameAr, nameEn),
//                       style: GoogleFonts.cairo(
//                           color: text,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     if (craftsman.isNotEmpty)
//                       Text(
//                         t('صنع بواسطة $craftsman', 'By $craftsman'),
//                         style: GoogleFonts.cairo(color: dim, fontSize: 11),
//                       ),
//                     const SizedBox(height: 6),
//                     Text(
//                       '$price JOD',
//                       style: GoogleFonts.cairo(
//                           color: const Color(0xFF4CAF50),
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 12),
//               IconButton(
//                 icon: const Icon(Icons.favorite, color: Colors.redAccent),
//                 onPressed: () => _removeFavorite('product', id),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // ─── Exhibitions List ──────────────────────────────────────────────────
//   Widget _buildExhibitionsList() {
//     if (_exhibitions.isEmpty) {
//       return _buildEmptyState(
//           t('لا يوجد معارض مفضلة حالياً', 'No favorite exhibitions yet.'));
//     }
//     return ListView.builder(
//       physics: const BouncingScrollPhysics(),
//       padding: const EdgeInsets.all(16),
//       itemCount: _exhibitions.length,
//       itemBuilder: (context, index) {
//         final ex = _exhibitions[index];
//         final name = widget.isArabic
//             ? (ex['name'] ?? ex['nameEn'] ?? 'معرض')
//             : (ex['nameEn'] ?? ex['name'] ?? 'Exhibition');
//         final location = widget.isArabic
//             ? (ex['location'] ?? ex['city'] ?? '')
//             : (ex['locationEn'] ?? ex['city'] ?? '');
//         final startDate = ex['startDate']?.toString().split('T')[0] ?? '';
//         final endDate = ex['endDate']?.toString().split('T')[0] ?? '';
//         final status = ex['status'] ?? 'upcoming';
//         final imageUrl = ex['imageUrl'] as String?;

//         // Status color
//         Color statusColor;
//         String statusLabel;
//         switch (status) {
//           case 'active':
//             statusColor = Colors.green;
//             statusLabel = t('نشط', 'Active');
//             break;
//           case 'upcoming':
//             statusColor = Colors.blue;
//             statusLabel = t('قادم', 'Upcoming');
//             break;
//           case 'past':
//             statusColor = Colors.grey;
//             statusLabel = t('منتهي', 'Past');
//             break;
//           default:
//             statusColor = Colors.orange;
//             statusLabel = status;
//         }

//         return GestureDetector(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => CustomerExhibitionDetailScreen(
//                   exhibition: ex,
//                 ),
//               ),
//             ).then((_) => _fetchFavorites());
//           },
//           child: Container(
//             margin: const EdgeInsets.only(bottom: 12),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: surface,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: border),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.04),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   width: 64,
//                   height: 64,
//                   decoration: BoxDecoration(
//                     color: accent.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(12),
//                     image: imageUrl != null
//                         ? DecorationImage(
//                             image: NetworkImage(imageUrl), fit: BoxFit.cover)
//                         : null,
//                   ),
//                   child: imageUrl == null
//                       ? Icon(Icons.museum_outlined, color: accent, size: 28)
//                       : null,
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               name,
//                               style: GoogleFonts.cairo(
//                                 color: text,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 2,
//                             ),
//                             decoration: BoxDecoration(
//                               color: statusColor.withValues(alpha: 0.12),
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(
//                                 color: statusColor.withValues(alpha: 0.3),
//                               ),
//                             ),
//                             child: Text(
//                               statusLabel,
//                               style: TextStyle(
//                                 color: statusColor,
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Icon(Icons.location_on_outlined,
//                               size: 12, color: dim),
//                           const SizedBox(width: 4),
//                           Expanded(
//                             child: Text(
//                               location,
//                               style: TextStyle(color: dim, fontSize: 11),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 2),
//                       Row(
//                         children: [
//                           Icon(Icons.calendar_today_outlined,
//                               size: 12, color: dim),
//                           const SizedBox(width: 4),
//                           Text(
//                             '$startDate - $endDate',
//                             style: TextStyle(color: dim, fontSize: 11),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.favorite_rounded,
//                       color: Colors.redAccent),
//                   onPressed: () => _toggleExhibitionInterest(ex),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _removeFavorite(String type, String id) async {
//     try {
//       await ApiService.post('/interactions', body: {
//         'type':
//             type == 'craftsman' ? 'unfavorite_craftsman' : 'unfavorite_product',
//         'targetId': id,
//       });
//     } catch (_) {}
//     setState(() {
//       if (type == 'craftsman') {
//         _craftsmen
//             .removeWhere((c) => (c['targetId'] ?? c['id'])?.toString() == id);
//       } else {
//         _products
//             .removeWhere((p) => (p['targetId'] ?? p['id'])?.toString() == id);
//       }
//     });
//   }

//   Widget _buildEmptyState(String message) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: border,
//             ),
//             child: Icon(Icons.favorite_border, size: 60, color: dim),
//           ),
//           const SizedBox(height: 20),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 40),
//             child: Text(
//               message,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.cairo(color: dim, fontSize: 14),
//             ),
//           ),
//           const SizedBox(height: 16),
//           TextButton.icon(
//             onPressed: _fetchFavorites,
//             icon: Icon(Icons.refresh, color: accent),
//             label: Text(t('تحديث', 'Refresh'), style: TextStyle(color: accent)),
//           ),
//         ],
//       ),
//     );
//   }
// }
