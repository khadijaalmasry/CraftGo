import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../custom_order/browse_templates_screen.dart';
import '../hire_order/create_job_screen.dart';
import '../../services/api_service.dart';
import 'product_details_page.dart';
import '../../services/chat_service.dart';
import '../../services/session_service.dart';
import 'chat_detail_screen.dart';
// ─────────────────────────────────────────────────────────────────────────────
// ArtisanProfilePage — matched to ClientDashboard theme
// ─────────────────────────────────────────────────────────────────────────────

class ArtisanProfilePage extends StatefulWidget {
  final Map<String, dynamic> artisan;
  final bool isArabic;
  final bool isDarkMode;
  final bool isGuest;

  const ArtisanProfilePage({
    super.key,
    required this.artisan,
    required this.isArabic,
    required this.isDarkMode,
    this.isGuest = false,
  });

  @override
  State<ArtisanProfilePage> createState() => _ArtisanProfilePageState();
}

class _ArtisanProfilePageState extends State<ArtisanProfilePage>
    with SingleTickerProviderStateMixin {
  late bool isArabic;
  late bool isDarkMode;

  bool _following = false;
  bool _isFavorite = false;
  late TabController _tabController;

  // ── Calendar state ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(
      () => setState(() {}),
    );
    _fetchArtisanData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _realProducts = [];
  List<dynamic> _realReviews = [];
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;

  Future<void> _fetchArtisanData() async {
    try {
      final artisanId =
          (widget.artisan['id'] ?? widget.artisan['artisanId'])?.toString();

      if (artisanId == null || artisanId.trim().isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final responses = await Future.wait([
        ApiService.get('/craftsman/profile/$artisanId'),
        ApiService.get('/products/craftsman/$artisanId'),
        ApiService.get('/craftsmen/reviews/$artisanId'),
        ApiService.get('/exhibitions/craftsman/$artisanId'),
      ]);

      final profileRes = responses[0];
      final productsRes = responses[1];
      final reviewsRes = responses[2];
      final exhibitionsRes = responses[3];

      if (!mounted) return;

      setState(() {
        if (profileRes.statusCode == 200) {
          final decoded = jsonDecode(profileRes.body);
          if (decoded is Map) {
            _profileData = Map<String, dynamic>.from(decoded);
            debugPrint('PROFILE DATA: ${jsonEncode(_profileData)}');
          }
        }

        if (productsRes.statusCode == 200) {
          final decoded = jsonDecode(productsRes.body);
          _realProducts = _extractProducts(decoded)
              .where(_isPublicProduct)
              .map(_normalizeProduct)
              .toList();
        }

        if (reviewsRes.statusCode == 200) {
          final decoded = jsonDecode(reviewsRes.body);
          if (decoded is Map) {
            _realReviews = (decoded['reviews'] as List?) ?? [];
          } else if (decoded is List) {
            _realReviews = decoded;
          }
        }

        if (exhibitionsRes.statusCode == 200) {
          final decoded = jsonDecode(exhibitionsRes.body);
          final registrations = decoded is List
              ? decoded
              : (decoded is Map && decoded['registrations'] is List
                  ? decoded['registrations'] as List
                  : <dynamic>[]);

          final now = DateTime.now();

          _events = registrations
              .whereType<Map>()
              .map((registrationRaw) {
                final registration = Map<String, dynamic>.from(registrationRaw);

                final exhibitionRaw =
                    registration['Exhibition'] ?? registration['exhibition'];

                if (exhibitionRaw is! Map) {
                  return null;
                }

                final exhibition = Map<String, dynamic>.from(exhibitionRaw);

                final status =
                    (registration['status'] ?? '').toString().toLowerCase();

                final startDateRaw =
                    exhibition['startDate'] ?? exhibition['date'];

                final startDate = DateTime.tryParse(
                  startDateRaw?.toString() ?? '',
                );

                if (startDate == null) {
                  return null;
                }

                // Public profile shows only confirmed, current/upcoming events.
                if (status.isNotEmpty && status != 'confirmed') {
                  return null;
                }

                final dayStart =
                    DateTime(startDate.year, startDate.month, startDate.day);
                final todayStart = DateTime(now.year, now.month, now.day);

                if (dayStart.isBefore(todayStart)) {
                  return null;
                }

                final name = (exhibition['name'] ?? exhibition['title'] ?? '')
                    .toString();
                final location = (exhibition['location'] ?? '').toString();

                return <String, dynamic>{
                  'id': (exhibition['id'] ?? '').toString(),
                  'titleAr': name,
                  'titleEn': name,
                  'date': startDate,
                  'locationAr': location,
                  'locationEn': location,
                  'registrationStatus': status,
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort(
              (a, b) =>
                  (a['date'] as DateTime).compareTo(b['date'] as DateTime),
            );
        } else {
          _events = [];
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching artisan data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _extractProducts(dynamic decoded) {
    dynamic rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      rawList = decoded['products'] ?? decoded['Products'] ?? decoded['items'];
      final data = decoded['data'];
      if (rawList == null && data is List) rawList = data;
      if (rawList == null && data is Map) {
        rawList = data['products'] ?? data['Products'] ?? data['items'];
      }
    }

    if (rawList is! List) return <Map<String, dynamic>>[];
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool _isPublicProduct(Map<String, dynamic> product) {
    final value =
        product['isPublic'] ?? product['public'] ?? product['is_public'];
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'public';
  }

  String _firstText(Iterable<dynamic> values, [String fallback = '']) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  String _productImageUrl(Map<String, dynamic> product) {
    final direct = _firstText([
      product['imageUrl'],
      product['imageURL'],
      product['image'],
      product['productImage'],
      product['thumbnailUrl'],
      product['thumbnail'],
    ]);
    if (direct.isNotEmpty) return direct;

    final images = product['images'] ?? product['Images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        return _firstText([
          first['url'],
          first['imageUrl'],
          first['secure_url'],
          first['path'],
        ]);
      }
      return _firstText([first]);
    }
    return '';
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> raw) {
    final titleAr = _firstText([
      raw['titleAr'],
      raw['nameAr'],
      raw['title'],
      raw['name'],
      raw['productName'],
    ], t('منتج يدوي', 'Handmade Product'));
    final titleEn = _firstText([
      raw['titleEn'],
      raw['nameEn'],
      raw['title'],
      raw['name'],
      raw['productName'],
      titleAr,
    ], 'Handmade Product');
    final imageUrl = _productImageUrl(raw);
    final price = double.tryParse(
          (raw['price'] ?? raw['productPrice'] ?? raw['amount'] ?? 0)
              .toString(),
        ) ??
        0.0;

    // Keep every original backend field and add the aliases used by the
    // profile card and ProductDetailsPage.
    return <String, dynamic>{
      ...raw,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'title': _firstText([raw['title'], titleEn]),
      'nameAr': titleAr,
      'nameEn': titleEn,
      'name': _firstText([raw['name'], titleEn]),
      'imageUrl': imageUrl,
      'image': _firstText([raw['image'], imageUrl]),
      'price': price,
      'isPublic': true,
      // ProductDetailsPage needs the real owner information. The
      // craftsman-products endpoint does not always repeat it per product,
      // so pass the profile that is already loaded on this page.
      'artisan': raw['artisan'] ??
          raw['Artisan'] ??
          raw['craftsman'] ??
          raw['Craftsman'] ??
          raw['User'] ??
          raw['user'] ??
          _profileData,
    };
  }

  void _toggleFollow() async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }
    setState(() => _following = !_following);
    try {
      await ApiService.post('/interactions', body: {
        'productId': widget.artisan['id']?.toString() ?? '',
        'interactionType': _following ? 'follow' : 'unfollow',
      });
    } catch (e) {
      debugPrint('Follow error: $e');
    }
  }

  void _toggleFavorite() async {
    if (widget.isGuest) {
      _showGuestPrompt();
      return;
    }
    setState(() => _isFavorite = !_isFavorite);
    _showSnack(
      _isFavorite
          ? t('أُضيف للمفضلة ❤', 'Added to Favorites ❤')
          : t('أُزيل من المفضلة', 'Removed from Favorites'),
    );
    // Artisan favorites are tracked by liking one of their products
    // or via the interaction log for the profile visit
    try {
      await ApiService.post('/interactions', body: {
        'productId': widget.artisan['id']?.toString() ?? '',
        'interactionType': _isFavorite ? 'like' : 'unlike',
      });
    } catch (e) {
      debugPrint('Favorite error: $e');
    }
  }

  // ── Theme-aware colors (mirroring ClientDashboard) ──────────────────────
  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;

  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;

  Color get cardBorderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  Color get topButtonBackground =>
      isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  static const Color _gold = Color(0xFFD4A017);
  static const Color _starGold = Color(0xFFF7B500);

  String t(String ar, String en) => isArabic ? ar : en;

  // Exhibition events are loaded from the backend in _fetchArtisanData().

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Returns the event that matches the given date, or null.
  Map<String, dynamic>? _getEventForDate(DateTime date) {
    try {
      return _events.firstWhere(
        (e) =>
            e["date"].year == date.year &&
            e["date"].month == date.month &&
            e["date"].day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Shows a dialog with event details when a day with an event is tapped.
  void _showEventDetails(DateTime date) {
    final event = _getEventForDate(date);
    if (event == null) {
      _showSnack(t('لا يوجد حدث في هذا اليوم', 'No event on this day'));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: topButtonBackground,
        title: Text(
          t(event["titleAr"], event["titleEn"]),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: _gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  "${date.day}/${date.month}/${date.year}",
                  style: TextStyle(color: secondaryTextColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, color: _gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  t(event["locationAr"], event["locationEn"]),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('إغلاق', 'Close'), style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
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
                    ? "يرجى تسجيل الدخول للاستفادة من هذه الميزة والتواصل مع أمهر الحرفيين."
                    : "Please log in to use this feature and connect with the best craftsmen.",
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

  // ── Navigate to Browse Templates ──────────────────────────────────────────
  void _showCustomOrderForm() {
    // Navigate to the Browse Templates screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseTemplatesScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          artisanId: widget.artisan['id']?.toString() ?? widget.artisan['id'],
          artisanName:
              isArabic ? widget.artisan['nameAr'] : widget.artisan['nameEn'],
        ),
      ),
    );
  }

  void _showHireForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          artisanId: widget.artisan['id']?.toString() ?? 'artisan-amjad',
          artisanName:
              isArabic ? widget.artisan['nameAr'] : widget.artisan['nameEn'],
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    try {
      final craftsmanId =
          (widget.artisan['id'] ?? widget.artisan['artisanId']).toString();

      if (craftsmanId.isEmpty) {
        _showSnack(t('تعذر تحديد الحرفي', 'Could not identify artisan'));
        return;
      }

      final chat = await ChatService.createOrGetChat(
        otherUserId: craftsmanId,
        otherUserRole:
            'craftsman', // or 'artisan' depending on your role naming
      );

      if (chat == null) {
        _showSnack(t('تعذر فتح المحادثة', 'Could not open chat'));
        return;
      }

      final currentUserId = await SessionService.getUserId() ?? '';

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            isArabic: isArabic,
            isDarkMode: isDarkMode,
            chatId: chat['id'].toString(),
            currentUserId: currentUserId,
            otherUserId: craftsmanId,
            name: _firstText([
              isArabic ? widget.artisan['nameAr'] : widget.artisan['nameEn'],
              widget.artisan['name'],
              widget.artisan['nameAr'],
              widget.artisan['nameEn'],
              chat['name'],
              chat['otherUserName'],
            ], t('حرفي', 'Artisan')),
            craft: _firstText([
              isArabic ? widget.artisan['craftAr'] : widget.artisan['craftEn'],
              widget.artisan['craft'],
              widget.artisan['craftAr'],
              widget.artisan['craftEn'],
            ], t('حرفي', 'Artisan')),
            online: false,
            orderTitle: '',
            orderStatus: '',
            orderPrice: '',
            avatarUrl: widget.artisan['image']?.toString(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Open chat error: $e');
      _showSnack(t('حدث خطأ أثناء فتح المحادثة', 'Failed to open chat'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = <String, dynamic>{
      ...widget.artisan,
      ..._profileData,
    };

    final stats = a['stats'] is Map
        ? Map<String, dynamic>.from(a['stats'] as Map)
        : <String, dynamic>{};

    final name = (a['name'] ?? a['nameAr'] ?? a['nameEn'] ?? '').toString();
    final craft = (a['primaryCategory'] ??
            a['craftAr'] ??
            a['craftEn'] ??
            a['craft'] ??
            '')
        .toString();
    final city = (a['city'] ?? '').toString();
    final bio = (a['bio'] ?? '').toString().trim();
    final priceRange = (a['priceRange'] ?? '').toString().trim();
    final experienceYears =
        int.tryParse((a['experienceYears'] ?? 0).toString()) ?? 0;
    final specializations = (a['specializations'] is List)
        ? List<dynamic>.from(a['specializations'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final rating = stats['rating'] ?? a['rating'] ?? a['averageRating'];
    final completedOrders =
        stats['completedOrders'] ?? a['completedOrders'] ?? a['jobs'] ?? 0;
    final followersCount = a['followersCount'] ?? 0;
    final avatarUrl = _firstText([
      a['profileImage'],
      a['profileImageUrl'],
      a['avatarUrl'],
      a['avatar'],
      a['imageUrl'],
      a['image'],
    ]);
    final avatarIsNetwork = avatarUrl.startsWith('http://') ||
        avatarUrl.startsWith('https://') ||
        avatarUrl.startsWith('data:') ||
        avatarUrl.startsWith('blob:');
    final ImageProvider<Object>? avatarProvider = avatarUrl.isEmpty
        ? null
        : avatarIsNetwork
            ? NetworkImage(avatarUrl) as ImageProvider<Object>
            : AssetImage(avatarUrl) as ImageProvider<Object>;

    // Get list of event dates for the calendar dots.
    final eventDates = _events.map((e) => e["date"] as DateTime).toList();

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,

        // ── Sticky bottom bar ────────────────────────────────────────────
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: topButtonBackground,
            border: Border(top: BorderSide(color: cardBorderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.isGuest
                      ? _showGuestPrompt
                      : () => _showCustomOrderForm(),
                  icon: Icon(Icons.edit_outlined, size: 16, color: _gold),
                  label: Text(
                    t('طلب مخصص', 'Custom Order'),
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: _gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      widget.isGuest ? _showGuestPrompt : () => _showHireForm(),
                  icon: const Icon(
                    Icons.handshake_outlined,
                    size: 16,
                    color: Colors.black,
                  ),
                  label: Text(
                    t('استئجار / موقع', 'Hire / On-Site'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Cover + AppBar ───────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: backgroundColor,
              leading: _CircleBtn(
                icon: isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                onTap: () => Navigator.pop(context),
                bg: topButtonBackground,
                iconColor: primaryTextColor,
                border: cardBorderColor,
              ),
              actions: [
                // ── Favourite heart button ──
                GestureDetector(
                  onTap: _toggleFavorite,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isFavorite
                          ? const Color(0xFFE53935).withValues(alpha: 0.15)
                          : topButtonBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isFavorite
                            ? const Color(0xFFE53935).withValues(alpha: 0.6)
                            : cardBorderColor,
                        width: 1.5,
                      ),
                      boxShadow: _isFavorite
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFE53935,
                                ).withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite
                          ? const Color(0xFFE53935)
                          : primaryTextColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CircleBtn(
                  icon: Icons.share_outlined,
                  onTap: () {},
                  bg: topButtonBackground,
                  iconColor: primaryTextColor,
                  border: cardBorderColor,
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xFF1C2431), const Color(0xFF0D1420)]
                          : [const Color(0xFFE8EAF0), const Color(0xFFF5F6F8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Avatar + name + follow row ───────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF0D1420)
                                  : Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: _gold.withValues(alpha: 0.2),
                            backgroundImage: avatarProvider,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0] : '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: _gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.arefRuqaa(
                                        color: primaryTextColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (a['isVerified'] == true) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.verified_rounded,
                                      color: _gold,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                craft,
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    city.isNotEmpty
                                        ? city
                                        : t('لم تُحدّد المدينة',
                                            'City not specified'),
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _gold.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  priceRange.isNotEmpty
                                      ? '${t('نطاق السعر', 'Price range')}: $priceRange JOD'
                                      : t('السعر غير محدد',
                                          'Price not specified'),
                                  style: GoogleFonts.cairo(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Action buttons ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: _following
                                ? t('متابَع', 'Following')
                                : t('تابع', 'Follow'),
                            icon: _following
                                ? Icons.check_rounded
                                : Icons.person_add_outlined,
                            filled: _following,
                            accent: _gold,
                            border: cardBorderColor,
                            surface: topButtonBackground,
                            text: primaryTextColor,
                            onTap: _toggleFollow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            label: t('مراسلة', 'Message'),
                            icon: Icons.chat_bubble_outline_rounded,
                            filled: false,
                            accent: _gold,
                            border: cardBorderColor,
                            surface: topButtonBackground,
                            text: primaryTextColor,
                            onTap:
                                widget.isGuest ? _showGuestPrompt : _openChat,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Stats row ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: topButtonBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Row(
                        children: [
                          _Stat(
                            value: rating == null
                                ? t('جديد', 'New')
                                : rating.toString(),
                            labelAr: 'التقييم',
                            labelEn: 'Rating',
                            accent: _gold,
                            dim: secondaryTextColor,
                            isArabic: isArabic,
                          ),
                          _StatDivider(color: cardBorderColor),
                          _Stat(
                            value: completedOrders.toString(),
                            labelAr: 'طلب',
                            labelEn: 'Orders',
                            accent: _gold,
                            dim: secondaryTextColor,
                            isArabic: isArabic,
                          ),
                          _StatDivider(color: cardBorderColor),
                          _Stat(
                            value: followersCount.toString(),
                            labelAr: 'متابع',
                            labelEn: 'Followers',
                            accent: _gold,
                            dim: secondaryTextColor,
                            isArabic: isArabic,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Bio ──────────────────────────────────────────────
                    Text(
                      t('نبذة', 'About'),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio.isNotEmpty
                          ? bio
                          : t(
                              'لا توجد نبذة حتى الآن.',
                              'No bio available yet.',
                            ),
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 16,
                          color: _gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          experienceYears > 0
                              ? t(
                                  '$experienceYears سنوات خبرة',
                                  '$experienceYears years of experience',
                                )
                              : t('حرفي جديد', 'New artisan'),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (specializations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        t('التخصصات', 'Specializations'),
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: specializations
                            .map(
                              (item) => _Chip(
                                label: item,
                                accent: _gold,
                                surface: topButtonBackground,
                                border: cardBorderColor,
                                text: primaryTextColor,
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // ── Offer types ──────────────────────────────────────
                    Text(
                      t('أنواع الخدمات', 'Offer Types'),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _OfferType(
                          icon: Icons.inventory_2_outlined,
                          labelAr: 'جاهز للبيع',
                          labelEn: 'Ready-Made',
                          accent: _gold,
                          surface: topButtonBackground,
                          border: cardBorderColor,
                          text: primaryTextColor,
                          dim: secondaryTextColor,
                          isArabic: isArabic,
                        ),
                        const SizedBox(width: 10),
                        _OfferType(
                          icon: Icons.edit_outlined,
                          labelAr: 'طلب مخصص',
                          labelEn: 'Custom Order',
                          accent: _gold,
                          surface: topButtonBackground,
                          border: cardBorderColor,
                          text: primaryTextColor,
                          dim: secondaryTextColor,
                          isArabic: isArabic,
                        ),
                        const SizedBox(width: 10),
                        _OfferType(
                          icon: Icons.handshake_outlined,
                          labelAr: 'خدمة في الموقع',
                          labelEn: 'Hire / On-Site',
                          accent: _gold,
                          surface: topButtonBackground,
                          border: cardBorderColor,
                          text: primaryTextColor,
                          dim: secondaryTextColor,
                          isArabic: isArabic,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Products carousel ───────────────────────────────
                    Text(
                      t('الأعمال', 'Products'),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab row - Simplified to just "All Products" for real data
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _gold),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t("كل الأعمال", "All Products"),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Product carousel
                    if (_isLoading)
                      const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_realProducts.isEmpty)
                      SizedBox(
                        height: 160,
                        child: Center(
                          child: Text(
                            t(
                              'ستظهر أول أعمال هذا الحرفي هنا.',
                              'This artisan’s first products will appear here.',
                            ),
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _realProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final item = _realProducts[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailsPage(
                                      product: item,
                                      isArabic: isArabic,
                                      isDarkMode: isDarkMode,
                                      isGuest: widget.isGuest,
                                    ),
                                  ),
                                );
                              },
                              child: _ProductCard(
                                nameAr: item['titleAr'].toString(),
                                nameEn: item['titleEn'].toString(),
                                price: double.tryParse(
                                        item["price"]?.toString() ?? '0') ??
                                    0.0,
                                imageUrl: item['imageUrl']?.toString() ?? '',
                                isArabic: isArabic,
                                isDarkMode: isDarkMode,
                                accent: _gold,
                                surface: topButtonBackground,
                                border: cardBorderColor,
                                text: primaryTextColor,
                                dim: secondaryTextColor,
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Calendar & Events section ──────────────────────
                    Text(
                      t('الفعاليات القادمة', 'Upcoming Events'),
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_events.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: topButtonBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_outlined,
                              color: secondaryTextColor,
                              size: 30,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t(
                                'لا توجد فعاليات قادمة لهذا الحرفي.',
                                'This artisan has no upcoming exhibitions.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _EventCalendar(
                        eventDates: eventDates,
                        isArabic: isArabic,
                        accent: _gold,
                        textColor: primaryTextColor,
                        surfaceColor: topButtonBackground,
                        borderColor: cardBorderColor,
                        todayColor: Colors.red,
                        onDayTap: _showEventDetails,
                      ),
                      const SizedBox(height: 16),
                      ..._events.take(2).map(
                            (e) => _EventTile(
                              titleAr: e['titleAr'].toString(),
                              titleEn: e['titleEn'].toString(),
                              date: e['date'] as DateTime,
                              locationAr: e['locationAr'].toString(),
                              locationEn: e['locationEn'].toString(),
                              isArabic: isArabic,
                              accent: _gold,
                              surface: topButtonBackground,
                              border: cardBorderColor,
                              text: primaryTextColor,
                              dim: secondaryTextColor,
                              onTap: () =>
                                  _showEventDetails(e['date'] as DateTime),
                            ),
                          ),
                    ],

                    const SizedBox(height: 24),

                    // ── Reviews ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('التقييمات', 'Reviews'),
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: _starGold,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating == null
                                  ? t('جديد', 'New')
                                  : rating.toString(),
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '  (${_realReviews.length} ${t("تقييم", "reviews")})',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_realReviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            t('لا توجد تقييمات', 'No reviews yet'),
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        ),
                      )
                    else
                      ..._realReviews.map(
                        (r) => _ReviewCard(
                          nameAr: r["User"] != null
                              ? r["User"]["name"]
                              : (r["nameAr"] ?? "User"),
                          nameEn: r["User"] != null
                              ? r["User"]["name"]
                              : (r["nameEn"] ?? "User"),
                          rating: (r["rating"] as num?)?.toInt() ?? 5,
                          commentAr: r["comment"] ?? r["commentAr"] ?? "",
                          commentEn: r["comment"] ?? r["commentEn"] ?? "",
                          isArabic: isArabic,
                          accent: _gold,
                          surface: topButtonBackground,
                          border: cardBorderColor,
                          text: primaryTextColor,
                          dim: secondaryTextColor,
                        ),
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

  Widget _aiRatingBar(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.cairo(color: secondaryTextColor, fontSize: 9)),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: value,
                backgroundColor: cardBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 5,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _EventCalendar extends StatefulWidget {
  final List<DateTime> eventDates;
  final bool isArabic;
  final Color accent;
  final Color textColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color todayColor;
  final Function(DateTime) onDayTap;

  const _EventCalendar({
    required this.eventDates,
    required this.isArabic,
    required this.accent,
    required this.textColor,
    required this.surfaceColor,
    required this.borderColor,
    this.todayColor = Colors.red,
    required this.onDayTap,
  });

  @override
  State<_EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<_EventCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    // Start with current month, but if today's date is in the past, still show current month
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasEvent(DateTime date) {
    return widget.eventDates.any(
      (e) => e.year == date.year && e.month == date.month && e.day == date.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = widget.isArabic
        ? _arabicMonths[_currentMonth.month - 1]
        : _englishMonths[_currentMonth.month - 1];
    final year = _currentMonth.year;

    // Build days grid
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final startWeekday = firstDayOfMonth.weekday; // 1=Monday, 7=Sunday

    // Offset for first day (Monday=0)
    int offset = startWeekday - 1;

    List<Widget> dayWidgets = [];
    // Empty cells for offset
    for (int i = 0; i < offset; i++) {
      dayWidgets.add(Container());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final hasEvent = _hasEvent(date);
      final isToday = _isToday(date);

      dayWidgets.add(
        GestureDetector(
          onTap: () => widget.onDayTap(date),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? widget.todayColor.withValues(alpha: 0.15)
                  : (hasEvent ? widget.accent.withValues(alpha: 0.10) : null),
              border: isToday
                  ? Border.all(color: widget.todayColor, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                    color: isToday ? widget.todayColor : widget.textColor,
                    fontSize: 14,
                    fontWeight: isToday || hasEvent
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (hasEvent)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        children: [
          // Header with month/year and arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: widget.textColor,
                ),
                onPressed: _prevMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '$monthName $year',
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: widget.textColor,
                ),
                onPressed: _nextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday headers
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1.2,
            children: widget.isArabic
                ? ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
                    .map(
                      (e) => Center(
                        child: Text(
                          e,
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList()
                : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (e) => Center(
                        child: Text(
                          e,
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 4),
          // Days grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1.2,
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  static const _englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets (all themed to match ClientDashboard)
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
  Widget build(BuildContext context) {
    return Padding(
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
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color accent, border, surface, text;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.accent,
    required this.border,
    required this.surface,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled ? accent : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: filled ? accent : border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.black : text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, labelAr, labelEn;
  final Color accent, dim;
  final bool isArabic;

  const _Stat({
    required this.value,
    required this.labelAr,
    required this.labelEn,
    required this.accent,
    required this.dim,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isArabic ? labelAr : labelEn,
            style: TextStyle(color: dim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color);
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OfferType extends StatelessWidget {
  final IconData icon;
  final String labelAr, labelEn;
  final Color accent, surface, border, text, dim;
  final bool isArabic;

  const _OfferType({
    required this.icon,
    required this.labelAr,
    required this.labelEn,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.dim,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 6),
            Text(
              isArabic ? labelAr : labelEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String nameAr, nameEn;
  final String imageUrl;
  final double price;
  final bool isArabic, isDarkMode;
  final Color accent, surface, border, text, dim;

  const _ProductCard({
    required this.nameAr,
    required this.nameEn,
    required this.imageUrl,
    required this.price,
    required this.isArabic,
    required this.isDarkMode,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: imageUrl.isEmpty
                  ? _ProductImageFallback(accent: accent)
                  : Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: accent.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          _ProductImageFallback(accent: accent),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? nameAr : nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${price.toStringAsFixed(0)} JOD',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  final Color accent;
  const _ProductImageFallback({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: accent.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 36,
        color: accent.withValues(alpha: 0.6),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String titleAr, titleEn;
  final DateTime date;
  final String locationAr, locationEn;
  final bool isArabic;
  final Color accent, surface, border, text, dim;
  final VoidCallback onTap;

  const _EventTile({
    required this.titleAr,
    required this.titleEn,
    required this.date,
    required this.locationAr,
    required this.locationEn,
    required this.isArabic,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? titleAr : titleEn,
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: dim),
                      const SizedBox(width: 4),
                      Text(
                        "${date.day}/${date.month}/${date.year}",
                        style: TextStyle(color: dim, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined, size: 12, color: dim),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? locationAr : locationEn,
                        style: TextStyle(color: dim, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isArabic ? 'تسجيل' : 'RSVP',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String nameAr, nameEn, commentAr, commentEn;
  final int rating;
  final bool isArabic;
  final Color accent, surface, border, text, dim;

  const _ReviewCard({
    required this.nameAr,
    required this.nameEn,
    required this.commentAr,
    required this.commentEn,
    required this.rating,
    required this.isArabic,
    required this.accent,
    required this.surface,
    required this.border,
    required this.text,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(
                  (isArabic ? nameAr : nameEn)[0],
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? nameAr : nameEn,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: i < rating
                        ? const Color(0xFFF7B500)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? commentAr : commentEn,
            style: TextStyle(color: dim, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
