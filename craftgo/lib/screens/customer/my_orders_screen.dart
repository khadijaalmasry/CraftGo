// lib/screens/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/api_service.dart';
import '../../app_state.dart';
import '../custom_order/custom_order_provider.dart';
import '../hire_order/hire_order_provider.dart';
import '../custom_order/custom_order_request.dart';

import 'order_detail_screen.dart';
import 'review_submission_screen.dart';
import 'cart_screen.dart';
import 'product_offers_screen.dart';
import '../../services/delivery_service.dart';

class MyOrdersScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const MyOrdersScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _autoRefreshTimer;
  bool _isFetching = false;

  List<dynamic> _cartItems = [];
  List<dynamic> _standardOrders = [];
  List<dynamic> _productOffers = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Persisted review state per ready-made order.
  final Map<String, int> _reviewRatings = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchData();
      }
    });

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchData(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _fetchData(silent: true);
    }
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final customerId = _userId;
      if (customerId.isNotEmpty && mounted) {
        await Future.wait([
          context.read<CustomOrderProvider>().loadForCustomer(customerId),
          context.read<HireOrderProvider>().loadForCustomer(customerId),
        ]);
      }

      final ordersRes = await ApiService.get('/orders/customer');
      if (ordersRes.statusCode == 200) {
        final body = jsonDecode(ordersRes.body);
        List<dynamic> rawOrders;
        if (body is Map && body['orders'] != null) {
          rawOrders = List<dynamic>.from(body['orders']);
        } else if (body is List) {
          rawOrders = body;
        } else {
          rawOrders = [];
        }
        _standardOrders = rawOrders.map((o) {
          final m = Map<String, dynamic>.from(o as Map);
          final firstItem = (m['items'] as List?)?.isNotEmpty == true
              ? Map<String, dynamic>.from((m['items'] as List).first as Map)
              : <String, dynamic>{};
          m['nameAr'] = firstItem['productName'] ?? m['nameAr'] ?? '—';
          m['nameEn'] = firstItem['productName'] ?? m['nameEn'] ?? '—';
          m['price'] = m['totalAmount'] ?? firstItem['unitPrice'] ?? 0;
          m['artisan'] = firstItem['craftsmanName'] ?? m['artisan'] ?? '';
          m['imageUrl'] = firstItem['imageUrl'] ?? '';
          m['quantity'] = firstItem['quantity'] ?? 1;

          final createdAt = m['createdAt'];
          if (createdAt != null) {
            final parsedDate = DateTime.tryParse(createdAt.toString());
            if (parsedDate != null) {
              final localDate = parsedDate.toLocal();
              m['date'] =
                  '${localDate.day}/${localDate.month}/${localDate.year}';
            }
          }
          return m;
        }).toList();

        await _loadReviewStates();
      } else {
        setState(() => _hasError = true);
      }

      final offersRes = await ApiService.get('/product-offers/customer');
      if (offersRes.statusCode == 200) {
        final offersBody = jsonDecode(offersRes.body);
        final List<dynamic> rawOffers =
            offersBody is Map && offersBody['offers'] is List
                ? List<dynamic>.from(offersBody['offers'])
                : offersBody is List
                    ? List<dynamic>.from(offersBody)
                    : <dynamic>[];
        _productOffers = rawOffers.map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          final product = m['product'] is Map
              ? Map<String, dynamic>.from(m['product'] as Map)
              : <String, dynamic>{};
          final craftsman = m['craftsman'] is Map
              ? Map<String, dynamic>.from(m['craftsman'] as Map)
              : <String, dynamic>{};
          m['_kind'] = 'product_offer';
          m['nameAr'] = product['titleAr'] ??
              product['titleEn'] ??
              product['title'] ??
              '—';
          m['nameEn'] = product['titleEn'] ??
              product['titleAr'] ??
              product['title'] ??
              '—';
          m['artisan'] = craftsman['name'] ?? '';
          m['imageUrl'] = product['imageUrl'] ?? '';
          m['quantity'] = m['quantity'] ?? 1;
          m['price'] = m['counterUnitPrice'] ??
              m['acceptedUnitPrice'] ??
              m['offeredUnitPrice'] ??
              m['originalUnitPrice'] ??
              0;
          return m;
        }).toList();
      } else {
        debugPrint(
            'Could not load product offers: ${offersRes.statusCode} ${offersRes.body}');
      }

      final interactionsRes = await ApiService.get('/interactions');
      if (interactionsRes.statusCode == 200) {
        final data = jsonDecode(interactionsRes.body);
        final interactions = data is List
            ? data
            : (data['interactions'] ?? data['data'] ?? []) as List;
        _cartItems = interactions
            .where((i) => i['type'] == 'cart' || i['interactionType'] == 'cart')
            .toList();
      } else {
        setState(() => _hasError = true);
      }
    } catch (e) {
      debugPrint('Error fetching orders/cart: $e');
      setState(() => _hasError = true);
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() {
          if (!silent) _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReviewStates() async {
    _reviewRatings.clear();

    final Set<String> completedOrderIds = {};

    for (final rawOrder in _standardOrders) {
      if (rawOrder is! Map) continue;
      final status = rawOrder['status']?.toString() ?? '';
      if (status == 'completed' || status == 'delivered') {
        final orderId = rawOrder['id']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          completedOrderIds.add(orderId);
        }
      }
    }

    if (mounted) {
      final customProvider = context.read<CustomOrderProvider>();
      final customRequests = customProvider.requestsForCustomer(_userId);
      for (final request in customRequests) {
        if (request.status == 'completed') {
          final orderId = request.id.toString();
          if (orderId.isNotEmpty) {
            completedOrderIds.add(orderId);
          }
        }
      }
    }

    if (mounted) {
      final hireProvider = context.read<HireOrderProvider>();
      final hireRequests = hireProvider.requestsForCustomer(_userId);
      for (final request in hireRequests) {
        if (request.status == 'completed') {
          final orderId = request.id.toString();
          if (orderId.isNotEmpty) {
            completedOrderIds.add(orderId);
          }
        }
      }
    }

    debugPrint(
      'Loading review states for completed orders: $completedOrderIds',
    );

    for (final orderId in completedOrderIds) {
      try {
        final response = await ApiService.get('/reviews/order/$orderId');
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body is Map && body['reviewed'] == true) {
            final review = body['review'];
            int? rating;
            if (review is Map) {
              final rawRating = review['rating'];
              if (rawRating is int) {
                rating = rawRating;
              } else if (rawRating is num) {
                rating = rawRating.toInt();
              } else {
                rating = int.tryParse(rawRating?.toString() ?? '');
              }
            }
            if (rating != null) {
              _reviewRatings[orderId] = rating;
            }
          } else {
            _reviewRatings.remove(orderId);
          }
        }
      } catch (e) {
        debugPrint('Could not load review state for order $orderId: $e');
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _removeCartItem(String id) async {
    try {
      await ApiService.delete('/interactions/$id');
    } catch (_) {}
    setState(() {
      _cartItems.removeWhere((item) => (item['id']?.toString() == id));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  String get _userId => context.read<AppState>().userId ?? '';

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _openReviewScreen(dynamic order) async {
    late final Map<String, dynamic> reviewOrder;

    if (order is CustomOrderRequest) {
      reviewOrder = {
        'id': order.id,
        'customOrderRequestId': order.id,
        'nameAr': order.templateTitleAr,
        'nameEn': order.templateTitleEn,
        'artisan': order.artisanName,
        'type': 'custom',
      };
    } else if (order is HireRequest) {
      reviewOrder = {
        'id': order.id,
        'hireRequestId': order.id,
        'nameAr': order.jobDescription,
        'nameEn': order.jobDescription,
        'artisan': order.artisanName,
        'type': 'hire',
      };
    } else if (order is Map) {
      reviewOrder = Map<String, dynamic>.from(order);
      reviewOrder['nameAr'] ??= reviewOrder['productName'] ?? 'خدمة';
      reviewOrder['nameEn'] ??= reviewOrder['productName'] ?? 'Service';
      reviewOrder['artisan'] ??= reviewOrder['craftsmanName'] ?? '';
      reviewOrder['type'] ??= 'ready_made';
      if (reviewOrder['type'] == 'custom' && reviewOrder['customOrderRequestId'] == null) {
        reviewOrder['customOrderRequestId'] = reviewOrder['id'];
      }
      if (reviewOrder['type'] == 'hire' && reviewOrder['hireRequestId'] == null) {
        reviewOrder['hireRequestId'] = reviewOrder['id'];
      }
    } else {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewSubmissionScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          order: reviewOrder,
        ),
      ),
    );

    if (!mounted) return;
    await _loadReviewStates();
  }

  Future<void> _showRatingDialog(dynamic order) async {
    int selectedRating = 5;
    final commentController = TextEditingController();
    bool submitting = false;

    final String orderId;
    final String artisanName;

    if (order is CustomOrderRequest) {
      orderId = order.id.toString();
      artisanName = order.artisanName;
    } else if (order is HireRequest) {
      orderId = order.id.toString();
      artisanName = order.artisanName;
    } else {
      orderId = order['id']?.toString() ?? '';
      artisanName = order['artisan']?.toString() ?? '';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                t('قيّم الحرفي', 'Rate Artisan'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(
                        'كيف كانت تجربتك مع $artisanName؟',
                        'How was your experience with $artisanName?',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton(
                          onPressed: submitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = starValue;
                                  });
                                },
                          icon: Icon(
                            starValue <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: accent,
                            size: 34,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      enabled: !submitting,
                      maxLines: 4,
                      style: GoogleFonts.cairo(color: text),
                      decoration: InputDecoration(
                        hintText: t(
                          'اكتب تعليقًا اختياريًا...',
                          'Add an optional comment...',
                        ),
                        hintStyle: GoogleFonts.cairo(color: dim),
                        filled: true,
                        fillColor: widget.isDarkMode
                            ? const Color(0xFF0D1420)
                            : const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    t('إلغاء', 'Cancel'),
                    style: GoogleFonts.cairo(color: dim),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);

                          try {
                            final response = await ApiService.post(
                              '/reviews',
                              body: {
                                'orderId': orderId,
                                'rating': selectedRating,
                                'commentAr': widget.isArabic
                                    ? commentController.text
                                    : '',
                                'commentEn': widget.isArabic
                                    ? ''
                                    : commentController.text,
                              },
                            );

                            dynamic responseBody = <String, dynamic>{};
                            if (response.body.isNotEmpty) {
                              try {
                                responseBody = jsonDecode(response.body);
                              } catch (_) {}
                            }

                            if (response.statusCode == 200 ||
                                response.statusCode == 201) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              if (!mounted) return;

                              final submittedOrderId = orderId;

                              if (submittedOrderId.isNotEmpty) {
                                setState(() {
                                  _reviewRatings[submittedOrderId] =
                                      selectedRating;
                                });
                              }

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    t(
                                      'تم إرسال تقييمك بنجاح ⭐',
                                      'Your review was submitted successfully ⭐',
                                    ),
                                  ),
                                ),
                              );

                              await _fetchData();
                            } else if (response.statusCode == 409) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t(
                                      'لقد قيّمت هذا الطلب مسبقًا.',
                                      'You already rated this order.',
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              final errorMessage = responseBody is Map
                                  ? (responseBody['error'] ??
                                          responseBody['message'] ??
                                          'Failed to submit review')
                                      .toString()
                                  : 'Failed to submit review';
                              throw Exception(errorMessage);
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() => submitting = false);

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text(
                                  t(
                                    'تعذر إرسال التقييم. حاول مرة أخرى.',
                                    'Could not submit the review. Please try again.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.star_rounded),
                  label: Text(
                    submitting
                        ? t('جارٍ الإرسال...', 'Submitting...')
                        : t('إرسال التقييم', 'Submit Review'),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customProv = context.watch<CustomOrderProvider>();
    final hireProv = context.watch<HireOrderProvider>();

    final customRequests = customProv.requestsForCustomer(_userId);
    final hireRequests = hireProv.requestsForCustomer(_userId);

    final pendingArtisan = [
      ...customRequests.where((r) => r.status == 'pending_artisan'),
      ...hireRequests.where((r) => r.status == 'pending_artisan'),
      ..._standardOrders.where((r) {
        final st = (r['status'] ?? '').toString();
        return st == 'pending' || st == 'pending_artisan';
      }),
    ];

    final pendingCustomer = [
      ...customRequests.where((r) => r.status == 'pending_customer'),
      ...hireRequests.where((r) => r.status == 'pending_customer'),
      ..._standardOrders.where((r) {
        final st = (r['status'] ?? '').toString();
        return st == 'pending_customer' || st == 'ready' || st == 'waiting_delivery';
      }),
      ..._productOffers.where((r) => r['status'] == 'countered'),
    ];

    final inProgress = [
      ...customRequests.where((r) => r.status == 'in_progress'),
      ...hireRequests
          .where((r) => r.status == 'accepted' || r.status == 'in_progress'),
      ..._standardOrders.where(
          (r) => r['status'] == 'accepted' || r['status'] == 'in_progress'),
    ];

    final completed = [
      ...customRequests.where((r) => r.status == 'completed'),
      ...hireRequests.where((r) => r.status == 'completed'),
      ..._standardOrders.where(
          (r) => r['status'] == 'completed' || r['status'] == 'delivered'),
    ];

    final cartItems = _cartItems;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          t('طلباتي', 'My Orders'),
          style: GoogleFonts.arefRuqaa(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t('عروض أسعار المنتجات', 'Product price offers'),
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductOffersScreen(
                  isArabic: widget.isArabic,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            ).then((_) => _fetchData()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: dim,
          isScrollable: true,
          labelStyle:
              GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: t('السلة', 'Cart')),
            Tab(
                text: t('قيد الرد (${pendingArtisan.length})',
                    'Pending (${pendingArtisan.length})')),
            Tab(
                text: t('بانتظارك (${pendingCustomer.length})',
                    'Awaiting (${pendingCustomer.length})')),
            Tab(
                text: t('قيد التنفيذ (${inProgress.length})',
                    'In Progress (${inProgress.length})')),
            Tab(
                text: t('مكتملة (${completed.length})',
                    'Done (${completed.length})')),
          ],
        ),
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Colors.redAccent.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text(t('حدث خطأ', 'Something went wrong'),
                      style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(backgroundColor: accent),
                    child: Text(t('إعادة المحاولة', 'Retry'),
                        style: GoogleFonts.cairo(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildCartTab(cartItems),
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildRequestList(
                        pendingArtisan,
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                        type: 'pending_artisan',
                        emptyTitle: t('لا توجد طلبات في انتظار رد الحرفي',
                            'No orders awaiting artisan response'),
                        emptySub: t('ستظهر هنا الطلبات التي أرسلتها للحرفي',
                            'Orders you sent to artisans will appear here'),
                      ),
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildRequestList(
                        pendingCustomer,
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                        type: 'pending_customer',
                        emptyTitle: t('لا توجد طلبات بانتظار ردك',
                            'No orders awaiting your response'),
                        emptySub: t('الحرفي رد على طلبك، يرجى مراجعته',
                            'Artisan responded, please review it'),
                      ),
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildRequestList(
                        inProgress,
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                        type: 'in_progress',
                        emptyTitle: t('لا توجد طلبات قيد التنفيذ',
                            'No orders in progress'),
                        emptySub: t('الطلبات المقبولة تظهر هنا',
                            'Accepted orders appear here'),
                      ),
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _buildRequestList(
                        completed,
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                        type: 'completed',
                        emptyTitle:
                            t('لا توجد طلبات مكتملة', 'No completed orders'),
                        emptySub: t('الطلبات المنتهية تظهر هنا',
                            'Completed orders appear here'),
                      ),
              ],
            ),
    );
  }

  Widget _buildCartTab(List<dynamic> cartItems) {
    if (cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 64, color: dim.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(t('سلة التسوق فارغة', 'Your cart is empty'),
                style: TextStyle(color: dim, fontSize: 16)),
          ],
        ),
      );
    }

    double total = cartItems.fold(0, (sum, item) {
      final p = item['Product'] ?? item;
      return sum + ((p['price'] as num?)?.toDouble() ?? 0.0);
    });

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cartItems.length,
            itemBuilder: (_, index) {
              final item = cartItems[index];
              final interactionId = item['id']?.toString() ?? '';
              final p = item['Product'] ?? item;
              final nameAr = p['titleAr'] ?? p['nameAr'] ?? p['title'] ?? '—';
              final nameEn = p['titleEn'] ?? p['nameEn'] ?? nameAr;
              final price = (p['price'] as num?)?.toDouble() ?? 0.0;
              final artisan = p['Craftsman']?['name'] ?? p['artisan'] ?? '';
              final imageUrl = p['imageUrl'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF1C2431)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          widget.isDarkMode ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        image: imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: imageUrl == null
                          ? Icon(Icons.inventory_2_outlined,
                              size: 30, color: accent)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isArabic ? nameAr : nameEn,
                            style: TextStyle(
                                color: text, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(artisan,
                              style: TextStyle(color: dim, fontSize: 12)),
                          Text(
                            '${price.toStringAsFixed(2)} JOD',
                            style: TextStyle(
                                color: accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: Colors.redAccent),
                          onPressed: () => _removeCartItem(interactionId),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
            border: Border(
                top: BorderSide(
                    color:
                        widget.isDarkMode ? Colors.white12 : Colors.black12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('المجموع', 'Total'),
                      style: TextStyle(color: dim, fontSize: 12)),
                  Text('${total.toStringAsFixed(2)} JOD',
                      style: TextStyle(
                          color: text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        isArabic: widget.isArabic,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      t('إتمام الشراء', 'Checkout'),
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestList(
    List<dynamic> items, {
    required bool isArabic,
    required bool isDarkMode,
    required String type,
    required String emptyTitle,
    required String emptySub,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getIconForType(type),
                size: 64, color: dim.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: TextStyle(
                    color: text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(emptySub, style: TextStyle(color: dim, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool canRate;
        final String orderId;

        if (item is CustomOrderRequest) {
          canRate = type == 'completed' && item.status == 'completed';
          orderId = item.id.toString();
        } else if (item is HireRequest) {
          canRate = type == 'completed' && item.status == 'completed';
          orderId = item.id.toString();
        } else if (item is Map) {
          canRate = type == 'completed' &&
              (item['status'] == 'completed' || item['status'] == 'delivered');
          orderId = item['id']?.toString() ?? '';
        } else {
          canRate = false;
          orderId = '';
        }

        final existingRating =
            orderId.isNotEmpty ? _reviewRatings[orderId] : null;
        // Show confirm button whenever a delivery order is active (waiting_delivery) or ready
        final deliveryOrderData = item is Map
            ? (item['deliveryOrder'] ?? item['DeliveryOrder'] ?? item['delivery'])
            : null;
        final hasActiveDelivery = deliveryOrderData != null &&
            !['completed', 'delivered', 'cancelled'].contains(
                deliveryOrderData['status']?.toString());
        final canConfirmDelivery = item is Map &&
            (['ready', 'waiting_delivery', 'accepted'].contains(item['status']) ||
                hasActiveDelivery);

        final stRaw = item is CustomOrderRequest
            ? item.status
            : (item is HireRequest
                ? item.status
                : item['status']?.toString() ?? '');
        final bool isCancelled = stRaw == 'cancelled' || stRaw == 'rejected';

        return _RequestCard(
          item: item,
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          type: type,
          onTap: () {
            _navigateToDetail(context, item);
          },
          onDelete: isCancelled
              ? () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor:
                          isDarkMode ? const Color(0xFF1C2431) : Colors.white,
                      title: Text(t('حذف الطلب', 'Delete Order'),
                          style: TextStyle(color: text)),
                      content: Text(
                          t('هل أنت تأكد من حذف هذا الطلب الملغي؟',
                              'Delete this cancelled order?'),
                          style: TextStyle(color: dim)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(t('إلغاء', 'Cancel'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t('حذف', 'Delete'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  try {
                    if (item is CustomOrderRequest) {
                      await ApiService.delete(
                          '/custom-orders/requests/${item.id}');
                    } else if (item is Map) {
                      await ApiService.delete('/orders/${item['id']}');
                    }
                    await _fetchData();
                  } catch (e) {
                    debugPrint('Delete error: $e');
                  }
                }
              : null,
          onRate: canRate && existingRating == null
              ? () => _openReviewScreen(item)
              : null,
          reviewRating: existingRating,
          onConfirmDelivery: canConfirmDelivery
              ? () async {
                  // Use delivery order ID if available, else product order ID
                  final deliveryData = item is Map
                      ? (item['deliveryOrder'] ?? item['DeliveryOrder'] ?? item['delivery'])
                      : null;
                  final confirmId = deliveryData?['id']?.toString() ?? orderId;
                  final ok = await ApiService.post(
                    '/delivery/orders/$confirmId/confirm-by-customer',
                    body: {},
                  );
                  if (!mounted) return;
                  if (ok.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(t(
                        'تم تأكيد الاستلام وتحرير المبلغ من الضمان',
                        'Delivery confirmed and escrow released!',
                      )),
                    ));
                    await _fetchData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text(t(
                          'تعذر تأكيد الاستلام', 'Could not confirm delivery')),
                    ));
                  }
                }
              : null,
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'pending_artisan':
        return Icons.hourglass_empty;
      case 'pending_customer':
        return Icons.hourglass_top;
      case 'in_progress':
        return Icons.build_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.receipt_long;
    }
  }

  void _navigateToDetail(BuildContext context, dynamic item) {
    if (item is Map && item['_kind'] == 'product_offer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductOffersScreen(
            isArabic: widget.isArabic,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      ).then((_) => _fetchData());
      return;
    }

    Map<String, dynamic> orderMap;

    if (item is CustomOrderRequest) {
      orderMap = {
        'id': item.id,
        'customOrderRequestId': item.id,
        'nameAr': item.templateTitleAr,
        'nameEn': item.templateTitleEn,
        'artisan': item.artisanName,
        'customerName': item.customerName,
        'status': item.status,
        'date': _formatDate(item.createdAt),
        'price': item.artisanResponse?.total ?? 0,
        'type': 'custom',
        'filledFields': item.filledFields,
        'artisanResponse': item.artisanResponse,
      };
    } else if (item is HireRequest) {
      orderMap = {
        'id': item.id,
        'hireRequestId': item.id,
        'nameAr': item.jobDescription,
        'nameEn': item.jobDescription,
        'jobDescription': item.jobDescription,
        'artisan': item.artisanName,
        'artisanId': item.artisanId,
        'customerName': item.customerName,
        'status': item.status,
        'date': _formatDate(item.createdAt),
        'createdAt': item.createdAt,
        'price': item.artisanResponse?.totalPrice ?? 0,
        'type': 'hire',
        'location': item.location,
        'startDate': item.startDate,
        'endDate': item.endDate,
        'dailyHours': item.dailyHours,
        'materials':
            item.materials.map((material) => material.toJson()).toList(),
        'toolsRequired': item.toolsRequired,
        'schedule': item.artisanResponse?.schedule
                .map((day) => day.toJson())
                .toList() ??
            <Map<String, dynamic>>[],
        'artisanResponse': item.artisanResponse == null
            ? null
            : {
                'dailyRate': item.artisanResponse!.dailyRate,
                'materialCost': item.artisanResponse!.materialCost,
                'schedule': item.artisanResponse!.schedule
                    .map((day) => day.toJson())
                    .toList(),
                'totalPrice': item.artisanResponse!.totalPrice,
                'notesAr': item.artisanResponse!.notesAr,
                'notesEn': item.artisanResponse!.notesEn,
              },
      };
    } else {
      orderMap = Map<String, dynamic>.from(item as Map);
      final firstItem = (orderMap['items'] as List?)?.isNotEmpty == true
          ? (orderMap['items'] as List).first as Map<String, dynamic>
          : <String, dynamic>{};

      orderMap['nameAr'] = firstItem['productName'] ?? '—';
      orderMap['nameEn'] = firstItem['productName'] ?? '—';
      orderMap['price'] = (orderMap['totalAmount'] as num?)?.toDouble() ?? 0.0;
      orderMap['artisan'] = firstItem['craftsmanName'] ?? '';
      orderMap['type'] = 'ready_made';
      orderMap['orderId'] = orderMap['id']; // explicitly set for disputes
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          order: orderMap,
        ),
      ),
    );
  }
}
//   void _navigateToDetail(BuildContext context, dynamic item) {
//     if (item is Map && item['_kind'] == 'product_offer') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ProductOffersScreen(
//             isArabic: widget.isArabic,
//             isDarkMode: widget.isDarkMode,
//           ),
//         ),
//       ).then((_) => _fetchData());
//       return;
//     }

//     Map<String, dynamic> orderMap;

//     if (item is CustomOrderRequest) {
//       orderMap = {
//         'id': item.id,
//         'nameAr': item.templateTitleAr,
//         'nameEn': item.templateTitleEn,
//         'artisan': item.artisanName,
//         'customerName': item.customerName,
//         'status': item.status,
//         'date': _formatDate(item.createdAt),
//         'price': item.artisanResponse?.total ?? 0,
//         'type': 'custom',
//         'filledFields': item.filledFields,
//         'artisanResponse': item.artisanResponse,
//       };
//     } else if (item is HireRequest) {
//       orderMap = {
//         'id': item.id,
//         'nameAr': item.jobDescription,
//         'nameEn': item.jobDescription,
//         'jobDescription': item.jobDescription,
//         'artisan': item.artisanName,
//         'artisanId': item.artisanId,
//         'customerName': item.customerName,
//         'status': item.status,
//         'date': _formatDate(item.createdAt),
//         'createdAt': item.createdAt,
//         'price': item.artisanResponse?.totalPrice ?? 0,
//         'type': 'hire',
//         'location': item.location,
//         'startDate': item.startDate,
//         'endDate': item.endDate,
//         'dailyHours': item.dailyHours,
//         'materials':
//             item.materials.map((material) => material.toJson()).toList(),
//         'toolsRequired': item.toolsRequired,
//         'schedule': item.artisanResponse?.schedule
//                 .map((day) => day.toJson())
//                 .toList() ??
//             <Map<String, dynamic>>[],
//         'artisanResponse': item.artisanResponse == null
//             ? null
//             : {
//                 'dailyRate': item.artisanResponse!.dailyRate,
//                 'materialCost': item.artisanResponse!.materialCost,
//                 'schedule': item.artisanResponse!.schedule
//                     .map((day) => day.toJson())
//                     .toList(),
//                 'totalPrice': item.artisanResponse!.totalPrice,
//                 'notesAr': item.artisanResponse!.notesAr,
//                 'notesEn': item.artisanResponse!.notesEn,
//               },
//       };
//     } else {
//       orderMap = Map<String, dynamic>.from(item as Map);
//       final firstItem = (orderMap['items'] as List?)?.isNotEmpty == true
//           ? (orderMap['items'] as List).first as Map<String, dynamic>
//           : <String, dynamic>{};

//       orderMap['nameAr'] = firstItem['productName'] ?? '—';
//       orderMap['nameEn'] = firstItem['productName'] ?? '—';
//       orderMap['price'] = (orderMap['totalAmount'] as num?)?.toDouble() ?? 0.0;
//       orderMap['artisan'] = firstItem['craftsmanName'] ?? '';
//       orderMap['type'] = 'ready_made';
//     }

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => OrderDetailScreen(
//           isArabic: widget.isArabic,
//           isDarkMode: widget.isDarkMode,
//           order: orderMap,
//         ),
//       ),
//     );
//   }
// }

// ── Request Card Widget ─────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final dynamic item;
  final bool isArabic;
  final bool isDarkMode;
  final String type;
  final VoidCallback onTap;
  final VoidCallback? onRate;
  final int? reviewRating;
  final VoidCallback? onConfirmDelivery;
  final VoidCallback? onDelete;

  const _RequestCard({
    required this.item,
    required this.isArabic,
    required this.isDarkMode,
    required this.type,
    required this.onTap,
    this.onRate,
    this.reviewRating,
    this.onConfirmDelivery,
    this.onDelete,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String get _title {
    if (item is CustomOrderRequest) {
      final tAr = item.templateTitleAr;
      final tEn = item.templateTitleEn;
      if (tAr.isNotEmpty || tEn.isNotEmpty) {
        return isArabic ? tAr : tEn;
      }
      final shortId = item.id.length >= 8 ? item.id.substring(0, 8).toUpperCase() : item.id;
      return isArabic ? 'طلب مخصص #$shortId' : 'Custom Order #$shortId';
    } else if (item is HireRequest) {
      return isArabic ? item.jobDescription : item.jobDescription;
    } else {
      final name = isArabic
          ? (item['nameAr'] ?? item['productName'] ?? '')
          : (item['nameEn'] ?? item['productName'] ?? '');
      if (name != null && name.toString().isNotEmpty && name.toString() != '—') {
        return name.toString();
      }
      final idStr = item['id']?.toString() ?? '';
      if (idStr.length >= 8) {
        final shortId = idStr.substring(0, 8).toUpperCase();
        return isArabic ? 'طلب #$shortId' : 'Order #$shortId';
      }
      return name.toString();
    }
  }

  String? get _deliveryPin {
    if (item is CustomOrderRequest) {
      final req = item as CustomOrderRequest;
      return req.deliveryPin ?? req.deliveryOrder?['deliveryPin']?.toString();
    } else if (item is HireRequest) {
      return null;
    } else if (item is Map) {
      final pin = item['deliveryPin'] ??
          item['deliveryOrder']?['deliveryPin'] ??
          item['DeliveryOrder']?['deliveryPin'] ??
          item['delivery']?['deliveryPin'];
      return pin?.toString();
    }
    return null;
  }

  String? get _deliveryOrderId {
    if (item is CustomOrderRequest) {
      final req = item as CustomOrderRequest;
      return req.deliveryOrder?['id']?.toString() ?? req.deliveryOrder?['deliveryOrderId']?.toString();
    } else if (item is HireRequest) {
      return null;
    } else if (item is Map) {
      return item['deliveryOrderId']?.toString() ??
          item['deliveryOrder']?['id']?.toString() ??
          item['DeliveryOrder']?['id']?.toString() ??
          item['delivery']?['id']?.toString();
    }
    return null;
  }

  String get _artisanName {
    if (item is CustomOrderRequest) return item.artisanName;
    if (item is HireRequest) return item.artisanName;
    return item['artisan'] ?? '';
  }

  double get _price {
    if (item is CustomOrderRequest) return item.artisanResponse?.total ?? 0;
    if (item is HireRequest) return item.artisanResponse?.totalPrice ?? 0;
    return (item['price'] as num?)?.toDouble() ?? 0;
  }

  String get _status {
    final status = item is CustomOrderRequest
        ? item.status
        : (item is HireRequest ? item.status : item['status'] ?? '');
    final map = {
      'pending': t('قيد الانتظار', 'Pending'),
      'pending_artisan': t('في انتظار الرد', 'Awaiting Response'),
      'pending_customer': t('بانتظار موافقتك', 'Awaiting Your Approval'),
      'countered': t('عرض مضاد', 'Counter Offer'),
      'accepted': t('مقبول', 'Accepted'),
      'in_progress': t('قيد التنفيذ', 'In Progress'),
      'completed': t('مكتمل', 'Completed'),
      'rejected': t('مرفوض', 'Rejected'),
      'cancelled': t('ملغي', 'Cancelled'),
    };
    return map[status] ?? status;
  }

  Color get _statusColor {
    final status = item is CustomOrderRequest
        ? item.status
        : (item is HireRequest ? item.status : item['status'] ?? '');
    final map = {
      'pending': Colors.orange,
      'pending_artisan': Colors.orange,
      'pending_customer': Colors.blue,
      'countered': Colors.blue,
      'accepted': Colors.teal,
      'in_progress': const Color(0xFFD4A017),
      'completed': Colors.green,
      'rejected': Colors.red,
      'cancelled': Colors.grey,
    };
    return map[status] ?? Colors.orange;
  }

  String get _typeLabel {
    if (item is CustomOrderRequest) return t('طلب مخصص', 'Custom Order');
    if (item is HireRequest) return t('عمل في الموقع', 'On-Site Work');
    if (item is Map && item['_kind'] == 'product_offer') {
      return t('مفاصلة سعر', 'Price Negotiation');
    }
    return t('منتج جاهز', 'Ready-Made');
  }

  Color get _typeColor {
    if (item is CustomOrderRequest) return Colors.purple;
    if (item is HireRequest) return Colors.teal;
    if (item is Map && item['_kind'] == 'product_offer') return Colors.blue;
    return const Color(0xFFD4A017);
  }

  String get _imageUrl {
    if (item is CustomOrderRequest) return '';
    if (item is HireRequest) return '';
    return (item['imageUrl'] as String?) ?? item['Product']?['imageUrl'] ?? '';
  }

  String get _date {
    if (item is CustomOrderRequest)
      return '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';
    if (item is HireRequest)
      return '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';
    if (item['createdAt'] != null) {
      final date = DateTime.tryParse(item['createdAt'].toString());
      if (date != null) return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }

  String get _quantity {
    if (item is CustomOrderRequest) return '';
    if (item is HireRequest) return '';
    final qty = item['quantity'] ?? 1;
    return isArabic ? 'الكمية: $qty' : 'Qty: $qty';
  }

  String get _statusRaw {
    if (item is CustomOrderRequest) return item.status;
    if (item is HireRequest) return item.status;
    if (item is Map) return item['status']?.toString() ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _typeLabel,
                    style: TextStyle(
                        color: _typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _status,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if ((_statusRaw == 'cancelled' || _statusRaw == 'rejected') &&
                    onDelete != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageUrl.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 12, left: 12),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(_imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Icon(Icons.broken_image, color: dim)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isArabic ? 'بواسطة $_artisanName' : 'By $_artisanName',
                        style: TextStyle(color: dim, fontSize: 13),
                      ),
                      if (_quantity.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_quantity,
                            style: TextStyle(color: dim, fontSize: 12)),
                      ],
                      if (_date.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_date, style: TextStyle(color: dim, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_price.toStringAsFixed(2)} JOD',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          t('عرض التفاصيل', 'View Details'),
                          style: TextStyle(color: dim, fontSize: 12),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: dim),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_deliveryPin != null && _deliveryPin!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pin_outlined, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('رمز تسليم الشحنة للمندوب:', 'Delivery PIN for Driver:'),
                            style: TextStyle(color: dim, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _deliveryPin!,
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: t('أعطِ هذا الرمز للمندوب عند استلام شحنتك', 'Share this PIN with driver upon delivery'),
                      child: Icon(Icons.info_outline, color: dim, size: 18),
                    ),
                  ],
                ),
              ),
            ],
            if (_deliveryOrderId != null &&
                _deliveryOrderId!.isNotEmpty &&
                (_statusRaw == 'completed' ||
                    _statusRaw == 'delivered' ||
                    _statusRaw == 'waiting_delivery')) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => DeliveryService.showDeliveryReviewModal(
                        context,
                        _deliveryOrderId!,
                        isArabic,
                        role: 'customer',
                      ),
                      icon: const Icon(Icons.star_outline_rounded,
                          color: Color(0xFFD4A017), size: 16),
                      label: Text(
                        t('تقييم التوصيل', 'Rate Delivery'),
                        style: const TextStyle(
                            color: Color(0xFFD4A017),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD4A017)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => DeliveryService.showReportDriverModal(
                      context,
                      _deliveryOrderId!,
                      isArabic,
                      role: 'customer',
                    ),
                    icon: const Icon(Icons.report_problem_outlined,
                        color: Colors.redAccent, size: 16),
                    label: Text(
                      t('بلاغ', 'Report'),
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
            if (reviewRating != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.green,
                      size: 19,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t(
                        'تم التقييم ${reviewRating!}/5',
                        'Rated ${reviewRating!}/5',
                      ),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (onConfirmDelivery != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConfirmDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    t('تأكيد استلام المنتج', 'Confirm Product Delivery'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else if (onRate != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 19),
                  label: Text(
                    t('قيّم الحرفي', 'Rate Artisan'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// // lib/screens/my_orders_screen.dart
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';
// import 'dart:async';
// import '../../services/api_service.dart';
// import '../../app_state.dart';
// import '../custom_order/custom_order_provider.dart';
// import '../hire_order/hire_order_provider.dart';
// import '../custom_order/custom_order_request.dart';

// import 'order_detail_screen.dart';
// import 'review_submission_screen.dart';
// import 'cart_screen.dart';
// import 'product_offers_screen.dart';

// class MyOrdersScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;

//   const MyOrdersScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//   });

//   @override
//   State<MyOrdersScreen> createState() => _MyOrdersScreenState();
// }

// class _MyOrdersScreenState extends State<MyOrdersScreen>
//     with SingleTickerProviderStateMixin, WidgetsBindingObserver {
//   late TabController _tabController;
//   Timer? _autoRefreshTimer;
//   bool _isFetching = false;

//   List<dynamic> _cartItems = [];
//   List<dynamic> _standardOrders = [];
//   List<dynamic> _productOffers = [];
//   bool _isLoading = true;
//   bool _hasError = false;

//   // Persisted review state per ready-made order.
//   final Map<String, int> _reviewRatings = {};

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _tabController = TabController(length: 5, vsync: this);

//     // Wait until Provider/AppState are available, then load everything from backend.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         _fetchData();
//       }
//     });

//     // Stripe Checkout opens outside the Flutter app. Keep this screen synced
//     // so a paid order appears automatically without Ctrl+R.
//     _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
//       if (mounted) _fetchData(silent: true);
//     });
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed && mounted) {
//       _fetchData(silent: true);
//     }
//   }

//   Future<void> _fetchData({bool silent = false}) async {
//     if (_isFetching) return;
//     _isFetching = true;

//     if (!silent && mounted) {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//       });
//     }
//     try {
//       // IMPORTANT: Custom orders are stored in CustomOrderProvider, not in
//       // /orders/customer. Reload them from the backend so an artisan bid
//       // (pending_customer) appears immediately in the Awaiting tab.
//       final customerId = _userId;
//       if (customerId.isNotEmpty && mounted) {
//         await Future.wait([
//           context.read<CustomOrderProvider>().loadForCustomer(customerId),
//           context.read<HireOrderProvider>().loadForCustomer(customerId),
//         ]);
//       }

//       final ordersRes = await ApiService.get('/orders/customer');
//       if (ordersRes.statusCode == 200) {
//         final body = jsonDecode(ordersRes.body);
//         // New API returns { success: true, orders: [...] }
//         List<dynamic> rawOrders;
//         if (body is Map && body['orders'] != null) {
//           rawOrders = List<dynamic>.from(body['orders']);
//         } else if (body is List) {
//           rawOrders = body;
//         } else {
//           rawOrders = [];
//         }
//         // Normalize each order so _RequestCard can read nameAr/nameEn/price/artisan/imageUrl
//         _standardOrders = rawOrders.map((o) {
//           final m = Map<String, dynamic>.from(o as Map);
//           final firstItem = (m['items'] as List?)?.isNotEmpty == true
//               ? Map<String, dynamic>.from((m['items'] as List).first as Map)
//               : <String, dynamic>{};
//           m['nameAr'] = firstItem['productName'] ?? m['nameAr'] ?? '—';
//           m['nameEn'] = firstItem['productName'] ?? m['nameEn'] ?? '—';
//           m['price'] = m['totalAmount'] ?? firstItem['unitPrice'] ?? 0;
//           m['artisan'] = firstItem['craftsmanName'] ?? m['artisan'] ?? '';
//           m['imageUrl'] = firstItem['imageUrl'] ?? '';
//           m['quantity'] = firstItem['quantity'] ?? 1;

//           // Keep createdAt as received from the API, but also prepare a safe
//           // display date for OrderDetailScreen.
//           final createdAt = m['createdAt'];
//           if (createdAt != null) {
//             final parsedDate = DateTime.tryParse(createdAt.toString());
//             if (parsedDate != null) {
//               final localDate = parsedDate.toLocal();
//               m['date'] =
//                   '${localDate.day}/${localDate.month}/${localDate.year}';
//             }
//           }

//           return m;
//         }).toList();

//         await _loadReviewStates();
//       } else {
//         setState(() => _hasError = true);
//       }

//       // Load product price-negotiation offers for the current customer.
//       // A craftsman's counter-offer has status == 'countered' and must appear
//       // in the Awaiting tab so the customer can review it.
//       final offersRes = await ApiService.get('/product-offers/customer');
//       if (offersRes.statusCode == 200) {
//         final offersBody = jsonDecode(offersRes.body);
//         final List<dynamic> rawOffers =
//             offersBody is Map && offersBody['offers'] is List
//                 ? List<dynamic>.from(offersBody['offers'])
//                 : offersBody is List
//                     ? List<dynamic>.from(offersBody)
//                     : <dynamic>[];

//         _productOffers = rawOffers.map((raw) {
//           final m = Map<String, dynamic>.from(raw as Map);
//           final product = m['product'] is Map
//               ? Map<String, dynamic>.from(m['product'] as Map)
//               : <String, dynamic>{};
//           final craftsman = m['craftsman'] is Map
//               ? Map<String, dynamic>.from(m['craftsman'] as Map)
//               : <String, dynamic>{};

//           m['_kind'] = 'product_offer';
//           m['nameAr'] = product['titleAr'] ??
//               product['titleEn'] ??
//               product['title'] ??
//               '—';
//           m['nameEn'] = product['titleEn'] ??
//               product['titleAr'] ??
//               product['title'] ??
//               '—';
//           m['artisan'] = craftsman['name'] ?? '';
//           m['imageUrl'] = product['imageUrl'] ?? '';
//           m['quantity'] = m['quantity'] ?? 1;

//           // For a countered offer, show the artisan's latest counter price.
//           // Otherwise keep the customer's offered/list price as a fallback.
//           m['price'] = m['counterUnitPrice'] ??
//               m['acceptedUnitPrice'] ??
//               m['offeredUnitPrice'] ??
//               m['originalUnitPrice'] ??
//               0;

//           return m;
//         }).toList();
//       } else {
//         debugPrint(
//             'Could not load product offers: ${offersRes.statusCode} ${offersRes.body}');
//       }

//       final interactionsRes = await ApiService.get('/interactions');
//       if (interactionsRes.statusCode == 200) {
//         final data = jsonDecode(interactionsRes.body);
//         final interactions = data is List
//             ? data
//             : (data['interactions'] ?? data['data'] ?? []) as List;
//         _cartItems = interactions
//             .where((i) => i['type'] == 'cart' || i['interactionType'] == 'cart')
//             .toList();
//       } else {
//         setState(() => _hasError = true);
//       }
//     } catch (e) {
//       debugPrint('Error fetching orders/cart: $e');
//       setState(() => _hasError = true);
//     } finally {
//       _isFetching = false;
//       if (mounted) {
//         setState(() {
//           if (!silent) _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _loadReviewStates() async {
//     // Reload persisted review state for all completed order types.
//     _reviewRatings.clear();

//     final Set<String> completedOrderIds = {};

//     // 1) Ready-Made completed orders
//     for (final rawOrder in _standardOrders) {
//       if (rawOrder is! Map) continue;

//       final status = rawOrder['status']?.toString() ?? '';

//       if (status == 'completed' || status == 'delivered') {
//         final orderId = rawOrder['id']?.toString() ?? '';

//         if (orderId.isNotEmpty) {
//           completedOrderIds.add(orderId);
//         }
//       }
//     }

//     // 2) Custom completed orders
//     if (mounted) {
//       final customProvider = context.read<CustomOrderProvider>();
//       final customRequests = customProvider.requestsForCustomer(_userId);

//       for (final request in customRequests) {
//         if (request.status == 'completed') {
//           final orderId = request.id.toString();

//           if (orderId.isNotEmpty) {
//             completedOrderIds.add(orderId);
//           }
//         }
//       }
//     }

//     // 3) Hire / On-Site completed orders
//     if (mounted) {
//       final hireProvider = context.read<HireOrderProvider>();
//       final hireRequests = hireProvider.requestsForCustomer(_userId);

//       for (final request in hireRequests) {
//         if (request.status == 'completed') {
//           final orderId = request.id.toString();

//           if (orderId.isNotEmpty) {
//             completedOrderIds.add(orderId);
//           }
//         }
//       }
//     }

//     debugPrint(
//       'Loading review states for completed orders: $completedOrderIds',
//     );

//     // 4) Ask backend whether each completed order was reviewed.
//     for (final orderId in completedOrderIds) {
//       try {
//         final response = await ApiService.get('/reviews/order/$orderId');

//         debugPrint(
//           'Review check for $orderId -> '
//           '${response.statusCode}: ${response.body}',
//         );

//         if (response.statusCode == 200) {
//           final body = jsonDecode(response.body);

//           if (body is Map && body['reviewed'] == true) {
//             final review = body['review'];

//             int? rating;

//             if (review is Map) {
//               final rawRating = review['rating'];

//               if (rawRating is int) {
//                 rating = rawRating;
//               } else if (rawRating is num) {
//                 rating = rawRating.toInt();
//               } else {
//                 rating = int.tryParse(rawRating?.toString() ?? '');
//               }
//             }

//             if (rating != null) {
//               _reviewRatings[orderId] = rating;

//               debugPrint(
//                 'Loaded existing rating for $orderId: $rating',
//               );
//             }
//           } else {
//             _reviewRatings.remove(orderId);
//           }
//         }
//       } catch (e) {
//         debugPrint(
//           'Could not load review state for order $orderId: $e',
//         );
//       }
//     }

//     if (mounted) {
//       setState(() {});
//     }
//   }

//   void _removeCartItem(String id) async {
//     try {
//       await ApiService.delete('/interactions/$id');
//     } catch (_) {}
//     setState(() {
//       _cartItems.removeWhere((item) => (item['id']?.toString() == id));
//     });
//   }

//   @override
//   void dispose() {
//     _autoRefreshTimer?.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     _tabController.dispose();
//     super.dispose();
//   }

//   // Theme colors
//   Color get bg =>
//       widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

//   Color get text => widget.isDarkMode ? Colors.white : Colors.black87;

//   Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;

//   Color get accent => const Color(0xFFD4A017);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   // ── Get current user ID from AppState ──────────────────────────────────
//   String get _userId => context.read<AppState>().userId ?? '';

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year}';
//   }

//   Future<void> _openReviewScreen(dynamic order) async {
//     late final Map<String, dynamic> reviewOrder;

//     if (order is CustomOrderRequest) {
//       reviewOrder = {
//         'id': order.id,
//         'nameAr': order.templateTitleAr,
//         'nameEn': order.templateTitleEn,
//         'artisan': order.artisanName,
//         'type': 'custom',
//       };
//     } else if (order is HireRequest) {
//       reviewOrder = {
//         'id': order.id,
//         'nameAr': order.jobDescription,
//         'nameEn': order.jobDescription,
//         'artisan': order.artisanName,
//         'type': 'hire',
//       };
//     } else if (order is Map) {
//       reviewOrder = Map<String, dynamic>.from(order);
//       reviewOrder['nameAr'] ??= reviewOrder['productName'] ?? 'خدمة';
//       reviewOrder['nameEn'] ??= reviewOrder['productName'] ?? 'Service';
//       reviewOrder['artisan'] ??= reviewOrder['craftsmanName'] ?? '';
//       reviewOrder['type'] ??= 'ready_made';
//     } else {
//       return;
//     }

//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => ReviewSubmissionScreen(
//           isArabic: widget.isArabic,
//           isDarkMode: widget.isDarkMode,
//           order: reviewOrder,
//         ),
//       ),
//     );

//     if (!mounted) return;
//     await _loadReviewStates();
//   }

//   Future<void> _rateOrder(dynamic order) async {
//     String orderId = '';

//     if (order is CustomOrderRequest) {
//       orderId = order.id.toString();
//     } else if (order is HireRequest) {
//       orderId = order.id.toString();
//     } else if (order is Map) {
//       orderId = order['id']?.toString() ?? '';
//     }

//     if (orderId.isEmpty) {
//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             t(
//               'تعذر تحديد رقم الطلب',
//               'Could not identify the order',
//             ),
//           ),
//         ),
//       );

//       return;
//     }

//     try {
//       final checkRes = await ApiService.get('/reviews/order/$orderId');

//       if (checkRes.statusCode == 200) {
//         final body = jsonDecode(checkRes.body);

//         if (body is Map && body['reviewed'] == true) {
//           final existing = body['review'];

//           if (!mounted) return;

//           await showDialog<void>(
//             context: context,
//             builder: (dialogContext) {
//               final rating = existing is Map ? existing['rating'] : null;

//               return AlertDialog(
//                 backgroundColor:
//                     widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
//                 title: Text(
//                   t(
//                     'تم تقييم هذا الطلب',
//                     'Order Already Rated',
//                   ),
//                   style: GoogleFonts.cairo(
//                     color: text,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 content: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.verified_rounded,
//                       color: Colors.green,
//                       size: 44,
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       rating != null
//                           ? t(
//                               'تقييمك الحالي: $rating من 5',
//                               'Your rating: $rating out of 5',
//                             )
//                           : t(
//                               'لقد أرسلت تقييمًا لهذا الطلب مسبقًا.',
//                               'You already submitted a review for this order.',
//                             ),
//                       textAlign: TextAlign.center,
//                       style: GoogleFonts.cairo(
//                         color: text,
//                       ),
//                     ),
//                   ],
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(dialogContext),
//                     child: Text(
//                       t('حسنًا', 'OK'),
//                       style: GoogleFonts.cairo(
//                         color: accent,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           );

//           return;
//         }
//       }
//     } catch (e) {
//       debugPrint('Review check failed: $e');
//     }

//     if (!mounted) return;

//     await _showRatingDialog(order);
//   }

//   Future<void> _showRatingDialog(dynamic order) async {
//     int selectedRating = 5;
//     final commentController = TextEditingController();
//     bool submitting = false;

//     final String orderId;
//     final String artisanName;

//     if (order is CustomOrderRequest) {
//       orderId = order.id.toString();
//       artisanName = order.artisanName;
//     } else if (order is HireRequest) {
//       orderId = order.id.toString();
//       artisanName = order.artisanName;
//     } else {
//       orderId = order['id']?.toString() ?? '';
//       artisanName = order['artisan']?.toString() ?? '';
//     }

//     await showDialog<void>(
//       context: context,
//       builder: (dialogContext) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               backgroundColor:
//                   widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               title: Text(
//                 t('قيّم الحرفي', 'Rate Artisan'),
//                 textAlign: TextAlign.center,
//                 style: GoogleFonts.cairo(
//                   color: text,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       t(
//                         'كيف كانت تجربتك مع $artisanName؟',
//                         'How was your experience with $artisanName?',
//                       ),
//                       textAlign: TextAlign.center,
//                       style: GoogleFonts.cairo(
//                         color: dim,
//                         fontSize: 13,
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: List.generate(5, (index) {
//                         final starValue = index + 1;

//                         return IconButton(
//                           onPressed: submitting
//                               ? null
//                               : () {
//                                   setDialogState(() {
//                                     selectedRating = starValue;
//                                   });
//                                 },
//                           icon: Icon(
//                             starValue <= selectedRating
//                                 ? Icons.star_rounded
//                                 : Icons.star_border_rounded,
//                             color: accent,
//                             size: 34,
//                           ),
//                         );
//                       }),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: commentController,
//                       enabled: !submitting,
//                       maxLines: 4,
//                       style: GoogleFonts.cairo(color: text),
//                       decoration: InputDecoration(
//                         hintText: t(
//                           'اكتب تعليقًا اختياريًا...',
//                           'Add an optional comment...',
//                         ),
//                         hintStyle: GoogleFonts.cairo(color: dim),
//                         filled: true,
//                         fillColor: widget.isDarkMode
//                             ? const Color(0xFF0D1420)
//                             : const Color(0xFFF5F6F8),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(14),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               actionsAlignment: MainAxisAlignment.center,
//               actions: [
//                 TextButton(
//                   onPressed:
//                       submitting ? null : () => Navigator.pop(dialogContext),
//                   child: Text(
//                     t('إلغاء', 'Cancel'),
//                     style: GoogleFonts.cairo(color: dim),
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: submitting
//                       ? null
//                       : () async {
//                           setDialogState(() => submitting = true);

//                           try {
//                             final response = await ApiService.post(
//                               '/reviews',
//                               body: {
//                                 'orderId': orderId,
//                                 'rating': selectedRating,
//                                 'commentAr': widget.isArabic
//                                     ? commentController.text
//                                     : '',
//                                 'commentEn': widget.isArabic
//                                     ? ''
//                                     : commentController.text,
//                               },
//                             );

//                             dynamic responseBody = <String, dynamic>{};
//                             if (response.body.isNotEmpty) {
//                               try {
//                                 responseBody = jsonDecode(response.body);
//                               } catch (_) {}
//                             }

//                             if (response.statusCode == 200 ||
//                                 response.statusCode == 201) {
//                               if (dialogContext.mounted) {
//                                 Navigator.pop(dialogContext);
//                               }

//                               if (!mounted) return;

//                               final submittedOrderId = orderId;

//                               if (submittedOrderId.isNotEmpty) {
//                                 setState(() {
//                                   _reviewRatings[submittedOrderId] =
//                                       selectedRating;
//                                 });
//                               }

//                               ScaffoldMessenger.of(this.context).showSnackBar(
//                                 SnackBar(
//                                   backgroundColor: Colors.green,
//                                   content: Text(
//                                     t(
//                                       'تم إرسال تقييمك بنجاح ⭐',
//                                       'Your review was submitted successfully ⭐',
//                                     ),
//                                   ),
//                                 ),
//                               );

//                               await _fetchData();
//                             } else if (response.statusCode == 409) {
//                               if (dialogContext.mounted) {
//                                 Navigator.pop(dialogContext);
//                               }

//                               if (!mounted) return;
//                               ScaffoldMessenger.of(this.context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     t(
//                                       'لقد قيّمت هذا الطلب مسبقًا.',
//                                       'You already rated this order.',
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             } else {
//                               final errorMessage = responseBody is Map
//                                   ? (responseBody['error'] ??
//                                           responseBody['message'] ??
//                                           'Failed to submit review')
//                                       .toString()
//                                   : 'Failed to submit review';
//                               throw Exception(errorMessage);
//                             }
//                           } catch (e) {
//                             if (!dialogContext.mounted) return;

//                             setDialogState(() => submitting = false);

//                             ScaffoldMessenger.of(dialogContext).showSnackBar(
//                               SnackBar(
//                                 backgroundColor: Colors.redAccent,
//                                 content: Text(
//                                   t(
//                                     'تعذر إرسال التقييم. حاول مرة أخرى.',
//                                     'Could not submit the review. Please try again.',
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }
//                         },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: accent,
//                     foregroundColor: Colors.black,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   icon: submitting
//                       ? const SizedBox(
//                           width: 16,
//                           height: 16,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.black,
//                           ),
//                         )
//                       : const Icon(Icons.star_rounded),
//                   label: Text(
//                     submitting
//                         ? t('جارٍ الإرسال...', 'Submitting...')
//                         : t('إرسال التقييم', 'Submit Review'),
//                     style: GoogleFonts.cairo(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );

//     commentController.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final customProv = context.watch<CustomOrderProvider>();
//     final hireProv = context.watch<HireOrderProvider>();

//     // Customer's custom orders
//     final customRequests = customProv.requestsForCustomer(_userId);
//     final hireRequests = hireProv.requestsForCustomer(_userId);

//     // Filter by status
//     final pendingArtisan = [
//       ...customRequests.where((r) => r.status == 'pending_artisan'),
//       ...hireRequests.where((r) => r.status == 'pending_artisan'),
//       ..._standardOrders.where((r) {
//         final st = (r['status'] ?? '').toString();
//         return st == 'pending' || st == 'pending_artisan';
//       }),
//     ];

//     final pendingCustomer = [
//       ...customRequests.where((r) => r.status == 'pending_customer'),
//       ...hireRequests.where((r) => r.status == 'pending_customer'),
//       ..._standardOrders.where((r) {
//         final st = (r['status'] ?? '').toString();
//         return st == 'pending_customer' || st == 'ready';
//       }),
//       // Product negotiations answered by the artisan with a counter-offer.
//       ..._productOffers.where((r) => r['status'] == 'countered'),
//     ];

//     final inProgress = [
//       ...customRequests.where((r) => r.status == 'in_progress'),
//       ...hireRequests
//           .where((r) => r.status == 'accepted' || r.status == 'in_progress'),
//       ..._standardOrders.where(
//           (r) => r['status'] == 'accepted' || r['status'] == 'in_progress'),
//     ];

//     final completed = [
//       ...customRequests.where((r) => r.status == 'completed'),
//       ...hireRequests.where((r) => r.status == 'completed'),
//       ..._standardOrders.where(
//           (r) => r['status'] == 'completed' || r['status'] == 'delivered'),
//     ];

//     // Cart items (from API)
//     final cartItems = _cartItems;

//     return Scaffold(
//       backgroundColor: bg,
//       appBar: AppBar(
//         backgroundColor: bg,
//         elevation: 0,
//         title: Text(
//           t('طلباتي', 'My Orders'),
//           style: GoogleFonts.arefRuqaa(
//             color: text,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         actions: [
//           IconButton(
//             tooltip: t('عروض أسعار المنتجات', 'Product price offers'),
//             icon: const Icon(Icons.handshake_outlined),
//             onPressed: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => ProductOffersScreen(
//                   isArabic: widget.isArabic,
//                   isDarkMode: widget.isDarkMode,
//                 ),
//               ),
//             ).then((_) => _fetchData()),
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: accent,
//           labelColor: accent,
//           unselectedLabelColor: dim,
//           isScrollable: true,
//           labelStyle:
//               GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
//           tabs: [
//             Tab(text: t('السلة', 'Cart')),
//             Tab(
//                 text: t('قيد الرد (${pendingArtisan.length})',
//                     'Pending (${pendingArtisan.length})')),
//             Tab(
//                 text: t('بانتظارك (${pendingCustomer.length})',
//                     'Awaiting (${pendingCustomer.length})')),
//             Tab(
//                 text: t('قيد التنفيذ (${inProgress.length})',
//                     'In Progress (${inProgress.length})')),
//             Tab(
//                 text: t('مكتملة (${completed.length})',
//                     'Done (${completed.length})')),
//           ],
//         ),
//       ),
//       body: _hasError
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.error_outline,
//                       size: 64, color: Colors.redAccent.withValues(alpha: 0.7)),
//                   const SizedBox(height: 16),
//                   Text(t('حدث خطأ', 'Something went wrong'),
//                       style: GoogleFonts.cairo(
//                           color: text,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: _fetchData,
//                     style: ElevatedButton.styleFrom(backgroundColor: accent),
//                     child: Text(t('إعادة المحاولة', 'Retry'),
//                         style: GoogleFonts.cairo(
//                             color: Colors.black, fontWeight: FontWeight.bold)),
//                   ),
//                 ],
//               ),
//             )
//           : TabBarView(
//               controller: _tabController,
//               children: [
//                 _isLoading
//                     ? Center(child: CircularProgressIndicator(color: accent))
//                     : _buildCartTab(cartItems),
//                 _isLoading
//                     ? Center(child: CircularProgressIndicator(color: accent))
//                     : _buildRequestList(
//                         pendingArtisan,
//                         isArabic: widget.isArabic,
//                         isDarkMode: widget.isDarkMode,
//                         type: 'pending_artisan',
//                         emptyTitle: t('لا توجد طلبات في انتظار رد الحرفي',
//                             'No orders awaiting artisan response'),
//                         emptySub: t('ستظهر هنا الطلبات التي أرسلتها للحرفي',
//                             'Orders you sent to artisans will appear here'),
//                       ),
//                 _isLoading
//                     ? Center(child: CircularProgressIndicator(color: accent))
//                     : _buildRequestList(
//                         pendingCustomer,
//                         isArabic: widget.isArabic,
//                         isDarkMode: widget.isDarkMode,
//                         type: 'pending_customer',
//                         emptyTitle: t('لا توجد طلبات بانتظار ردك',
//                             'No orders awaiting your response'),
//                         emptySub: t('الحرفي رد على طلبك، يرجى مراجعته',
//                             'Artisan responded, please review it'),
//                       ),
//                 _isLoading
//                     ? Center(child: CircularProgressIndicator(color: accent))
//                     : _buildRequestList(
//                         inProgress,
//                         isArabic: widget.isArabic,
//                         isDarkMode: widget.isDarkMode,
//                         type: 'in_progress',
//                         emptyTitle: t('لا توجد طلبات قيد التنفيذ',
//                             'No orders in progress'),
//                         emptySub: t('الطلبات المقبولة تظهر هنا',
//                             'Accepted orders appear here'),
//                       ),
//                 _isLoading
//                     ? Center(child: CircularProgressIndicator(color: accent))
//                     : _buildRequestList(
//                         completed,
//                         isArabic: widget.isArabic,
//                         isDarkMode: widget.isDarkMode,
//                         type: 'completed',
//                         emptyTitle:
//                             t('لا توجد طلبات مكتملة', 'No completed orders'),
//                         emptySub: t('الطلبات المنتهية تظهر هنا',
//                             'Completed orders appear here'),
//                       ),
//               ],
//             ),
//     );
//   }

//   // ── Cart Tab ──────────────────────────────────────────────────────────────

//   Widget _buildCartTab(List<dynamic> cartItems) {
//     if (cartItems.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.shopping_cart_outlined,
//                 size: 64, color: dim.withValues(alpha: 0.3)),
//             const SizedBox(height: 16),
//             Text(t('سلة التسوق فارغة', 'Your cart is empty'),
//                 style: TextStyle(color: dim, fontSize: 16)),
//           ],
//         ),
//       );
//     }

//     double total = cartItems.fold(0, (sum, item) {
//       final p = item['Product'] ?? item;
//       return sum + ((p['price'] as num?)?.toDouble() ?? 0.0);
//     });

//     return Column(
//       children: [
//         Expanded(
//           child: ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: cartItems.length,
//             itemBuilder: (_, index) {
//               final item = cartItems[index];
//               final interactionId = item['id']?.toString() ?? '';
//               final p = item['Product'] ?? item;
//               final nameAr = p['titleAr'] ?? p['nameAr'] ?? p['title'] ?? '—';
//               final nameEn = p['titleEn'] ?? p['nameEn'] ?? nameAr;
//               final price = (p['price'] as num?)?.toDouble() ?? 0.0;
//               final artisan = p['Craftsman']?['name'] ?? p['artisan'] ?? '';
//               final imageUrl = p['imageUrl'] as String?;

//               return Container(
//                 margin: const EdgeInsets.only(bottom: 12),
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: widget.isDarkMode
//                       ? const Color(0xFF1C2431)
//                       : Colors.white,
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(
//                       color:
//                           widget.isDarkMode ? Colors.white12 : Colors.black12),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 60,
//                       height: 60,
//                       decoration: BoxDecoration(
//                         color: accent.withValues(alpha: 0.12),
//                         borderRadius: BorderRadius.circular(12),
//                         image: imageUrl != null
//                             ? DecorationImage(
//                                 image: NetworkImage(imageUrl),
//                                 fit: BoxFit.cover)
//                             : null,
//                       ),
//                       child: imageUrl == null
//                           ? Icon(Icons.inventory_2_outlined,
//                               size: 30, color: accent)
//                           : null,
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             widget.isArabic ? nameAr : nameEn,
//                             style: TextStyle(
//                                 color: text, fontWeight: FontWeight.w600),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           Text(artisan,
//                               style: TextStyle(color: dim, fontSize: 12)),
//                           Text(
//                             '${price.toStringAsFixed(2)} JOD',
//                             style: TextStyle(
//                                 color: accent, fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.delete_outline,
//                               size: 20, color: Colors.redAccent),
//                           onPressed: () => _removeCartItem(interactionId),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
//             border: Border(
//                 top: BorderSide(
//                     color:
//                         widget.isDarkMode ? Colors.white12 : Colors.black12)),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(t('المجموع', 'Total'),
//                       style: TextStyle(color: dim, fontSize: 12)),
//                   Text('${total.toStringAsFixed(2)} JOD',
//                       style: TextStyle(
//                           color: text,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold)),
//                 ],
//               ),
//               GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => CartScreen(
//                         isArabic: widget.isArabic,
//                         isDarkMode: widget.isDarkMode,
//                       ),
//                     ),
//                   );
//                 },
//                 child: Container(
//                   height: 48,
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                         colors: [Color(0xFFF7B500), Color(0xFFD89A00)]),
//                     borderRadius: BorderRadius.circular(24),
//                   ),
//                   child: Center(
//                     child: Text(
//                       t('إتمام الشراء', 'Checkout'),
//                       style: const TextStyle(
//                           color: Colors.black, fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // ── Unified Request List ──────────────────────────────────────────────────
//   Widget _buildRequestList(
//     List<dynamic> items, {
//     required bool isArabic,
//     required bool isDarkMode,
//     required String type,
//     required String emptyTitle,
//     required String emptySub,
//   }) {
//     if (items.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(_getIconForType(type),
//                 size: 64, color: dim.withValues(alpha: 0.3)),
//             const SizedBox(height: 16),
//             Text(emptyTitle,
//                 style: TextStyle(
//                     color: text, fontSize: 16, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Text(emptySub, style: TextStyle(color: dim, fontSize: 13)),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       physics: const BouncingScrollPhysics(),
//       itemCount: items.length,
//       itemBuilder: (context, index) {
//         final item = items[index];
//         final bool canRate;
//         final String orderId;

//         if (item is CustomOrderRequest) {
//           canRate = type == 'completed' && item.status == 'completed';
//           orderId = item.id.toString();
//         } else if (item is HireRequest) {
//           canRate = type == 'completed' && item.status == 'completed';
//           orderId = item.id.toString();
//         } else if (item is Map) {
//           canRate = type == 'completed' &&
//               (item['status'] == 'completed' || item['status'] == 'delivered');
//           orderId = item['id']?.toString() ?? '';
//         } else {
//           canRate = false;
//           orderId = '';
//         }

//         final existingRating =
//             orderId.isNotEmpty ? _reviewRatings[orderId] : null;
//         final canConfirmDelivery = item is Map && item['status'] == 'ready';

//         final String stRaw = item is CustomOrderRequest
//             ? item.status
//             : (item is HireRequest ? item.status : item['status']?.toString() ?? '');
//         final bool isCancelled = stRaw == 'cancelled' || stRaw == 'rejected';

//         return _RequestCard(
//           item: item,
//           isArabic: isArabic,
//           isDarkMode: isDarkMode,
//           type: type,
//           onTap: () {
//             // Navigate to appropriate detail screen
//             _navigateToDetail(context, item);
//           },
//           onDelete: isCancelled
//               ? () async {
//                   final confirm = await showDialog<bool>(
//                     context: context,
//                     builder: (ctx) => AlertDialog(
//                       backgroundColor: isDarkMode ? const Color(0xFF1C2431) : Colors.white,
//                       title: Text(t('حذف الطلب', 'Delete Order'), style: TextStyle(color: text)),
//                       content: Text(t('هل أنت تأكد من حذف هذا الطلب الملغي؟', 'Delete this cancelled order?'), style: TextStyle(color: dim)),
//                       actions: [
//                         TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('إلغاء', 'Cancel'))),
//                         ElevatedButton(
//                           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                           onPressed: () => Navigator.pop(ctx, true),
//                           child: Text(t('حذف', 'Delete'), style: const TextStyle(color: Colors.white)),
//                         ),
//                       ],
//                     ),
//                   );
//                   if (confirm != true || !mounted) return;
//                   try {
//                     if (item is CustomOrderRequest) {
//                       await ApiService.delete('/custom-orders/requests/${item.id}');
//                     } else if (item is Map) {
//                       await ApiService.delete('/orders/${item['id']}');
//                     }
//                     await _fetchData();
//                   } catch (e) {
//                     debugPrint('Delete error: $e');
//                   }
//                 }
//               : null,
//           onRate: canRate && existingRating == null
//               ? () => _openReviewScreen(item)
//               : null,
//           reviewRating: existingRating,
//           onConfirmDelivery: canConfirmDelivery
//               ? () async {
//                   final ok = await ApiService.patch(
//                     '/orders/$orderId/status',
//                     body: {'status': 'completed'},
//                   );
//                   if (!mounted) return;
//                   if (ok.statusCode == 200) {
//                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                       backgroundColor: Colors.green,
//                       content: Text(t(
//                         'تم تأكيد الاستلام وتحرير المبلغ من الضمان',
//                         'Delivery confirmed and Escrow released',
//                       )),
//                     ));
//                     await _fetchData();
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                       backgroundColor: Colors.redAccent,
//                       content: Text(t(
//                           'تعذر تأكيد الاستلام', 'Could not confirm delivery')),
//                     ));
//                   }
//                 }
//               : null,
//         );
//       },
//     );
//   }

//   IconData _getIconForType(String type) {
//     switch (type) {
//       case 'pending_artisan':
//         return Icons.hourglass_empty;
//       case 'pending_customer':
//         return Icons.hourglass_top;
//       case 'in_progress':
//         return Icons.build_outlined;
//       case 'completed':
//         return Icons.check_circle_outline;
//       default:
//         return Icons.receipt_long;
//     }
//   }

//   void _navigateToDetail(BuildContext context, dynamic item) {
//     // Product price-negotiation cards are managed by ProductOffersScreen,
//     // where the customer can accept/reject the artisan counter-offer.
//     if (item is Map && item['_kind'] == 'product_offer') {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ProductOffersScreen(
//             isArabic: widget.isArabic,
//             isDarkMode: widget.isDarkMode,
//           ),
//         ),
//       ).then((_) => _fetchData());
//       return;
//     }

//     // Convert to a map for the OrderDetailScreen
//     Map<String, dynamic> orderMap;

//     if (item is CustomOrderRequest) {
//       orderMap = {
//         'id': item.id,
//         'nameAr': item.templateTitleAr,
//         'nameEn': item.templateTitleEn,
//         'artisan': item.artisanName,
//         'customerName': item.customerName,
//         'status': item.status,
//         'date': _formatDate(item.createdAt),
//         'price': item.artisanResponse?.total ?? 0,
//         'type': 'custom',
//         'filledFields': item.filledFields,
//         'artisanResponse': item.artisanResponse,
//       };
//     } else if (item is HireRequest) {
//       orderMap = {
//         'id': item.id,
//         'nameAr': item.jobDescription,
//         'nameEn': item.jobDescription,
//         'jobDescription': item.jobDescription,
//         'artisan': item.artisanName,
//         'artisanId': item.artisanId,
//         'customerName': item.customerName,
//         'status': item.status,
//         'date': _formatDate(item.createdAt),
//         'createdAt': item.createdAt,
//         'price': item.artisanResponse?.totalPrice ?? 0,
//         'type': 'hire',
//         'location': item.location,
//         'startDate': item.startDate,
//         'endDate': item.endDate,
//         'dailyHours': item.dailyHours,
//         'materials':
//             item.materials.map((material) => material.toJson()).toList(),
//         'toolsRequired': item.toolsRequired,
//         'schedule': item.artisanResponse?.schedule
//                 .map((day) => day.toJson())
//                 .toList() ??
//             <Map<String, dynamic>>[],
//         'artisanResponse': item.artisanResponse == null
//             ? null
//             : {
//                 'dailyRate': item.artisanResponse!.dailyRate,
//                 'materialCost': item.artisanResponse!.materialCost,
//                 'schedule': item.artisanResponse!.schedule
//                     .map((day) => day.toJson())
//                     .toList(),
//                 'totalPrice': item.artisanResponse!.totalPrice,
//                 'notesAr': item.artisanResponse!.notesAr,
//                 'notesEn': item.artisanResponse!.notesEn,
//               },
//       };
//     } else {
//       orderMap = Map<String, dynamic>.from(item as Map);
//       // New API shape: { id, status, totalAmount, items: [{productName, imageUrl, craftsmanName, quantity, unitPrice}] }
//       final firstItem = (orderMap['items'] as List?)?.isNotEmpty == true
//           ? (orderMap['items'] as List).first as Map<String, dynamic>
//           : <String, dynamic>{};

//       orderMap['nameAr'] = firstItem['productName'] ?? '—';
//       orderMap['nameEn'] = firstItem['productName'] ?? '—';
//       orderMap['price'] = (orderMap['totalAmount'] as num?)?.toDouble() ?? 0.0;
//       orderMap['artisan'] = firstItem['craftsmanName'] ?? '';
//       orderMap['type'] = 'ready_made';
//     }

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => OrderDetailScreen(
//           isArabic: widget.isArabic,
//           isDarkMode: widget.isDarkMode,
//           order: orderMap,
//         ),
//       ),
//     );
//   }
// }

// // ── Request Card Widget ─────────────────────────────────────────────────────
// class _RequestCard extends StatelessWidget {
//   final dynamic item;
//   final bool isArabic;
//   final bool isDarkMode;
//   final String type;
//   final VoidCallback onTap;
//   final VoidCallback? onRate;
//   final int? reviewRating;
//   final VoidCallback? onConfirmDelivery;
//   final VoidCallback? onDelete;

//   const _RequestCard({
//     required this.item,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.type,
//     required this.onTap,
//     this.onRate,
//     this.reviewRating,
//     this.onConfirmDelivery,
//     this.onDelete,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;

//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get surf => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get border => isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get accent => const Color(0xFFD4A017);

//   String get _title {
//     if (item is CustomOrderRequest) {
//       return isArabic ? item.templateTitleAr : item.templateTitleEn;
//     } else if (item is HireRequest) {
//       return isArabic ? item.jobDescription : item.jobDescription;
//     } else {
//       // Support both old shape (nameAr/nameEn) and new normalized shape
//       final name = isArabic
//           ? (item['nameAr'] ?? item['productName'] ?? '—')
//           : (item['nameEn'] ?? item['productName'] ?? '—');
//       return name.toString();
//     }
//   }

//   String get _artisanName {
//     if (item is CustomOrderRequest) return item.artisanName;
//     if (item is HireRequest) return item.artisanName;
//     return item['artisan'] ?? '';
//   }

//   double get _price {
//     if (item is CustomOrderRequest) return item.artisanResponse?.total ?? 0;
//     if (item is HireRequest) return item.artisanResponse?.totalPrice ?? 0;
//     return (item['price'] as num?)?.toDouble() ?? 0;
//   }

//   String get _status {
//     final status = item is CustomOrderRequest
//         ? item.status
//         : (item is HireRequest ? item.status : item['status'] ?? '');
//     final map = {
//       'pending': t('قيد الانتظار', 'Pending'),
//       'pending_artisan': t('في انتظار الرد', 'Awaiting Response'),
//       'pending_customer': t('بانتظار موافقتك', 'Awaiting Your Approval'),
//       'countered': t('عرض مضاد', 'Counter Offer'),
//       'accepted': t('مقبول', 'Accepted'),
//       'in_progress': t('قيد التنفيذ', 'In Progress'),
//       'completed': t('مكتمل', 'Completed'),
//       'rejected': t('مرفوض', 'Rejected'),
//       'cancelled': t('ملغي', 'Cancelled'),
//     };
//     return map[status] ?? status;
//   }

//   Color get _statusColor {
//     final status = item is CustomOrderRequest
//         ? item.status
//         : (item is HireRequest ? item.status : item['status'] ?? '');
//     final map = {
//       'pending': Colors.orange,
//       'pending_artisan': Colors.orange,
//       'pending_customer': Colors.blue,
//       'countered': Colors.blue,
//       'accepted': Colors.teal,
//       'in_progress': const Color(0xFFD4A017),
//       'completed': Colors.green,
//       'rejected': Colors.red,
//       'cancelled': Colors.grey,
//     };
//     return map[status] ?? Colors.orange;
//   }

//   String get _typeLabel {
//     if (item is CustomOrderRequest) return t('طلب مخصص', 'Custom Order');
//     if (item is HireRequest) return t('عمل في الموقع', 'On-Site Work');
//     if (item is Map && item['_kind'] == 'product_offer') {
//       return t('مفاصلة سعر', 'Price Negotiation');
//     }
//     return t('منتج جاهز', 'Ready-Made');
//   }

//   Color get _typeColor {
//     if (item is CustomOrderRequest) return Colors.purple;
//     if (item is HireRequest) return Colors.teal;
//     if (item is Map && item['_kind'] == 'product_offer') return Colors.blue;
//     return const Color(0xFFD4A017);
//   }

//   String get _imageUrl {
//     if (item is CustomOrderRequest) return '';
//     if (item is HireRequest) return '';
//     // First check normalized imageUrl set in _fetchData, then fallback
//     return (item['imageUrl'] as String?) ?? item['Product']?['imageUrl'] ?? '';
//   }

//   String get _date {
//     if (item is CustomOrderRequest)
//       return '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';
//     if (item is HireRequest)
//       return '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';
//     if (item['createdAt'] != null) {
//       final date = DateTime.tryParse(item['createdAt'].toString());
//       if (date != null) return '${date.day}/${date.month}/${date.year}';
//     }
//     return '';
//   }

//   String get _quantity {
//     if (item is CustomOrderRequest) return '';
//     if (item is HireRequest) return '';
//     final qty = item['quantity'] ?? 1;
//     return isArabic ? 'الكمية: $qty' : 'Qty: $qty';
//   String get _statusRaw {
//     if (item is CustomOrderRequest) return item.status;
//     if (item is HireRequest) return item.status;
//     if (item is Map) return item['status']?.toString() ?? '';
//     return '';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       behavior: HitTestBehavior.opaque,
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 14),
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: surf,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(color: border),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.04),
//                 blurRadius: 10,
//                 offset: const Offset(0, 4))
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header: Type badge + Status + Delete button if cancelled
//             Row(
//               children: [
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: _typeColor.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     _typeLabel,
//                     style: TextStyle(
//                         color: _typeColor,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 const Spacer(),
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: _statusColor.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     _status,
//                     style: TextStyle(
//                         color: _statusColor,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 if ((_statusRaw == 'cancelled' || _statusRaw == 'rejected') && onDelete != null) ...[
//                   const SizedBox(width: 4),
//                   IconButton(
//                     constraints: const BoxConstraints(),
//                     padding: const EdgeInsets.all(4),
//                     icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
//                     onPressed: onDelete,
//                   ),
//                 ],
//               ],
//             ),
//             const SizedBox(height: 12),
//             // Title and Content
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (_imageUrl.isNotEmpty)
//                   Container(
//                     margin: const EdgeInsets.only(right: 12, left: 12),
//                     width: 60,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     clipBehavior: Clip.hardEdge,
//                     child: Image.network(_imageUrl,
//                         fit: BoxFit.cover,
//                         errorBuilder: (c, e, s) =>
//                             Icon(Icons.broken_image, color: dim)),
//                   ),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         _title,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                             color: text,
//                             fontSize: 15,
//                             fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(height: 6),
//                       // Artisan name
//                       Text(
//                         isArabic ? 'بواسطة $_artisanName' : 'By $_artisanName',
//                         style: TextStyle(color: dim, fontSize: 13),
//                       ),
//                       if (_quantity.isNotEmpty) ...[
//                         const SizedBox(height: 4),
//                         Text(_quantity,
//                             style: TextStyle(color: dim, fontSize: 12)),
//                       ],
//                       if (_date.isNotEmpty) ...[
//                         const SizedBox(height: 4),
//                         Text(_date, style: TextStyle(color: dim, fontSize: 12)),
//                       ],
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             // Price + view details
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '${_price.toStringAsFixed(2)} JOD',
//                   style: TextStyle(
//                       color: accent, fontWeight: FontWeight.bold, fontSize: 15),
//                 ),
//                 InkWell(
//                   onTap: onTap,
//                   borderRadius: BorderRadius.circular(10),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 6,
//                       vertical: 8,
//                     ),
//                     child: Row(
//                       children: [
//                         Text(
//                           t('عرض التفاصيل', 'View Details'),
//                           style: TextStyle(color: dim, fontSize: 12),
//                         ),
//                         Icon(Icons.arrow_forward_ios, size: 14, color: dim),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             if (reviewRating != null) ...[
//               const SizedBox(height: 12),
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(vertical: 11),
//                 decoration: BoxDecoration(
//                   color: Colors.green.withValues(alpha: 0.10),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                     color: Colors.green.withValues(alpha: 0.55),
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(
//                       Icons.star_rounded,
//                       color: Colors.green,
//                       size: 19,
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       t(
//                         'تم التقييم ${reviewRating!}/5',
//                         'Rated ${reviewRating!}/5',
//                       ),
//                       style: const TextStyle(
//                         color: Colors.green,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ] else if (onConfirmDelivery != null) ...[
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: onConfirmDelivery,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: accent,
//                     foregroundColor: Colors.black,
//                   ),
//                   icon: const Icon(Icons.inventory_2_outlined),
//                   label: Text(
//                     t('تأكيد استلام المنتج', 'Confirm Product Delivery'),
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ] else if (onRate != null) ...[
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: OutlinedButton.icon(
//                   onPressed: onRate,
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: accent,
//                     side: BorderSide(color: accent.withValues(alpha: 0.7)),
//                     padding: const EdgeInsets.symmetric(vertical: 11),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   icon: const Icon(Icons.star_rounded, size: 19),
//                   label: Text(
//                     t('قيّم الحرفي', 'Rate Artisan'),
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
