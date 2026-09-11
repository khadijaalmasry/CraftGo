import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/products_service.dart';
import '../../services/api_service.dart';
import '../custom_order/custom_order_provider.dart';
import '../custom_order/custom_order_request.dart';
import '../hire_order/hire_order_provider.dart';
import 'artisan_response_screen.dart';
import 'craftsman_review_customer_screen.dart';
import '../delivery/create_delivery_screen.dart';
import '../../services/delivery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CraftsmanOrdersScreen — إدارة الطلبات الواردة للحرفي[cite: 34]
//
// Tabs:
//   1. واردة (Incoming) — طلبات جديدة تحتاج رد[cite: 34]
//   2. مفاوضة (Negotiating) — رد الحرفي قيد انتظار موافقة الزبون[cite: 34]
//   3. قيد التنفيذ (In Progress) — طلبات معتمدة قيد العمل[cite: 34]
//   4. مكتملة (Completed) — طلبات منتهية[cite: 34]
//   5. جاهزة (Ready) — طلبات المنتجات الجاهزة[cite: 34]
// ─────────────────────────────────────────────────────────────────────────────

class CraftsmanOrdersScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String artisanId; // The logged-in artisan's ID[cite: 34]

  const CraftsmanOrdersScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.artisanId,
  });

  @override
  State<CraftsmanOrdersScreen> createState() => _CraftsmanOrdersScreenState();
}

class _CraftsmanOrdersScreenState extends State<CraftsmanOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Product orders from backend
  List<Map<String, dynamic>> _productOrders = [];
  List<Map<String, dynamic>> _artisanDeliveries = [];
  bool _loadingOrders = true;
  List<Map<String, dynamic>> _productOffers = [];

  final Map<String, int> _customerReviewRatings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllOrders();
  }

  // ── Colors ──────────────────────────────────────────────────────────────────
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent =>
      widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get gold => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  String localizeNumber(String value) {
    if (!widget.isArabic) return value;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      value = value.replaceAll(en[i], ar[i]);
    }
    return value;
  }

  Future<void> _loadAllOrders() async {
    await Future.wait([
      _loadProductOffers(),
      _loadProductOrders(),
      _loadArtisanDeliveries(),
    ]);
  }

  Future<void> _loadArtisanDeliveries() async {
    final deliveries = await ProductsService.getArtisanDeliveries(widget.artisanId);
    if (mounted) {
      setState(() {
        _artisanDeliveries = deliveries
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
      });
    }
  }

  Future<void> _loadProductOffers() async {
    final offers = await ProductsService.getMyArtisanOffers();
    if (mounted) {
      setState(() => _productOffers =
          offers.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    }
  }

  Future<void> _loadProductOrders() async {
    setState(() => _loadingOrders = true);
    final orders = await ProductsService.getCraftsmanOrders(widget.artisanId);
    if (mounted) {
      setState(() {
        _productOrders =
            orders.map((o) => Map<String, dynamic>.from(o)).toList();
        _loadingOrders = false;
      });
      await _loadCustomerReviewStates();
    }
  }

  Future<void> _loadCustomerReviewStates() async {
    final completedIds = _productOrders
        .where((o) {
          final status = (o['status'] ?? '').toString();
          return status == 'completed' || status == 'delivered';
        })
        .map((o) => o['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    for (final orderId in completedIds) {
      try {
        final response =
            await ApiService.get('/reviews/customer/order/$orderId');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final body = jsonDecode(response.body);
          if (body is Map && body['reviewed'] == true) {
            final review = body['review'];
            final rawRating = review is Map ? review['rating'] : null;
            final rating = rawRating is num
                ? rawRating.toInt()
                : int.tryParse(rawRating?.toString() ?? '');

            if (rating != null) {
              _customerReviewRatings[orderId] = rating;
            }
          } else {
            _customerReviewRatings.remove(orderId);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateProductOrderStatus(String orderId, String status) async {
    final ok = await ProductsService.updateOrderStatus(orderId, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? t('✅ تم تحديث حالة الطلب', '✅ Order status updated')
            : t('❌ فشل التحديث', '❌ Update failed')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _loadAllOrders();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Status Helpers ──────────────────────────────────────────────────────────
  String statusText(String status) {
    final map = {
      'pending_artisan': t('في انتظار ردك', 'Awaiting Your Response'),
      'pending_customer': t('في انتظار الزبون', 'Awaiting Customer'),
      'pending': t('قيد الانتظار', 'Pending'),
      'accepted': t('مقبول', 'Accepted'),
      'in_progress': t('قيد التنفيذ', 'In Progress'),
      'completed': t('مكتمل', 'Completed'),
      'rejected': t('مرفوض', 'Rejected'),
      'cancelled': t('ملغي', 'Cancelled'),
    };
    return map[status] ?? status;
  }

  Color statusColor(String status) {
    final map = {
      'pending_artisan': Colors.orange,
      'pending_customer': Colors.blue,
      'pending': Colors.orange,
      'accepted': Colors.blue,
      'in_progress': gold,
      'completed': Colors.green,
      'rejected': Colors.red,
      'cancelled': Colors.grey,
    };
    return map[status] ?? Colors.grey;
  }

  // ── Filtered Lists ──────────────────────────────────────────────────────────
  List<CustomOrderRequest> _incomingRequests(CustomOrderProvider prov) {
    return prov
        .requestsForArtisan(widget.artisanId)
        .where((r) => r.status == 'pending_artisan')
        .toList();
  }

  List<CustomOrderRequest> _negotiatingRequests(CustomOrderProvider prov) {
    return prov
        .requestsForArtisan(widget.artisanId)
        .where((r) => r.status == 'pending_customer')
        .toList();
  }

  List<CustomOrderRequest> _inProgressRequests(CustomOrderProvider prov) {
    return prov
        .requestsForArtisan(widget.artisanId)
        .where((r) => r.status == 'in_progress')
        .toList();
  }

  List<CustomOrderRequest> _completedRequests(CustomOrderProvider prov) {
    return prov
        .requestsForArtisan(widget.artisanId)
        .where((r) =>
            r.status == 'completed' ||
            r.status == 'rejected' ||
            r.status == 'cancelled')
        .toList();
  }

  List<Map<String, dynamic>> get _incomingProductOrders =>
      _productOrders.where((o) {
        final status = (o['status'] ?? 'pending').toString();
        return status == 'pending' || status == 'pending_artisan';
      }).toList();

  List<Map<String, dynamic>> get _readyProductOrders =>
      _productOrders.where((o) {
        final status = (o['status'] ?? '').toString();
        return status == 'ready' ||
            status == 'waiting_delivery' ||
            status == 'delivering';
      }).toList();

  List<Map<String, dynamic>> get _inProgressProductOrders =>
      _productOrders.where((o) {
        final status = (o['status'] ?? '').toString();
        return status == 'accepted' || status == 'in_progress';
      }).toList();

  List<Map<String, dynamic>> get _doneProductOrders =>
      _productOrders.where((o) {
        final status = (o['status'] ?? '').toString();
        return status == 'completed' ||
            status == 'delivered' ||
            status == 'cancelled';
      }).toList();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CustomOrderProvider>();
    final hireProv = context.watch<HireOrderProvider>();
    final incoming = _incomingRequests(prov);
    final negotiating = _negotiatingRequests(prov);
    final inProgress = _inProgressRequests(prov);
    final completed = _completedRequests(prov);
    final hireInProgress = hireProv
        .requestsForArtisan(widget.artisanId)
        .where((r) => r.status == 'in_progress')
        .toList();
    final hireCompleted = hireProv
        .requestsForArtisan(widget.artisanId)
        .where((r) => r.status == 'completed')
        .toList();

    final incomingProductOrders = _incomingProductOrders;
    final readyProductOrders = _readyProductOrders;
    final inProgressProductOrders = _inProgressProductOrders;
    final doneProductOrders = _doneProductOrders;

    final incomingCount = incoming.length + incomingProductOrders.length;
    final inProgressCount = inProgress.length +
        inProgressProductOrders.length +
        hireInProgress.length;
    final doneCount =
        completed.length + doneProductOrders.length + hireCompleted.length;

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
                GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(
                  text:
                      t('واردة ($incomingCount)', 'Incoming ($incomingCount)')),
              Tab(
                  text: t('مفاوضة (${negotiating.length})',
                      'Negotiating (${negotiating.length})')),
              Tab(
                  text: t('قيد التنفيذ ($inProgressCount)',
                      'In Progress ($inProgressCount)')),
              Tab(text: t('مكتملة ($doneCount)', 'Done ($doneCount)')),
              Tab(
                text: t('جاهزة للتوصيل (${_readyProductOrders.length})',
                    'Ready for Delivery (${_readyProductOrders.length})'),
              )
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildIncomingCombinedTab(incoming, prov, incomingProductOrders),
            _buildNegotiatingTab(negotiating, prov),
            _buildInProgressCombinedTab(
              inProgress,
              prov,
              inProgressProductOrders,
              hireInProgress,
            ),
            _buildCompletedCombinedTab(
              completed,
              prov,
              doneProductOrders,
              hireCompleted,
            ),
            _buildProductOrdersTab(orders: readyProductOrders),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCombinedTab(
    List<CustomOrderRequest> requests,
    CustomOrderProvider prov,
    List<Map<String, dynamic>> productOrders,
  ) {
    if (requests.isEmpty && productOrders.isEmpty) {
      return _buildEmptyState(
        Icons.inbox_outlined,
        t('لا توجد طلبات واردة', 'No incoming requests'),
        t('ستظهر هنا الطلبات الجديدة من الزبائن',
            'New customer requests will appear here'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllOrders,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          ...requests.map(
            (request) => _IncomingRequestCard(
              request: request,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              onRespond: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtisanResponseScreen(
                      isArabic: widget.isArabic,
                      isDarkMode: widget.isDarkMode,
                      request: request,
                      artisanId: widget.artisanId,
                    ),
                  ),
                ).then((_) => _loadAllOrders());
              },
              onDecline: () => _showDeclineDialog(context, request, prov),
            ),
          ),
          ...productOrders.map((order) => _buildProductOrderCard(order)),
        ],
      ),
    );
  }

  Widget _buildInProgressCombinedTab(
    List<CustomOrderRequest> requests,
    CustomOrderProvider prov,
    List<Map<String, dynamic>> productOrders,
    List<HireRequest> hireRequests,
  ) {
    if (requests.isEmpty && productOrders.isEmpty && hireRequests.isEmpty) {
      return _buildEmptyState(
        Icons.build_outlined,
        t('لا توجد طلبات قيد التنفيذ', 'No orders in progress'),
        t('الطلبات المعتمدة تظهر هنا', 'Approved orders appear here'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllOrders,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          ...requests.map(
            (request) => _InProgressCard(
              request: request,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              onUpdateProgress: () =>
                  _showProgressUpdateDialog(context, request, prov),
              onComplete: () => _showCompleteDialog(context, request, prov),
            ),
          ),
          ...productOrders.map((order) => _buildProductOrderCard(order)),
          ...hireRequests.map(
            (request) => _HireOrderCard(
              request: request,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              completed: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCombinedTab(
    List<CustomOrderRequest> requests,
    CustomOrderProvider prov,
    List<Map<String, dynamic>> productOrders,
    List<HireRequest> hireRequests,
  ) {
    if (requests.isEmpty && productOrders.isEmpty && hireRequests.isEmpty) {
      return _buildEmptyState(
        Icons.check_circle_outline,
        t('لا توجد طلبات مكتملة', 'No completed orders'),
        t('الطلبات المنجزة تظهر هنا', 'Completed orders appear here'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllOrders,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          ...requests.map(
            (request) => _CompletedCard(
              request: request,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              onReview: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CraftsmanReviewCustomerScreen(
                      isArabic: widget.isArabic,
                      isDarkMode: widget.isDarkMode,
                      customerName: request.customerName,
                      orderId: request.id.toString(),
                    ),
                  ),
                );
              },
            ),
          ),
          ...productOrders.map((order) => _buildProductOrderCard(order)),
          ...hireRequests.map(
            (request) => _HireOrderCard(
              request: request,
              isArabic: widget.isArabic,
              isDarkMode: widget.isDarkMode,
              completed: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. NEGOTIATING TAB ──────────────────────────────────────────────────────
  Widget _buildNegotiatingTab(
      List<CustomOrderRequest> requests, CustomOrderProvider prov) {
    if (requests.isEmpty && _productOffers.isEmpty) {
      return _buildEmptyState(
        Icons.hourglass_empty,
        t('لا توجد طلبات قيد المفاوضة', 'No negotiations in progress'),
        t('الطلبات التي ردّ عليها الحرفي تظهر هنا',
            'Requests you\'ve responded to appear here'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        ..._productOffers
            .where((o) =>
                ['pending', 'countered', 'accepted'].contains(o['status']))
            .map(_buildProductOfferCard),
        ...List.generate(
            requests.length,
            (i) => _NegotiatingCard(
                  request: requests[i],
                  isArabic: widget.isArabic,
                  isDarkMode: widget.isDarkMode,
                  onViewDetails: () {
                    _showNegotiationDetails(context, requests[i]);
                  },
                  onCancel: () => _showCancelDialog(context, requests[i], prov),
                )),
      ],
    );
  }

  Widget _buildProductOfferCard(Map<String, dynamic> offer) {
    final product = Map<String, dynamic>.from(offer['product'] ?? const {});
    final customer = Map<String, dynamic>.from(offer['customer'] ?? const {});
    final status = offer['status'].toString();
    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['titleEn']?.toString() ?? 'Product offer',
              style:
                  GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
          Text(
              '${customer['name'] ?? 'Customer'} • ${offer['offeredUnitPrice']} JOD',
              style: GoogleFonts.cairo(color: gold)),
          Text(t('الحالة: $status', 'Status: $status'),
              style: GoogleFonts.cairo(color: dim, fontSize: 12)),
          if (status == 'pending')
            Row(children: [
              TextButton(
                  onPressed: () async {
                    await ProductsService.respondToOffer(offer['id'].toString(),
                        action: 'reject');
                    _loadAllOrders();
                  },
                  child: Text(t('رفض', 'Reject'))),
              const Spacer(),
              OutlinedButton(
                  onPressed: () => _counterOffer(offer),
                  child: Text(t('عرض مضاد', 'Counter'))),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: () async {
                    await ProductsService.respondToOffer(offer['id'].toString(),
                        action: 'accept');
                    _loadAllOrders();
                  },
                  child: Text(t('قبول', 'Accept'))),
            ]),
        ]),
      ),
    );
  }

  Future<void> _counterOffer(Map<String, dynamic> offer) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
        context: context,
        builder: (c) => AlertDialog(
              backgroundColor: surface,
              title: Text(t('عرض مضاد', 'Counter offer'),
                  style: TextStyle(color: text)),
              content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: text)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(t('إلغاء', 'Cancel'))),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(c, double.tryParse(controller.text)),
                    child: Text(t('إرسال', 'Send')))
              ],
            ));
    controller.dispose();
    if (value != null) {
      await ProductsService.respondToOffer(offer['id'].toString(),
          action: 'counter', counterPrice: value);
      _loadAllOrders();
    }
  }

  Widget _buildProductOrdersTab({required List<Map<String, dynamic>> orders}) {
    if (_loadingOrders) {
      return Center(child: CircularProgressIndicator(color: gold));
    }

    if (orders.isEmpty && _artisanDeliveries.isEmpty) {
      return _buildEmptyState(
        Icons.local_shipping_outlined,
        t('لا توجد طلبات توصيل جاهزة', 'No ready delivery orders'),
        t('الطلبات والشحنات الجاهزة لبدء التنفيذ ستظهر هنا',
            'Accepted orders and delivery shipments ready to process will appear here'),
      );
    }

    // Group ready orders by customer (name + phone + address)
    final Map<String, List<Map<String, dynamic>>> groupedByCustomer = {};
    for (final order in orders) {
      final key = (order['customerName']?.toString() ?? '') +
          '|' +
          (order['customerPhone']?.toString() ?? '') +
          '|' +
          (order['shippingAddress']?.toString() ?? '');
      groupedByCustomer.putIfAbsent(key, () => []).add(order);
    }

    return RefreshIndicator(
      onRefresh: _loadAllOrders,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          // Section 1: Active and Past Delivery Shipments
          if (_artisanDeliveries.isNotEmpty) ...[
            Text(
              t('شحنات التوصيل الحالية والمحدثة', 'Active & Past Deliveries'),
              style: GoogleFonts.cairo(
                  color: text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._artisanDeliveries.map((delivery) => _buildArtisanDeliveryCard(delivery)),
            const SizedBox(height: 16),
          ],

          // Section 2: Ready Product Orders (Grouped by Customer)
          if (groupedByCustomer.isNotEmpty) ...[
            Text(
              t('الطلبات الجاهزة لتأكيد التوصيل', 'Orders Ready for Delivery'),
              style: GoogleFonts.cairo(
                  color: text, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...groupedByCustomer.entries.map((entry) {
              final ordersList = entry.value;
              final firstOrder = ordersList.first;
              final custName = firstOrder['customerName'] ?? 'Customer';

              if (ordersList.length > 1) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$custName (${ordersList.length} ${t('طلبات', 'orders')})',
                              style: GoogleFonts.cairo(
                                  color: text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openGroupedDeliveryScreen(ordersList),
                            icon: const Icon(Icons.inventory_2_outlined, size: 15, color: Colors.black),
                            label: Text(
                              t('تجميع شحنة واحدة 📦', 'Group into 1 Shipment 📦'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gold,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...ordersList.map((o) => _buildProductOrderCard(o)),
                    ],
                  ),
                );
              } else {
                return _buildProductOrderCard(firstOrder);
              }
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildArtisanDeliveryCard(Map<String, dynamic> delivery) {
    final deliveryId = delivery['id']?.toString() ?? '';
    final orderCode = delivery['orderCode']?.toString() ?? '';
    final status = (delivery['status'] ?? 'available').toString();
    final driver = delivery['driver'] is Map ? Map<String, dynamic>.from(delivery['driver'] as Map) : null;
    final customer = delivery['customer'] is Map ? Map<String, dynamic>.from(delivery['customer'] as Map) : null;
    final pin = delivery['deliveryPin']?.toString() ?? '';

    Color statusColor = Colors.orange;
    String statusLabel = t('متاح للسائقين', 'Available for Drivers');
    if (status == 'active' || status == 'in_progress') {
      statusColor = Colors.blue;
      statusLabel = t('قيد التوصيل', 'Delivering');
    } else if (status == 'delivered' || status == 'completed') {
      statusColor = Colors.green;
      statusLabel = t('تم التسليم', 'Delivered');
    } else if (status == 'cancelled') {
      statusColor = Colors.grey;
      statusLabel = t('ملغي', 'Cancelled');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'cancelled' ? Colors.grey.withValues(alpha: 0.3) : border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📦 $orderCode',
                style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (customer != null || delivery['customerPhone'] != null)
            Text(
              '${t('الزبون: ', 'Customer: ')}${customer?['name'] ?? ''} (${delivery['customerPhone'] ?? customer?['phone'] ?? ''})',
              style: TextStyle(color: dim, fontSize: 12),
            ),
          Text(
            '${t('العنوان: ', 'Address: ')}${delivery['dropoffAddress'] ?? ''}',
            style: TextStyle(color: dim, fontSize: 12),
          ),
          if (driver != null) ...[
            const SizedBox(height: 4),
            Text(
              '${t('السائق: ', 'Driver: ')}${driver['name']} (${driver['phone'] ?? ''})',
              style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
          if (pin.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${t('رمز الاستلام: ', 'Delivery PIN: ')}$pin',
              style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status != 'completed' && status != 'delivered' && status != 'cancelled')
                OutlinedButton.icon(
                  onPressed: () => _confirmCancelDelivery(deliveryId),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: Text(
                    t('إلغاء التوصيل', 'Cancel Delivery'),
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              if (status == 'cancelled' || status == 'completed' || status == 'delivered')
                OutlinedButton.icon(
                  onPressed: () => _clearDeliveryHistory(deliveryId),
                  icon: Icon(Icons.delete_sweep_outlined, size: 16, color: dim),
                  label: Text(
                    t('مسح من السجل', 'Clear from History'),
                    style: TextStyle(color: dim, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelDelivery(String deliveryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('إلغاء الشحنة', 'Cancel Delivery'), style: TextStyle(color: text)),
        content: Text(
          t('هل أنت متأكد من إلغاء طلب التوصيل هذا؟', 'Are you sure you want to cancel this delivery order?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('نعم، إلغاء', 'Yes, Cancel'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await DeliveryService.cancelDeliveryOrder(deliveryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? t('تم إلغاء التوصيل', 'Delivery cancelled') : t('فشل الإلغاء', 'Failed to cancel')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _loadAllOrders();
      }
    }
  }

  Future<void> _clearDeliveryHistory(String deliveryId) async {
    final success = await DeliveryService.clearDeliveryOrder(deliveryId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? t('تم المسح من السجل', 'Cleared from history') : t('فشل المسح', 'Clear failed')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadAllOrders();
    }
  }

  Future<void> _openGroupedDeliveryScreen(List<Map<String, dynamic>> ordersList) async {
    final groupedIds = ordersList.map((o) => o['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
    final firstOrder = ordersList.first;
    final rawItems = firstOrder['items'];
    final firstItem = rawItems is List && rawItems.isNotEmpty && rawItems.first is Map
        ? Map<String, dynamic>.from(rawItems.first as Map)
        : <String, dynamic>{};
    final productId = firstItem['productId']?.toString() ?? '';
    final productName = firstItem['productName']?.toString() ?? 'Combined Shipment';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateDeliveryScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          orderId: groupedIds.isNotEmpty ? groupedIds.first : '',
          productId: productId,
          productName: productName,
          groupedOrderIds: groupedIds,
          customerName: firstOrder['customerName']?.toString() ?? '',
        ),
      ),
    );

    if (result == true) {
      _loadAllOrders();
    }
  }

  Widget _buildProductOrderCard(Map<String, dynamic> order) {
    final rawItems = order['items'];
    final firstItem =
        rawItems is List && rawItems.isNotEmpty && rawItems.first is Map
            ? Map<String, dynamic>.from(rawItems.first as Map)
            : <String, dynamic>{};

    final orderId = order['id']?.toString() ?? '';
    final status = (order['status'] ?? 'pending').toString();
    final totalPrice = order['totalAmount'] ?? firstItem['unitPrice'] ?? 0;
    final deliveryAddress = order['shippingAddress']?.toString() ?? '';
    final productName = firstItem['productName']?.toString() ?? '—';
    final productImage = firstItem['imageUrl']?.toString() ?? '';
    final customerName = order['customerName']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (productImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    productImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: gold),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: gold),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText(status),
                            style: TextStyle(
                              color: statusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t('الزبون: ', 'Customer: ')}$customerName',
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${t('العنوان: ', 'Address: ')}$deliveryAddress',
            style: TextStyle(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalPrice JOD',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: widget.isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                if (status == 'pending' || status == 'pending_artisan') ...[
                  ElevatedButton(
                    onPressed: () => _updateProductOrderStatus(
                        orderId, 'pending_customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      t('قبول (طلب الدفع)', 'Approve (Request Payment)'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _updateProductOrderStatus(orderId, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      t('رفض', 'Reject'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ] else if (status == 'pending_customer') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t('⏳ بانتظار دفع الزبون', '⏳ Awaiting Customer Payment'),
                      style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (status == 'accepted') ...[
                  ElevatedButton(
                    onPressed: () =>
                        _updateProductOrderStatus(orderId, 'in_progress'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      t('بدء التنفيذ', 'Start Work'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ] else if (status == 'completed') ...[
                  if (_customerReviewRatings[orderId] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t(
                              'تم التقييم ${_customerReviewRatings[orderId]}/5',
                              'Rated ${_customerReviewRatings[orderId]}/5',
                            ),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final rating = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CraftsmanReviewCustomerScreen(
                              isArabic: widget.isArabic,
                              isDarkMode: widget.isDarkMode,
                              customerName: customerName,
                              orderId: orderId,
                            ),
                          ),
                        );

                        if (rating != null && mounted) {
                          setState(() {
                            _customerReviewRatings[orderId] = rating;
                          });
                        }

                        await _loadAllOrders();
                      },
                      icon: Icon(Icons.star, size: 17, color: gold),
                      label: Text(
                        t('تقييم الزبون', 'Rate Customer'),
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ] else if (status == 'in_progress') ...[
                  ElevatedButton(
                    onPressed: () => _updateProductOrderStatus(orderId, 'ready'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      t('إكمال التوصيل', 'Complete'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                OutlinedButton(
                  onPressed: () => _showManageDeliveryDialog(order),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    t('إدارة التوصيل', 'Manage Delivery'),
                    style: TextStyle(
                      color: text,
                      fontSize: 12,
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

  Future<void> _showManageDeliveryDialog(Map<String, dynamic> order) async {
    final firstItem = (order['items'] is List && order['items'].isNotEmpty)
        ? Map<String, dynamic>.from(order['items'][0])
        : <String, dynamic>{};
    final productId = firstItem['productId']?.toString() ?? '';
    final orderId = order['id']?.toString() ?? '';

    // Navigate to CreateDeliveryScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateDeliveryScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          orderId: orderId,
          productId: productId,
          productName: firstItem['productName']?.toString() ?? 'Product',
        ),
      ),
    );

    if (result == true) {
      // Refresh orders after creating delivery
      _loadAllOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم إنشاء طلب التوصيل بنجاح',
              'Delivery order created successfully')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────
  void _showDeclineDialog(BuildContext context, CustomOrderRequest request,
      CustomOrderProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('رفض الطلب', 'Decline Order'),
            style: TextStyle(color: text)),
        content: Text(
          t('هل أنت متأكد من رفض هذا الطلب؟',
              'Are you sure you want to decline this order?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              prov.customerReject(request.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('تم رفض الطلب', 'Order declined')),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(t('رفض', 'Decline'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, CustomOrderRequest request,
      CustomOrderProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('إلغاء المفاوضة', 'Cancel Negotiation'),
            style: TextStyle(color: text)),
        content: Text(
          t('هل تريد إلغاء هذه المفاوضة؟',
              'Do you want to cancel this negotiation?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              prov.customerCancel(request.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(t('تم إلغاء المفاوضة', 'Negotiation cancelled')),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(t('إلغاء', 'Cancel'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNegotiationDetails(
      BuildContext context, CustomOrderRequest request) {
    final response = request.artisanResponse;
    if (response == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
              t('تفاصيل العرض', 'Bid Details'),
              style: GoogleFonts.cairo(
                  color: text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(t('توزيع السعر', 'Price Breakdown'),
                style: TextStyle(
                    color: dim, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...response.breakdown.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isArabic ? row.labelAr : row.labelEn,
                          style: TextStyle(color: text)),
                      Text('${row.amount.toStringAsFixed(0)} JOD',
                          style: TextStyle(
                              color: gold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
            Divider(color: border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('المجموع', 'Total'),
                    style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('${response.total.toStringAsFixed(0)} JOD',
                    style: TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Text(t('المهام', 'Tasks'),
                style: TextStyle(
                    color: dim, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...response.tasks.map((task) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(task,
                              style: TextStyle(color: text, fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Text(
              '${t('تاريخ التسليم:', 'Delivery:')} ${response.deliveryDate.day}/${response.deliveryDate.month}/${response.deliveryDate.year}',
              style: TextStyle(color: dim, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isArabic ? response.notesAr : response.notesEn,
              style: TextStyle(
                  color: dim, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  t('إغلاق', 'Close'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProgressUpdateDialog(
    BuildContext context,
    CustomOrderRequest request,
    CustomOrderProvider prov,
  ) {
    const stages = [
      'materials_received',
      'execution_started',
      'quality_review',
      'ready_for_delivery',
    ];

    final stageLabels = {
      'materials_received': t('تم استلام المواد', 'Materials Received'),
      'execution_started': t('بدأ التنفيذ', 'Execution Started'),
      'quality_review': t('مراجعة الجودة', 'Quality Review'),
      'ready_for_delivery': t('جاهز للتسليم', 'Ready for Delivery'),
    };

    final stagePercent = {
      'materials_received': 25,
      'execution_started': 50,
      'quality_review': 75,
      'ready_for_delivery': 100,
    };

    var selectedIndex = request.progressStage == null
        ? 0
        : stages.indexOf(request.progressStage!);

    if (selectedIndex < 0) selectedIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('تحديث مرحلة التنفيذ', 'Update Progress'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isArabic
                        ? request.templateTitleAr
                        : request.templateTitleEn,
                    style: TextStyle(color: dim, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...stages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final stage = entry.value;
                    final percent = stagePercent[stage] ?? 0;

                    return RadioListTile<int>(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              stageLabels[stage] ?? stage,
                              style: TextStyle(color: text),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      value: idx,
                      groupValue: selectedIndex,
                      onChanged: saving
                          ? null
                          : (val) {
                              if (val == null) return;
                              setSheetState(() => selectedIndex = val);
                            },
                      activeColor: gold,
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final stage = stages[selectedIndex];
                              final percent = stagePercent[stage] ?? 0;

                              setSheetState(() => saving = true);

                              final ok = await prov.artisanUpdateProgress(
                                requestId: request.id,
                                progressStage: stage,
                                progressPercent: percent,
                              );

                              if (!mounted) return;

                              if (!ok) {
                                if (sheetContext.mounted) {
                                  setSheetState(() => saving = false);
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        '❌ فشل تحديث المرحلة',
                                        '❌ Failed to update stage',
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t(
                                      'تم تحديث المرحلة إلى $percent% ✅',
                                      'Progress updated to $percent% ✅',
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              await _loadAllOrders();
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              t('تحديث', 'Update'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCompleteDialog(BuildContext context, CustomOrderRequest request,
      CustomOrderProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('تأكيد الإتمام', 'Confirm Completion'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('هل اكتملت الخدمة وترغب في إغلاق هذا الطلب؟',
              'Has the service been completed? Close this order?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('لا', 'No'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              prov.artisanUpdateStatus(request.id, 'completed');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('✅ تم إكمال الطلب', '✅ Order completed')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(t('نعم، اكتمل', 'Yes, Done'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 56, color: accent),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.cairo(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.cairo(color: dim, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Incoming Request Card ──────────────────────────────────────────────────
class _IncomingRequestCard extends StatelessWidget {
  final CustomOrderRequest request;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onRespond;
  final VoidCallback onDecline;

  const _IncomingRequestCard({
    required this.request,
    required this.isArabic,
    required this.isDarkMode,
    required this.onRespond,
    required this.onDecline,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final customerName = request.customerName;
    final templateTitle =
        isArabic ? request.templateTitleAr : request.templateTitleEn;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: gold.withValues(alpha: 0.15),
                child: Text(
                  customerName.isNotEmpty ? customerName[0] : '?',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      templateTitle,
                      style: TextStyle(color: dim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t('جديد', 'New'),
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: request.filledFields.entries.take(3).map((entry) {
              final value = entry.value.toString();
              if (value.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.length > 30 ? '${value.substring(0, 30)}...' : value,
                  style: TextStyle(color: dim, fontSize: 11),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    t('رفض', 'Decline'),
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onRespond,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    t('رد على الطلب', 'Respond'),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── In Progress Card ──────────────────────────────────────────────────────
class _InProgressCard extends StatelessWidget {
  final CustomOrderRequest request;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onUpdateProgress;
  final VoidCallback onComplete;

  const _InProgressCard({
    required this.request,
    required this.isArabic,
    required this.isDarkMode,
    required this.onUpdateProgress,
    required this.onComplete,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final response = request.artisanResponse;
    final percent = request.progressPercent ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? request.templateTitleAr : request.templateTitleEn,
                  style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('قيد التنفيذ', 'In Progress'),
                  style: TextStyle(
                      color: gold, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.customerName,
            style: TextStyle(color: dim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 8,
                    backgroundColor: gold.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percent%',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (response != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: gold),
                Text(
                  '${response.total.toStringAsFixed(0)} JOD',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule_outlined, size: 14, color: dim),
                const SizedBox(width: 4),
                Text(
                  '${response.deliveryDate.day}/${response.deliveryDate.month}/${response.deliveryDate.year}',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onUpdateProgress,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    t('تحديث المرحلة', 'Update Progress'),
                    style: TextStyle(color: text, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate to CreateDeliveryScreen for this custom order
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateDeliveryScreen(
                          isArabic: isArabic,
                          isDarkMode: isDarkMode,
                          orderId: '', // empty because it's a custom order
                          productId: '', // no product
                          productName: isArabic
                              ? request.templateTitleAr
                              : request.templateTitleEn,
                          customOrderId: request.id, // pass the custom order ID
                        ),
                      ),
                    ).then((_) => context
                        .read<CustomOrderProvider>()
                        .loadForArtisan(request.artisanId));
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: gold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    t('إدارة التوصيل', 'Manage Delivery'),
                    style: TextStyle(
                        color: gold, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    t('إكمال الطلب', 'Complete'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ── Completed Card ────────────────────────────────────────────────────────
class _CompletedCard extends StatelessWidget {
  final CustomOrderRequest request;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onReview;

  const _CompletedCard({
    required this.request,
    required this.isArabic,
    required this.isDarkMode,
    required this.onReview,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final response = request.artisanResponse;
    final isDone = request.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? request.templateTitleAr : request.templateTitleEn,
                  style: TextStyle(color: text, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDone ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isDone
                      ? t('مكتمل', 'Completed')
                      : t('ملغي/مرفوض', 'Cancelled'),
                  style: TextStyle(
                      color: isDone ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (!isDone) ...[
                const SizedBox(width: 4),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: surface,
                        title: Text(t('حذف الطلب', 'Delete Order'),
                            style: TextStyle(color: text)),
                        content: Text(
                            t('هل أنت متاكد من حذف هذا الطلب الملغي؟',
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
                    if (confirm != true || !context.mounted) return;
                    try {
                      final res = await ApiService.delete(
                          '/custom-orders/requests/${request.id}');
                      if (res.statusCode == 200 && context.mounted) {
                        final prov = context.read<CustomOrderProvider>();
                        await prov.loadForArtisan(request.artisanId);
                      }
                    } catch (e) {
                      debugPrint('Delete custom order error: $e');
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.customerName,
            style: TextStyle(color: dim, fontSize: 13),
          ),
          if (response != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: gold),
                Text(
                  '${response.total.toStringAsFixed(0)} JOD',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (isDone) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReview,
              icon: Icon(Icons.star, size: 16, color: gold),
              label: Text(
                t('تقييم الزبون', 'Rate Customer'),
                style: TextStyle(color: text, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Negotiating Card ──────────────────────────────────────────────────────
class _NegotiatingCard extends StatelessWidget {
  final CustomOrderRequest request;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onViewDetails;
  final VoidCallback onCancel;

  const _NegotiatingCard({
    required this.request,
    required this.isArabic,
    required this.isDarkMode,
    required this.onViewDetails,
    required this.onCancel,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  Color get text => isDarkMode ? Colors.white : Colors.black87;
  Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.08);
  Color get gold => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final response = request.artisanResponse;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isArabic ? request.templateTitleAr : request.templateTitleEn,
                style: TextStyle(color: text, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t('بانتظار الزبون', 'Waiting'),
                  style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.customerName,
            style: TextStyle(color: dim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (response != null)
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: gold),
                const SizedBox(width: 4),
                Text(
                  '${response.total.toStringAsFixed(0)} JOD',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule_outlined, size: 14, color: dim),
                const SizedBox(width: 4),
                Text(
                  '${response.deliveryDate.day}/${response.deliveryDate.month}/${response.deliveryDate.year}',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.task_alt_outlined, size: 14, color: dim),
                const SizedBox(width: 4),
                Text(
                  '${response.tasks.length} ${t('مهام', 'tasks')}',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    t('عرض التفاصيل', 'View Details'),
                    style: TextStyle(color: text, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    t('إلغاء', 'Cancel'),
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hire / On-Site Card ───────────────────────────────────────────────────
class _HireOrderCard extends StatelessWidget {
  final HireRequest request;
  final bool isArabic;
  final bool isDarkMode;
  final bool completed;

  const _HireOrderCard({
    required this.request,
    required this.isArabic,
    required this.isDarkMode,
    required this.completed,
  });

  String t(String ar, String en) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white60 : Colors.black54;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    const gold = Color(0xFFD4A017);
    final total = request.artisanResponse?.totalPrice ?? 0;
    final artisanShare = total * 0.90;
    String date(DateTime value) => '${value.day}/${value.month}/${value.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed
              ? Colors.green.withValues(alpha: 0.35)
              : gold.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.14),
                ),
                child: const Icon(Icons.handyman_outlined, color: gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.customerName.isEmpty
                          ? t('طلب عمل ميداني', 'On-Site Work')
                          : request.customerName,
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      t('عمل ميداني • Hire / On-Site',
                          'Hire / On-Site • Escrow protected'),
                      style: const TextStyle(color: gold, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (completed ? Colors.green : gold).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  completed
                      ? t('مكتمل', 'Completed')
                      : t('قيد التنفيذ', 'In Progress'),
                  style: TextStyle(
                    color: completed ? Colors.green : gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.jobDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: text, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: dim, size: 14),
              const SizedBox(width: 6),
              Text(
                '${date(request.startDate)}  →  ${date(request.endDate)}',
                style: TextStyle(color: dim, fontSize: 11),
              ),
              const Spacer(),
              Icon(Icons.schedule, color: dim, size: 14),
              const SizedBox(width: 4),
              Text('${request.dailyHours} h/day',
                  style: TextStyle(color: dim, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: text.withValues(alpha: 0.08)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(t('إجمالي الطلب', 'Order total'),
                  style: TextStyle(color: dim, fontSize: 11)),
              const Spacer(),
              Text('${total.toStringAsFixed(2)} JOD',
                  style: const TextStyle(
                      color: gold, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                  completed
                      ? Icons.account_balance_wallet_outlined
                      : Icons.lock_outline,
                  color: completed ? Colors.green : gold,
                  size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  completed
                      ? t('حصتك متاحة بعد تحرير الضمان',
                          'Your share is available after escrow release')
                      : t('حصتك محجوزة بأمان في الضمان',
                          'Your share is safely held in Escrow'),
                  style: TextStyle(color: dim, fontSize: 11),
                ),
              ),
              Text('${artisanShare.toStringAsFixed(2)} JOD',
                  style: TextStyle(
                    color: completed ? Colors.green : gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: request.progressPercent.clamp(0, 100) / 100,
                      minHeight: 7,
                      backgroundColor: gold.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(gold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${request.progressPercent.clamp(0, 100)}%',
                    style: const TextStyle(
                        color: gold, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.info_outline, size: 16, color: gold),
                label: Text(
                  t('تفاصيل العمل الميداني', 'On-Site Work Details'),
                  style: TextStyle(color: text, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';
// import '../../services/products_service.dart';
// import '../../services/api_service.dart';
// import '../custom_order/custom_order_provider.dart';
// import '../custom_order/custom_order_request.dart';
// import '../hire_order/hire_order_provider.dart';
// import 'artisan_response_screen.dart';
// import 'craftsman_review_customer_screen.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // CraftsmanOrdersScreen — إدارة الطلبات الواردة للحرفي
// //
// // Tabs:
// //   1. واردة (Incoming) — طلبات جديدة تحتاج رد
// //   2. مفاوضة (Negotiating) — رد الحرفي قيد انتظار موافقة الزبون
// //   3. قيد التنفيذ (In Progress) — طلبات معتمدة قيد العمل
// //   4. مكتملة (Completed) — طلبات منتهية
// // ─────────────────────────────────────────────────────────────────────────────

// class CraftsmanOrdersScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;
//   final String artisanId; // The logged-in artisan's ID

//   const CraftsmanOrdersScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.artisanId,
//   });

//   @override
//   State<CraftsmanOrdersScreen> createState() => _CraftsmanOrdersScreenState();
// }

// class _CraftsmanOrdersScreenState extends State<CraftsmanOrdersScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;

//   // Product orders from backend
//   List<Map<String, dynamic>> _productOrders = [];
//   bool _loadingOrders = true;
//   List<Map<String, dynamic>> _productOffers = [];

//   final Map<String, int> _customerReviewRatings = {};

//   // ── Colors ──────────────────────────────────────────────────────────────────
//   Color get bg =>
//       widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get surface =>
//       widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
//   Color get border => widget.isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get accent =>
//       widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
//   Color get gold => const Color(0xFFD4A017);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   String localizeNumber(String value) {
//     if (!widget.isArabic) return value;
//     const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
//     const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
//     for (int i = 0; i < en.length; i++) {
//       value = value.replaceAll(en[i], ar[i]);
//     }
//     return Container(
//         margin: const EdgeInsets.only(bottom: 8),
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//             border: Border.all(color: border),
//             borderRadius: BorderRadius.circular(8)),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('ID: $id • ${t('الحالة', 'Status')}: $status'),
//           const SizedBox(height: 6),
//           Text('${t('السائق', 'Driver')}: ${driver ?? ''}'),
//           const SizedBox(height: 8),
//           FutureBuilder<List<dynamic>>(
//             future: ProductsService.getAvailableDrivers(),
//             builder: (context, snap) {
//               if (!snap.hasData)
//                 return const SizedBox(
//                     height: 40,
//                     child: Center(child: CircularProgressIndicator()));
//               final drivers = snap.data ?? [];
//               String? selectedDriverId;
//               return Row(children: [
//                 Expanded(
//                   child: DropdownButtonFormField<String>(
//                     items: drivers.map<DropdownMenuItem<String>>((d) {
//                       final name = d['name'] ?? d['id'];
//                       final did = d['id']?.toString() ?? '';
//                       return DropdownMenuItem<String>(
//                           value: did, child: Text('$name • $did'));
//                     }).toList(),
//                     onChanged: (v) => selectedDriverId = v,
//                     decoration: InputDecoration(
//                         hintText: t('اختر سائقًا', 'Select driver')),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                     onPressed: () async {
//                       if (selectedDriverId == null || selectedDriverId!.isEmpty)
//                         return;
//                       final ok = await ProductsService.assignDriverToDelivery(
//                           id, selectedDriverId!);
//                       if (ok) {
//                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                             content:
//                                 Text(t('تم تعيين السائق', 'Driver assigned'))));
//                         load();
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                             content: Text(t('فشل في تعيين السائق',
//                                 'Failed to assign driver'))));
//                       }
//                     },
//                     child: Text(t('تعيين', 'Assign'))),
//               ]);
//             },
//           ),
//         ]));
//   }

//   Future<void> _loadProductOffers() async {
//     final offers = await ProductsService.getMyArtisanOffers();
//     if (mounted)
//       setState(() => _productOffers =
//           offers.map((e) => Map<String, dynamic>.from(e as Map)).toList());
//   }

//   Future<void> _loadProductOrders() async {
//     setState(() => _loadingOrders = true);
//     final orders = await ProductsService.getCraftsmanOrders(widget.artisanId);
//     if (mounted) {
//       setState(() {
//         _productOrders =
//             orders.map((o) => Map<String, dynamic>.from(o)).toList();
//         _loadingOrders = false;
//       });
//       await _loadCustomerReviewStates();
//     }
//   }

//   Future<void> _loadCustomerReviewStates() async {
//     final completedIds = _productOrders
//         .where((o) {
//           final status = (o['status'] ?? '').toString();
//           return status == 'completed' || status == 'delivered';
//         })
//         .map((o) => o['id']?.toString() ?? '')
//         .where((id) => id.isNotEmpty)
//         .toList();

//     for (final orderId in completedIds) {
//       try {
//         final response =
//             await ApiService.get('/reviews/customer/order/$orderId');

//         if (response.statusCode == 200 && response.body.isNotEmpty) {
//           final body = jsonDecode(response.body);
//           if (body is Map && body['reviewed'] == true) {
//             final review = body['review'];
//             final rawRating = review is Map ? review['rating'] : null;
//             final rating = rawRating is num
//                 ? rawRating.toInt()
//                 : int.tryParse(rawRating?.toString() ?? '');

//             if (rating != null) {
//               _customerReviewRatings[orderId] = rating;
//             }
//           } else {
//             _customerReviewRatings.remove(orderId);
//           }
//         }
//       } catch (_) {}
//     }

//     if (mounted) setState(() {});
//   }

//   Future<void> _updateProductOrderStatus(String orderId, String status) async {
//     final ok = await ProductsService.updateOrderStatus(orderId, status);
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text(ok
//             ? t('✅ تم تحديث حالة الطلب', '✅ Order status updated')
//             : t('❌ فشل التحديث', '❌ Update failed')),
//         backgroundColor: ok ? Colors.green : Colors.red,
//       ));
//       if (ok) _loadAllOrders();
//     }
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   // ── Status Helpers ──────────────────────────────────────────────────────────
//   String statusText(String status) {
//     final map = {
//       'pending_artisan': t('في انتظار ردك', 'Awaiting Your Response'),
//       'pending_customer': t('في انتظار الزبون', 'Awaiting Customer'),
//       'pending': t('قيد الانتظار', 'Pending'),
//       'accepted': t('مقبول', 'Accepted'),
//       'in_progress': t('قيد التنفيذ', 'In Progress'),
//       'completed': t('مكتمل', 'Completed'),
//       'rejected': t('مرفوض', 'Rejected'),
//       'cancelled': t('ملغي', 'Cancelled'),
//     };
//     return map[status] ?? status;
//   }

//   Color statusColor(String status) {
//     final map = {
//       'pending_artisan': Colors.orange,
//       'pending_customer': Colors.blue,
//       'pending': Colors.orange,
//       'accepted': Colors.blue,
//       'in_progress': gold,
//       'completed': Colors.green,
//       'rejected': Colors.red,
//       'cancelled': Colors.grey,
//     };
//     return map[status] ?? Colors.grey;
//   }

//   // ── Filtered Lists ──────────────────────────────────────────────────────────
//   List<CustomOrderRequest> _incomingRequests(CustomOrderProvider prov) {
//     return prov
//         .requestsForArtisan(widget.artisanId)
//         .where((r) => r.status == 'pending_artisan')
//         .toList();
//   }

//   List<CustomOrderRequest> _negotiatingRequests(CustomOrderProvider prov) {
//     return prov
//         .requestsForArtisan(widget.artisanId)
//         .where((r) => r.status == 'pending_customer')
//         .toList();
//   }

//   List<CustomOrderRequest> _inProgressRequests(CustomOrderProvider prov) {
//     return prov
//         .requestsForArtisan(widget.artisanId)
//         .where((r) => r.status == 'in_progress')
//         .toList();
//   }

//   List<CustomOrderRequest> _completedRequests(CustomOrderProvider prov) {
//     return prov
//         .requestsForArtisan(widget.artisanId)
//         .where((r) =>
//             r.status == 'completed' ||
//             r.status == 'rejected' ||
//             r.status == 'cancelled')
//         .toList();
//   }

//   List<Map<String, dynamic>> get _incomingProductOrders => _productOrders
//       .where((o) => (o['status'] ?? 'pending').toString() == 'pending')
//       .toList();

//   // Once the artisan accepts a paid ready-made order, it is already an
//   // approved active order. Show both `accepted` and `in_progress` in the
//   // In Progress tab so the order does not disappear after Accept.
//   List<Map<String, dynamic>> get _readyProductOrders => _productOrders
//       .where((o) => (o['status'] ?? '').toString() == 'ready')
//       .toList();

//   List<Map<String, dynamic>> get _inProgressProductOrders =>
//       _productOrders.where((o) {
//         final status = (o['status'] ?? '').toString();
//         return status == 'accepted' || status == 'in_progress';
//       }).toList();

//   List<Map<String, dynamic>> get _doneProductOrders =>
//       _productOrders.where((o) {
//         final status = (o['status'] ?? '').toString();

//         // `ready` is not finished yet. It belongs only in the Ready tab until
//         // the customer confirms receipt and the order becomes completed/delivered.
//         return status == 'completed' ||
//             status == 'delivered' ||
//             status == 'cancelled';
//       }).toList();

//   @override
//   Widget build(BuildContext context) {
//     final prov = context.watch<CustomOrderProvider>();
//     final hireProv = context.watch<HireOrderProvider>();
//     final incoming = _incomingRequests(prov);
//     final negotiating = _negotiatingRequests(prov);
//     final inProgress = _inProgressRequests(prov);
//     final completed = _completedRequests(prov);
//     final hireInProgress = hireProv
//         .requestsForArtisan(widget.artisanId)
//         .where((r) => r.status == 'in_progress')
//         .toList();
//     final hireCompleted = hireProv
//         .requestsForArtisan(widget.artisanId)
//         .where((r) => r.status == 'completed')
//         .toList();

//     final incomingProductOrders = _incomingProductOrders;
//     final readyProductOrders = _readyProductOrders;
//     final inProgressProductOrders = _inProgressProductOrders;
//     final doneProductOrders = _doneProductOrders;

//     final incomingCount = incoming.length + incomingProductOrders.length;
//     final inProgressCount = inProgress.length +
//         inProgressProductOrders.length +
//         hireInProgress.length;
//     final doneCount =
//         completed.length + doneProductOrders.length + hireCompleted.length;

//     return Directionality(
//       textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: bg,
//           elevation: 0,
//           title: Text(
//             t('الطلبات', 'Orders'),
//             style: GoogleFonts.cairo(
//                 color: text, fontWeight: FontWeight.bold, fontSize: 20),
//           ),
//           actions: [
//             // Language toggle
//             TextButton(
//               onPressed: () =>
//                   context.read<dynamic>().toggleLanguage != null ? null : null,
//               child: const SizedBox.shrink(),
//             ),
//             GestureDetector(
//               onTap: () {
//                 // Toggle language via AppState
//                 final appState = Provider.of<dynamic>(context, listen: false);
//                 if (appState.runtimeType.toString().contains('AppState')) {
//                   appState.toggleLanguage();
//                 }
//               },
//               child: Container(
//                 margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: surface,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(
//                       color:
//                           widget.isDarkMode ? Colors.white12 : Colors.black12),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.language, size: 13, color: text),
//                     const SizedBox(width: 3),
//                     Text(
//                       widget.isArabic ? 'EN' : 'عر',
//                       style: TextStyle(
//                           color: text,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             GestureDetector(
//               onTap: () {
//                 final appState = Provider.of<dynamic>(context, listen: false);
//                 if (appState.runtimeType.toString().contains('AppState')) {
//                   appState.toggleTheme();
//                 }
//               },
//               child: Container(
//                 margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
//                 width: 34,
//                 decoration: BoxDecoration(
//                   color: surface,
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                       color:
//                           widget.isDarkMode ? Colors.white12 : Colors.black12),
//                 ),
//                 child: Icon(
//                   widget.isDarkMode
//                       ? Icons.light_mode_outlined
//                       : Icons.dark_mode_outlined,
//                   color: accent,
//                   size: 16,
//                 ),
//               ),
//             ),
//           ],
//           bottom: TabBar(
//             controller: _tabController,
//             labelColor: accent,
//             unselectedLabelColor: dim,
//             indicatorColor: accent,
//             indicatorWeight: 3,
//             labelStyle:
//                 GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
//             tabs: [
//               Tab(
//                   text:
//                       t('واردة ($incomingCount)', 'Incoming ($incomingCount)')),
//               Tab(
//                   text: t('مفاوضة (${negotiating.length})',
//                       'Negotiating (${negotiating.length})')),
//               Tab(
//                   text: t('قيد التنفيذ ($inProgressCount)',
//                       'In Progress ($inProgressCount)')),
//               Tab(text: t('مكتملة ($doneCount)', 'Done ($doneCount)')),
//               Tab(
//                   text: t('جاهزة (${readyProductOrders.length})',
//                       'Ready (${readyProductOrders.length})')),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           controller: _tabController,
//           children: [
//             _buildIncomingCombinedTab(incoming, prov, incomingProductOrders),
//             _buildNegotiatingTab(negotiating, prov),
//             _buildInProgressCombinedTab(
//               inProgress,
//               prov,
//               inProgressProductOrders,
//               hireInProgress,
//             ),
//             _buildCompletedCombinedTab(
//               completed,
//               prov,
//               doneProductOrders,
//               hireCompleted,
//             ),
//             _buildProductOrdersTab(orders: readyProductOrders),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildIncomingCombinedTab(
//     List<CustomOrderRequest> requests,
//     CustomOrderProvider prov,
//     List<Map<String, dynamic>> productOrders,
//   ) {
//     if (requests.isEmpty && productOrders.isEmpty) {
//       return _buildEmptyState(
//         Icons.inbox_outlined,
//         t('لا توجد طلبات واردة', 'No incoming requests'),
//         t('ستظهر هنا الطلبات الجديدة من الزبائن',
//             'New customer requests will appear here'),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _loadAllOrders,
//       color: gold,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(
//           parent: BouncingScrollPhysics(),
//         ),
//         children: [
//           ...requests.map(
//             (request) => _IncomingRequestCard(
//               request: request,
//               isArabic: widget.isArabic,
//               isDarkMode: widget.isDarkMode,
//               onRespond: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => ArtisanResponseScreen(
//                       isArabic: widget.isArabic,
//                       isDarkMode: widget.isDarkMode,
//                       request: request,
//                       artisanId: widget.artisanId,
//                     ),
//                   ),
//                 ).then((_) => _loadAllOrders());
//               },
//               onDecline: () => _showDeclineDialog(context, request, prov),
//             ),
//           ),
//           ...productOrders.map((order) => _buildProductOrderCard(order)),
//         ],
//       ),
//     );
//   }

//   Widget _buildInProgressCombinedTab(
//     List<CustomOrderRequest> requests,
//     CustomOrderProvider prov,
//     List<Map<String, dynamic>> productOrders,
//     List<HireRequest> hireRequests,
//   ) {
//     if (requests.isEmpty && productOrders.isEmpty && hireRequests.isEmpty) {
//       return _buildEmptyState(
//         Icons.build_outlined,
//         t('لا توجد طلبات قيد التنفيذ', 'No orders in progress'),
//         t('الطلبات المعتمدة تظهر هنا', 'Approved orders appear here'),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _loadAllOrders,
//       color: gold,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(
//           parent: BouncingScrollPhysics(),
//         ),
//         children: [
//           ...requests.map(
//             (request) => _InProgressCard(
//               request: request,
//               isArabic: widget.isArabic,
//               isDarkMode: widget.isDarkMode,
//               onUpdateProgress: () =>
//                   _showProgressUpdateDialog(context, request, prov),
//               onComplete: () => _showCompleteDialog(context, request, prov),
//             ),
//           ),
//           ...productOrders.map((order) => _buildProductOrderCard(order)),
//           ...hireRequests.map(
//             (request) => _HireOrderCard(
//               request: request,
//               isArabic: widget.isArabic,
//               isDarkMode: widget.isDarkMode,
//               completed: false,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCompletedCombinedTab(
//     List<CustomOrderRequest> requests,
//     CustomOrderProvider prov,
//     List<Map<String, dynamic>> productOrders,
//     List<HireRequest> hireRequests,
//   ) {
//     if (requests.isEmpty && productOrders.isEmpty && hireRequests.isEmpty) {
//       return _buildEmptyState(
//         Icons.check_circle_outline,
//         t('لا توجد طلبات مكتملة', 'No completed orders'),
//         t('الطلبات المنجزة تظهر هنا', 'Completed orders appear here'),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _loadAllOrders,
//       color: gold,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(
//           parent: BouncingScrollPhysics(),
//         ),
//         children: [
//           ...requests.map(
//             (request) => _CompletedCard(
//               request: request,
//               isArabic: widget.isArabic,
//               isDarkMode: widget.isDarkMode,
//               onReview: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => CraftsmanReviewCustomerScreen(
//                       isArabic: widget.isArabic,
//                       isDarkMode: widget.isDarkMode,
//                       customerName: request.customerName,
//                       orderId: request.id.toString(),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           ...productOrders.map((order) => _buildProductOrderCard(order)),
//           ...hireRequests.map(
//             (request) => _HireOrderCard(
//               request: request,
//               isArabic: widget.isArabic,
//               isDarkMode: widget.isDarkMode,
//               completed: true,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── 1. INCOMING TAB ─────────────────────────────────────────────────────────
//   Widget _buildIncomingTab(
//       List<CustomOrderRequest> requests, CustomOrderProvider prov) {
//     if (requests.isEmpty) {
//       return _buildEmptyState(
//         Icons.inbox_outlined,
//         t('لا توجد طلبات واردة', 'No incoming requests'),
//         t('ستظهر هنا الطلبات الجديدة من الزبائن',
//             'New customer requests will appear here'),
//       );
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       physics: const BouncingScrollPhysics(),
//       itemCount: requests.length,
//       itemBuilder: (context, i) => _IncomingRequestCard(
//         request: requests[i],
//         isArabic: widget.isArabic,
//         isDarkMode: widget.isDarkMode,
//         onRespond: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => ArtisanResponseScreen(
//                 isArabic: widget.isArabic,
//                 isDarkMode: widget.isDarkMode,
//                 request: requests[i],
//                 artisanId: widget.artisanId,
//               ),
//             ),
//           ).then((_) => _loadAllOrders());
//         },
//         onDecline: () => _showDeclineDialog(context, requests[i], prov),
//       ),
//     );
//   }

//   // ── 2. NEGOTIATING TAB ──────────────────────────────────────────────────────
//   Widget _buildNegotiatingTab(
//       List<CustomOrderRequest> requests, CustomOrderProvider prov) {
//     if (requests.isEmpty && _productOffers.isEmpty) {
//       return _buildEmptyState(
//         Icons.hourglass_empty,
//         t('لا توجد طلبات قيد المفاوضة', 'No negotiations in progress'),
//         t('الطلبات التي ردّ عليها الحرفي تظهر هنا',
//             'Requests you\'ve responded to appear here'),
//       );
//     }
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       physics: const BouncingScrollPhysics(),
//       children: [
//         ..._productOffers
//             .where((o) =>
//                 ['pending', 'countered', 'accepted'].contains(o['status']))
//             .map(_buildProductOfferCard),
//         ...List.generate(
//             requests.length,
//             (i) => _NegotiatingCard(
//                   request: requests[i],
//                   isArabic: widget.isArabic,
//                   isDarkMode: widget.isDarkMode,
//                   onViewDetails: () {
//                     _showNegotiationDetails(context, requests[i]);
//                   },
//                   onCancel: () => _showCancelDialog(context, requests[i], prov),
//                 )),
//       ],
//     );
//   }

//   Widget _buildProductOfferCard(Map<String, dynamic> offer) {
//     final product = Map<String, dynamic>.from(offer['product'] ?? const {});
//     final customer = Map<String, dynamic>.from(offer['customer'] ?? const {});
//     final status = offer['status'].toString();
//     return Card(
//       color: surface,
//       margin: const EdgeInsets.only(bottom: 12),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text(product['titleEn']?.toString() ?? 'Product offer',
//               style:
//                   GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
//           Text(
//               '${customer['name'] ?? 'Customer'} • ${offer['offeredUnitPrice']} JOD',
//               style: GoogleFonts.cairo(color: gold)),
//           Text(t('الحالة: $status', 'Status: $status'),
//               style: GoogleFonts.cairo(color: dim, fontSize: 12)),
//           if (status == 'pending')
//             Row(children: [
//               TextButton(
//                   onPressed: () async {
//                     await ProductsService.respondToOffer(offer['id'].toString(),
//                         action: 'reject');
//                     _loadAllOrders();
//                   },
//                   child: Text(t('رفض', 'Reject'))),
//               const Spacer(),
//               OutlinedButton(
//                   onPressed: () => _counterOffer(offer),
//                   child: Text(t('عرض مضاد', 'Counter'))),
//               const SizedBox(width: 8),
//               FilledButton(
//                   onPressed: () async {
//                     await ProductsService.respondToOffer(offer['id'].toString(),
//                         action: 'accept');
//                     _loadAllOrders();
//                   },
//                   child: Text(t('قبول', 'Accept'))),
//             ]),
//         ]),
//       ),
//     );
//   }

//   Future<void> _counterOffer(Map<String, dynamic> offer) async {
//     final controller = TextEditingController();
//     final value = await showDialog<double>(
//         context: context,
//         builder: (c) => AlertDialog(
//               backgroundColor: surface,
//               title: Text(t('عرض مضاد', 'Counter offer'),
//                   style: TextStyle(color: text)),
//               content: TextField(
//                   controller: controller,
//                   keyboardType: TextInputType.number,
//                   style: TextStyle(color: text)),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(c),
//                     child: Text(t('إلغاء', 'Cancel'))),
//                 FilledButton(
//                     onPressed: () =>
//                         Navigator.pop(c, double.tryParse(controller.text)),
//                     child: Text(t('إرسال', 'Send')))
//               ],
//             ));
//     controller.dispose();
//     if (value != null) {
//       await ProductsService.respondToOffer(offer['id'].toString(),
//           action: 'counter', counterPrice: value);
//       _loadAllOrders();
//     }
//   }

//   // ── 3. IN PROGRESS TAB ─────────────────────────────────────────────────────
//   Widget _buildInProgressTab(
//       List<CustomOrderRequest> requests, CustomOrderProvider prov) {
//     if (requests.isEmpty) {
//       return _buildEmptyState(
//         Icons.build_outlined,
//         t('لا توجد طلبات قيد التنفيذ', 'No orders in progress'),
//         t('الطلبات المعتمدة تظهر هنا', 'Approved orders appear here'),
//       );
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       physics: const BouncingScrollPhysics(),
//       itemCount: requests.length,
//       itemBuilder: (context, i) => _InProgressCard(
//         request: requests[i],
//         isArabic: widget.isArabic,
//         isDarkMode: widget.isDarkMode,
//         onUpdateProgress: () =>
//             _showProgressUpdateDialog(context, requests[i], prov),
//         onComplete: () => _showCompleteDialog(context, requests[i], prov),
//       ),
//     );
//   }

//   // ── 4. COMPLETED TAB ───────────────────────────────────────────────────────
//   Widget _buildCompletedTab(
//       List<CustomOrderRequest> requests, CustomOrderProvider prov) {
//     if (requests.isEmpty) {
//       return _buildEmptyState(
//         Icons.check_circle_outline,
//         t('لا توجد طلبات مكتملة', 'No completed orders'),
//         t('الطلبات المنجزة تظهر هنا', 'Completed orders appear here'),
//       );
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       physics: const BouncingScrollPhysics(),
//       itemCount: requests.length,
//       itemBuilder: (context, i) => _CompletedCard(
//         request: requests[i],
//         isArabic: widget.isArabic,
//         isDarkMode: widget.isDarkMode,
//         onReview: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => CraftsmanReviewCustomerScreen(
//                 isArabic: widget.isArabic,
//                 isDarkMode: widget.isDarkMode,
//                 customerName: requests[i].customerName,
//                 orderId: requests[i].id.toString(),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildProductOrdersTab({required List<Map<String, dynamic>> orders}) {
//     if (_loadingOrders) {
//       return Center(child: CircularProgressIndicator(color: gold));
//     }

//     if (orders.isEmpty) {
//       return _buildEmptyState(
//         Icons.local_shipping_outlined,
//         t('لا توجد طلبات جاهزة', 'No ready orders'),
//         t('الطلبات المقبولة والجاهزة لبدء التنفيذ ستظهر هنا',
//             'Accepted product orders ready to start will appear here'),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: _loadAllOrders,
//       color: gold,
//       child: ListView.builder(
//         padding: const EdgeInsets.all(16),
//         physics: const AlwaysScrollableScrollPhysics(
//           parent: BouncingScrollPhysics(),
//         ),
//         itemCount: orders.length,
//         itemBuilder: (context, index) => _buildProductOrderCard(orders[index]),
//       ),
//     );
//   }

//   Widget _buildProductOrderCard(Map<String, dynamic> order) {
//     final rawItems = order['items'];
//     final firstItem =
//         rawItems is List && rawItems.isNotEmpty && rawItems.first is Map
//             ? Map<String, dynamic>.from(rawItems.first as Map)
//             : <String, dynamic>{};

//     final orderId = order['id']?.toString() ?? '';
//     final status = (order['status'] ?? 'pending').toString();
//     final totalPrice = order['totalAmount'] ?? firstItem['unitPrice'] ?? 0;
//     final deliveryAddress = order['shippingAddress']?.toString() ?? '';
//     final productName = firstItem['productName']?.toString() ?? '—';
//     final productImage = firstItem['imageUrl']?.toString() ?? '';
//     final customerName = order['customerName']?.toString() ?? '';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: border),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (productImage.isNotEmpty)
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(10),
//                   child: Image.network(
//                     productImage,
//                     width: 60,
//                     height: 60,
//                     fit: BoxFit.cover,
//                     errorBuilder: (c, e, s) => Container(
//                       width: 60,
//                       height: 60,
//                       decoration: BoxDecoration(
//                         color: gold.withValues(alpha: 0.12),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Icon(Icons.inventory_2_outlined, color: gold),
//                     ),
//                   ),
//                 )
//               else
//                 Container(
//                   width: 60,
//                   height: 60,
//                   decoration: BoxDecoration(
//                     color: gold.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(Icons.inventory_2_outlined, color: gold),
//                 ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             productName,
//                             style: TextStyle(
//                               color: text,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 15,
//                             ),
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 3,
//                           ),
//                           decoration: BoxDecoration(
//                             color: statusColor(status).withValues(alpha: 0.15),
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Text(
//                             statusText(status),
//                             style: TextStyle(
//                               color: statusColor(status),
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${t('الزبون: ', 'Customer: ')}$customerName',
//                       style: TextStyle(color: dim, fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             '${t('العنوان: ', 'Address: ')}$deliveryAddress',
//             style: TextStyle(color: dim, fontSize: 12),
//           ),
//           const SizedBox(height: 8),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 '$totalPrice JOD',
//                 style: TextStyle(
//                   color: gold,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 15,
//                 ),
//               ),
//               if (status == 'pending')
//                 Row(
//                   children: [
//                     ElevatedButton(
//                       onPressed: () =>
//                           _updateProductOrderStatus(orderId, 'accepted'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 4,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       child: Text(
//                         t('قبول', 'Accept'),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     OutlinedButton(
//                       onPressed: () =>
//                           _updateProductOrderStatus(orderId, 'cancelled'),
//                       style: OutlinedButton.styleFrom(
//                         side: const BorderSide(color: Colors.red),
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 4,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       child: Text(
//                         t('رفض', 'Reject'),
//                         style: const TextStyle(
//                           color: Colors.red,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ),
//                   ],
//                 )
//               else if (status == 'accepted')
//                 ElevatedButton(
//                   onPressed: () =>
//                       _updateProductOrderStatus(orderId, 'in_progress'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: gold,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 4,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: Text(
//                     t('بدء التنفيذ', 'Start Work'),
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontSize: 12,
//                     ),
//                   ),
//                 )
//               else if (status == 'completed')
//                 _customerReviewRatings[orderId] != null
//                     ? Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 14,
//                           vertical: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.green.withValues(alpha: 0.10),
//                           borderRadius: BorderRadius.circular(10),
//                           border: Border.all(
//                             color: Colors.green.withValues(alpha: 0.55),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             const Icon(
//                               Icons.star_rounded,
//                               size: 17,
//                               color: Colors.green,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               t(
//                                 'تم التقييم ${_customerReviewRatings[orderId]}/5',
//                                 'Rated ${_customerReviewRatings[orderId]}/5',
//                               ),
//                               style: const TextStyle(
//                                 color: Colors.green,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ],
//                         ),
//                       )
//                     : OutlinedButton.icon(
//                         onPressed: () async {
//                           final rating = await Navigator.push<int>(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => CraftsmanReviewCustomerScreen(
//                                 isArabic: widget.isArabic,
//                                 isDarkMode: widget.isDarkMode,
//                                 customerName: customerName,
//                                 orderId: orderId,
//                               ),
//                             ),
//                           );

//                           if (rating != null && mounted) {
//                             setState(() {
//                               _customerReviewRatings[orderId] = rating;
//                             });
//                           }

//                           await _loadAllOrders();
//                         },
//                         icon: Icon(Icons.star, size: 17, color: gold),
//                         label: Text(
//                           t('تقييم الزبون', 'Rate Customer'),
//                           style: TextStyle(
//                             color: text,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                           ),
//                         ),
//                         style: OutlinedButton.styleFrom(
//                           side: BorderSide(color: border),
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 14,
//                             vertical: 8,
//                           ),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                         ),
//                       )
//               else if (status == 'in_progress')
//                 ElevatedButton(
//                   onPressed: () => _updateProductOrderStatus(orderId, 'ready'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 4,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: Text(
//                     t('إكمال التوصيل', 'Complete'),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               const SizedBox(width: 8),
//               // Manage delivery button
//               OutlinedButton(
//                 onPressed: () => _showManageDeliveryDialog(order),
//                 style: OutlinedButton.styleFrom(
//                   side: BorderSide(color: border),
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                 ),
//                 child: Text(t('إدارة التوصيل', 'Manage Delivery')),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showManageDeliveryDialog(Map<String, dynamic> order) async {
//     final firstItem = (order['items'] is List && order['items'].isNotEmpty)
//         ? Map<String, dynamic>.from(order['items'][0])
//         : <String, dynamic>{};
//     final productId = firstItem['productId']?.toString() ?? '';
//     final shippingAddress = order['shippingAddress']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (ctx) => Dialog(
//         child: StatefulBuilder(builder: (ctx2, setState) {
//           List<dynamic> deliveries = [];
//           List<dynamic> availableDrivers = [];
//           bool loading = true;
//           final Map<String, String> selectedDriverByDelivery = {};

//           void load() async {
//             final list =
//                 await ProductsService.getArtisanDeliveries(widget.artisanId);
//             final drivers = await ProductsService.getAvailableDrivers();
//             final filtered = list.where((d) {
//               try {
//                 final pid = (d['productId'] ?? '').toString();
//                 final addr = (d['dropoffAddress'] ?? '').toString();
//                 return pid == productId &&
//                     (addr.isEmpty || addr == shippingAddress);
//               } catch (_) {
//                 return false;
//               }
//             }).toList();
//             if (mounted)
//               setState(() {
//                 deliveries = filtered;
//                 availableDrivers = drivers;
//                 loading = false;
//               });
//           }

//           // Kick off loader
//           WidgetsBinding.instance.addPostFrameCallback((_) => load());

//           return Container(
//             padding: const EdgeInsets.all(16),
//             width: 460,
//             child: Column(mainAxisSize: MainAxisSize.min, children: [
//               Text(t('طلبات التوصيل', 'Delivery Orders'),
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 12),
//               if (loading) const CircularProgressIndicator(),
//               if (!loading && deliveries.isEmpty)
//                 Text(t('لا توجد طلبات توصيل مرتبطة',
//                     'No related delivery orders')),
//               if (!loading && deliveries.isNotEmpty)
//                 ...deliveries.map((d) {
//                   final id = d['id']?.toString() ?? '';
//                   final status = d['status']?.toString() ?? '';
//                   final driver = d['driver'] != null
//                       ? (d['driver']['name'] ?? '')
//                       : (d['driverId'] ?? '');
//                   return Container(
//                       margin: const EdgeInsets.only(bottom: 8),
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                           border: Border.all(color: border),
//                           borderRadius: BorderRadius.circular(8)),
//                       child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('ID: $id • ${t('الحالة', 'Status')}: $status'),
//                             const SizedBox(height: 6),
//                             Text('${t('السائق', 'Driver')}: ${driver ?? ''}'),
//                             const SizedBox(height: 8),
//                             Row(children: [
//                               Expanded(
//                                 child: DropdownButtonFormField<String>(
//                                   value: selectedDriverByDelivery[id],
//                                   items: availableDrivers
//                                       .map<DropdownMenuItem<String>>((d) {
//                                     final name = d['name'] ?? d['id'];
//                                     final did = d['id']?.toString() ?? '';
//                                     return DropdownMenuItem<String>(
//                                         value: did,
//                                         child: Text('$name • $did'));
//                                   }).toList(),
//                                   onChanged: (v) => setState(() =>
//                                       selectedDriverByDelivery[id] = v ?? ''),
//                                   decoration: InputDecoration(
//                                       hintText:
//                                           t('اختر سائقًا', 'Select driver')),
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               ElevatedButton(
//                                 onPressed: () async {
//                                   final selectedDriverId =
//                                       selectedDriverByDelivery[id];
//                                   if (selectedDriverId == null ||
//                                       selectedDriverId.isEmpty) return;
//                                   final ok = await ProductsService
//                                       .assignDriverToDelivery(
//                                           id, selectedDriverId);
//                                   if (ok) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                             content: Text(t('تم تعيين السائق',
//                                                 'Driver assigned'))));
//                                     load();
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                             content: Text(t(
//                                                 'فشل في تعيين السائق',
//                                                 'Failed to assign driver'))));
//                                   }
//                                 },
//                                 child: Text(t('تعيين', 'Assign')),
//                               ),
//                             ])
//                           ]));
//                 }).toList(),
//               const SizedBox(height: 12),
//               Align(
//                   alignment: Alignment.centerRight,
//                   child: TextButton(
//                       onPressed: () => Navigator.pop(ctx),
//                       child: Text(t('إغلاق', 'Close')))),
//             ]),
//           );
//         }),
//       ),
//     );
//   }

//   // ── Dialogs ──────────────────────────────────────────────────────────────────
//   void _showDeclineDialog(BuildContext context, CustomOrderRequest request,
//       CustomOrderProvider prov) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: surface,
//         title: Text(t('رفض الطلب', 'Decline Order'),
//             style: TextStyle(color: text)),
//         content: Text(
//           t('هل أنت متأكد من رفض هذا الطلب؟',
//               'Are you sure you want to decline this order?'),
//           style: TextStyle(color: dim),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             onPressed: () {
//               Navigator.pop(ctx);
//               prov.customerReject(request.id);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(t('تم رفض الطلب', 'Order declined')),
//                   backgroundColor: Colors.red,
//                 ),
//               );
//             },
//             child: Text(t('رفض', 'Decline'),
//                 style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showCancelDialog(BuildContext context, CustomOrderRequest request,
//       CustomOrderProvider prov) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: surface,
//         title: Text(t('إلغاء المفاوضة', 'Cancel Negotiation'),
//             style: TextStyle(color: text)),
//         content: Text(
//           t('هل تريد إلغاء هذه المفاوضة؟',
//               'Do you want to cancel this negotiation?'),
//           style: TextStyle(color: dim),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             onPressed: () {
//               Navigator.pop(ctx);
//               prov.customerCancel(request.id);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content:
//                       Text(t('تم إلغاء المفاوضة', 'Negotiation cancelled')),
//                   backgroundColor: Colors.red,
//                 ),
//               );
//             },
//             child: Text(t('إلغاء', 'Cancel'),
//                 style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showNegotiationDetails(
//       BuildContext context, CustomOrderRequest request) {
//     final response = request.artisanResponse;
//     if (response == null) return;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) => Container(
//         padding: const EdgeInsets.all(24),
//         decoration: BoxDecoration(
//           color: surface,
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
//           border: Border.all(color: border),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Center(
//               child: Container(
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                       color: border, borderRadius: BorderRadius.circular(2))),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               t('تفاصيل العرض', 'Bid Details'),
//               style: GoogleFonts.cairo(
//                   color: text, fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             // Price Breakdown
//             Text(t('توزيع السعر', 'Price Breakdown'),
//                 style: TextStyle(
//                     color: dim, fontSize: 12, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             ...response.breakdown.map((row) => Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(widget.isArabic ? row.labelAr : row.labelEn,
//                           style: TextStyle(color: text)),
//                       Text('${row.amount.toStringAsFixed(0)} JOD',
//                           style: TextStyle(
//                               color: gold, fontWeight: FontWeight.bold)),
//                     ],
//                   ),
//                 )),
//             Divider(color: border),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(t('المجموع', 'Total'),
//                     style: TextStyle(
//                         color: text,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16)),
//                 Text('${response.total.toStringAsFixed(0)} JOD',
//                     style: TextStyle(
//                         color: gold,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16)),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Text(t('المهام', 'Tasks'),
//                 style: TextStyle(
//                     color: dim, fontSize: 12, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             ...response.tasks.map((task) => Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 3),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.check_circle_outline,
//                           size: 14, color: Color(0xFF4CAF50)),
//                       const SizedBox(width: 8),
//                       Expanded(
//                           child: Text(task,
//                               style: TextStyle(color: text, fontSize: 13))),
//                     ],
//                   ),
//                 )),
//             const SizedBox(height: 12),
//             Text(
//               '${t('تاريخ التسليم:', 'Delivery:')} ${response.deliveryDate.day}/${response.deliveryDate.month}/${response.deliveryDate.year}',
//               style: TextStyle(color: dim, fontSize: 13),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               widget.isArabic ? response.notesAr : response.notesEn,
//               style: TextStyle(
//                   color: dim, fontSize: 13, fontStyle: FontStyle.italic),
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: gold,
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14)),
//                 ),
//                 onPressed: () => Navigator.pop(ctx),
//                 child: Text(
//                   t('إغلاق', 'Close'),
//                   style: TextStyle(
//                       color: Colors.black, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showProgressUpdateDialog(
//     BuildContext context,
//     CustomOrderRequest request,
//     CustomOrderProvider prov,
//   ) {
//     const stages = [
//       'materials_received',
//       'execution_started',
//       'quality_review',
//       'ready_for_delivery',
//     ];

//     final stageLabels = {
//       'materials_received': t('تم استلام المواد', 'Materials Received'),
//       'execution_started': t('بدأ التنفيذ', 'Execution Started'),
//       'quality_review': t('مراجعة الجودة', 'Quality Review'),
//       'ready_for_delivery': t('جاهز للتسليم', 'Ready for Delivery'),
//     };

//     final stagePercent = {
//       'materials_received': 25,
//       'execution_started': 50,
//       'quality_review': 75,
//       'ready_for_delivery': 100,
//     };

//     var selectedIndex = request.progressStage == null
//         ? 0
//         : stages.indexOf(request.progressStage!);

//     if (selectedIndex < 0) selectedIndex = 0;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (sheetContext) {
//         bool saving = false;

//         return StatefulBuilder(
//           builder: (sheetContext, setSheetState) {
//             return Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: surface,
//                 borderRadius:
//                     const BorderRadius.vertical(top: Radius.circular(28)),
//                 border: Border.all(color: border),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 4,
//                       decoration: BoxDecoration(
//                         color: border,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     t('تحديث مرحلة التنفيذ', 'Update Progress'),
//                     style: GoogleFonts.cairo(
//                       color: text,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     widget.isArabic
//                         ? request.templateTitleAr
//                         : request.templateTitleEn,
//                     style: TextStyle(color: dim, fontSize: 13),
//                   ),
//                   const SizedBox(height: 16),
//                   ...stages.asMap().entries.map((entry) {
//                     final idx = entry.key;
//                     final stage = entry.value;
//                     final percent = stagePercent[stage] ?? 0;

//                     return RadioListTile<int>(
//                       title: Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               stageLabels[stage] ?? stage,
//                               style: TextStyle(color: text),
//                             ),
//                           ),
//                           Text(
//                             '$percent%',
//                             style: TextStyle(
//                               color: gold,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                       value: idx,
//                       groupValue: selectedIndex,
//                       onChanged: saving
//                           ? null
//                           : (val) {
//                               if (val == null) return;
//                               setSheetState(() => selectedIndex = val);
//                             },
//                       activeColor: gold,
//                     );
//                   }),
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 48,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: gold,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                       ),
//                       onPressed: saving
//                           ? null
//                           : () async {
//                               final stage = stages[selectedIndex];
//                               final percent = stagePercent[stage] ?? 0;

//                               setSheetState(() => saving = true);

//                               final ok = await prov.artisanUpdateProgress(
//                                 requestId: request.id,
//                                 progressStage: stage,
//                                 progressPercent: percent,
//                               );

//                               if (!mounted) return;

//                               if (!ok) {
//                                 if (sheetContext.mounted) {
//                                   setSheetState(() => saving = false);
//                                 }

//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     content: Text(
//                                       t(
//                                         '❌ فشل تحديث المرحلة',
//                                         '❌ Failed to update stage',
//                                       ),
//                                     ),
//                                     backgroundColor: Colors.red,
//                                   ),
//                                 );
//                                 return;
//                               }

//                               if (sheetContext.mounted) {
//                                 Navigator.pop(sheetContext);
//                               }

//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     t(
//                                       'تم تحديث المرحلة إلى $percent% ✅',
//                                       'Progress updated to $percent% ✅',
//                                     ),
//                                   ),
//                                   backgroundColor: Colors.green,
//                                 ),
//                               );

//                               await _loadAllOrders();
//                             },
//                       child: saving
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.black,
//                               ),
//                             )
//                           : Text(
//                               t('تحديث', 'Update'),
//                               style: const TextStyle(
//                                 color: Colors.black,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showCompleteDialog(BuildContext context, CustomOrderRequest request,
//       CustomOrderProvider prov) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: surface,
//         title: Text(t('تأكيد الإتمام', 'Confirm Completion'),
//             style: TextStyle(color: text, fontWeight: FontWeight.bold)),
//         content: Text(
//           t('هل اكتملت الخدمة وترغب في إغلاق هذا الطلب؟',
//               'Has the service been completed? Close this order?'),
//           style: TextStyle(color: dim),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: Text(t('لا', 'No'), style: TextStyle(color: dim)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             onPressed: () {
//               Navigator.pop(ctx);
//               prov.artisanUpdateStatus(request.id, 'completed');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(t('✅ تم إكمال الطلب', '✅ Order completed')),
//                   backgroundColor: Colors.green,
//                 ),
//               );
//             },
//             child: Text(t('نعم، اكتمل', 'Yes, Done'),
//                 style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Empty State ──────────────────────────────────────────────────────────────
//   Widget _buildEmptyState(IconData icon, String title, String subtitle) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: accent.withValues(alpha: 0.08),
//             ),
//             child: Icon(icon, size: 56, color: accent),
//           ),
//           const SizedBox(height: 16),
//           Text(title,
//               style: GoogleFonts.cairo(
//                   color: text, fontSize: 16, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 6),
//           Text(subtitle, style: GoogleFonts.cairo(color: dim, fontSize: 13)),
//         ],
//       ),
//     );
//   }
// }

// // ── Incoming Request Card ──────────────────────────────────────────────────
// class _IncomingRequestCard extends StatelessWidget {
//   final CustomOrderRequest request;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onRespond;
//   final VoidCallback onDecline;

//   const _IncomingRequestCard({
//     required this.request,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onRespond,
//     required this.onDecline,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;

//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get border => isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get gold => const Color(0xFFD4A017);

//   @override
//   Widget build(BuildContext context) {
//     final customerName = request.customerName;
//     final templateTitle =
//         isArabic ? request.templateTitleAr : request.templateTitleEn;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withValues(alpha: 0.05),
//               blurRadius: 10,
//               offset: const Offset(0, 4))
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 20,
//                 backgroundColor: gold.withValues(alpha: 0.15),
//                 child: Text(
//                   customerName.isNotEmpty ? customerName[0] : '?',
//                   style: TextStyle(color: gold, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       customerName,
//                       style:
//                           TextStyle(color: text, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       templateTitle,
//                       style: TextStyle(color: dim, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withValues(alpha: 0.12),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   t('جديد', 'New'),
//                   style: TextStyle(
//                       color: Colors.orange,
//                       fontSize: 11,
//                       fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           // Fields summary
//           Wrap(
//             spacing: 8,
//             runSpacing: 6,
//             children: request.filledFields.entries.take(3).map((entry) {
//               final value = entry.value.toString();
//               if (value.isEmpty) return const SizedBox.shrink();
//               return Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: isDarkMode
//                       ? Colors.white.withValues(alpha: 0.05)
//                       : Colors.black.withValues(alpha: 0.04),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   value.length > 30 ? '${value.substring(0, 30)}...' : value,
//                   style: TextStyle(color: dim, fontSize: 11),
//                 ),
//               );
//             }).toList(),
//           ),
//           const SizedBox(height: 14),
//           // Actions
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onDecline,
//                   style: OutlinedButton.styleFrom(
//                     side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                   ),
//                   child: Text(
//                     t('رفض', 'Decline'),
//                     style: TextStyle(
//                         color: Colors.red, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 flex: 2,
//                 child: ElevatedButton(
//                   onPressed: onRespond,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: gold,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     padding: const EdgeInsets.symmetric(vertical: 10),
//                   ),
//                   child: Text(
//                     t('رد على الطلب', 'Respond'),
//                     style: TextStyle(
//                         color: Colors.black, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Negotiating Card ──────────────────────────────────────────────────────
// class _NegotiatingCard extends StatelessWidget {
//   final CustomOrderRequest request;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onViewDetails;
//   final VoidCallback onCancel;

//   const _NegotiatingCard({
//     required this.request,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onViewDetails,
//     required this.onCancel,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;

//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get border => isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get gold => const Color(0xFFD4A017);

//   @override
//   Widget build(BuildContext context) {
//     final response = request.artisanResponse;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: border),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Text(
//                 isArabic ? request.templateTitleAr : request.templateTitleEn,
//                 style: TextStyle(color: text, fontWeight: FontWeight.bold),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withValues(alpha: 0.12),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   t('بانتظار الزبون', 'Waiting'),
//                   style: TextStyle(
//                       color: Colors.blue,
//                       fontSize: 10,
//                       fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             request.customerName,
//             style: TextStyle(color: dim, fontSize: 13),
//           ),
//           const SizedBox(height: 12),
//           if (response != null)
//             Row(
//               children: [
//                 Icon(Icons.attach_money, size: 14, color: gold),
//                 const SizedBox(width: 4),
//                 Text(
//                   '${response.total.toStringAsFixed(0)} JOD',
//                   style: TextStyle(color: gold, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(width: 16),
//                 Icon(Icons.schedule_outlined, size: 14, color: dim),
//                 const SizedBox(width: 4),
//                 Text(
//                   '${response.deliveryDate.day}/${response.deliveryDate.month}/${response.deliveryDate.year}',
//                   style: TextStyle(color: dim, fontSize: 12),
//                 ),
//                 const SizedBox(width: 16),
//                 Icon(Icons.task_alt_outlined, size: 14, color: dim),
//                 const SizedBox(width: 4),
//                 Text(
//                   '${response.tasks.length} ${t('مهام', 'tasks')}',
//                   style: TextStyle(color: dim, fontSize: 12),
//                 ),
//               ],
//             ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onViewDetails,
//                   style: OutlinedButton.styleFrom(
//                     side: BorderSide(color: border),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                   ),
//                   child: Text(
//                     t('عرض التفاصيل', 'View Details'),
//                     style: TextStyle(color: text, fontSize: 12),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onCancel,
//                   style: OutlinedButton.styleFrom(
//                     side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                   ),
//                   child: Text(
//                     t('إلغاء', 'Cancel'),
//                     style: TextStyle(
//                         color: Colors.red,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Hire / On-Site Card ───────────────────────────────────────────────────
// class _HireOrderCard extends StatelessWidget {
//   final HireRequest request;
//   final bool isArabic;
//   final bool isDarkMode;
//   final bool completed;

//   const _HireOrderCard({
//     required this.request,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.completed,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;
//   Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get gold => const Color(0xFFD4A017);

//   @override
//   Widget build(BuildContext context) {
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white60 : Colors.black54;
//     const gold = Color(0xFFD4A017);
//     final total = request.artisanResponse?.totalPrice ?? 0;
//     final artisanShare = total * 0.90;
//     String date(DateTime value) => '${value.day}/${value.month}/${value.year}';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: completed
//               ? Colors.green.withValues(alpha: 0.35)
//               : gold.withValues(alpha: 0.45),
//           width: 1.4,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 42,
//                 height: 42,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: gold.withValues(alpha: 0.14),
//                 ),
//                 child: const Icon(Icons.handyman_outlined, color: gold),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       request.customerName.isEmpty
//                           ? t('طلب عمل ميداني', 'On-Site Work')
//                           : request.customerName,
//                       style: TextStyle(
//                         color: text,
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       t('عمل ميداني • Hire / On-Site',
//                           'Hire / On-Site • Escrow protected'),
//                       style: const TextStyle(color: gold, fontSize: 10),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color:
//                       (completed ? Colors.green : gold).withValues(alpha: 0.14),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   completed
//                       ? t('مكتمل', 'Completed')
//                       : t('قيد التنفيذ', 'In Progress'),
//                   style: TextStyle(
//                     color: completed ? Colors.green : gold,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             request.jobDescription,
//             maxLines: 3,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(color: text, fontSize: 13, height: 1.45),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.calendar_today_outlined, color: dim, size: 14),
//               const SizedBox(width: 6),
//               Text(
//                 '${date(request.startDate)}  →  ${date(request.endDate)}',
//                 style: TextStyle(color: dim, fontSize: 11),
//               ),
//               const Spacer(),
//               Icon(Icons.schedule, color: dim, size: 14),
//               const SizedBox(width: 4),
//               Text('${request.dailyHours} h/day',
//                   style: TextStyle(color: dim, fontSize: 11)),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Divider(color: text.withValues(alpha: 0.08)),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Text(t('إجمالي الطلب', 'Order total'),
//                   style: TextStyle(color: dim, fontSize: 11)),
//               const Spacer(),
//               Text('${total.toStringAsFixed(2)} JOD',
//                   style: const TextStyle(
//                       color: gold, fontWeight: FontWeight.bold)),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Row(
//             children: [
//               Icon(
//                   completed
//                       ? Icons.account_balance_wallet_outlined
//                       : Icons.lock_outline,
//                   color: completed ? Colors.green : gold,
//                   size: 14),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: Text(
//                   completed
//                       ? t('حصتك متاحة بعد تحرير الضمان',
//                           'Your share is available after escrow release')
//                       : t('حصتك محجوزة بأمان في الضمان',
//                           'Your share is safely held in Escrow'),
//                   style: TextStyle(color: dim, fontSize: 11),
//                 ),
//               ),
//               Text('${artisanShare.toStringAsFixed(2)} JOD',
//                   style: TextStyle(
//                     color: completed ? Colors.green : gold,
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   )),
//             ],
//           ),
//           if (!completed) ...[
//             const SizedBox(height: 14),
//             Row(
//               children: [
//                 Expanded(
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: LinearProgressIndicator(
//                       value: request.progressPercent.clamp(0, 100) / 100,
//                       minHeight: 7,
//                       backgroundColor: gold.withValues(alpha: 0.12),
//                       valueColor: const AlwaysStoppedAnimation<Color>(gold),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Text('${request.progressPercent.clamp(0, 100)}%',
//                     style: const TextStyle(
//                         color: gold, fontWeight: FontWeight.bold)),
//               ],
//             ),
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: () => _showHireProgressDialog(context, request),
//                 icon: const Icon(Icons.update, size: 17),
//                 label: Text(t('تحديث تقدم العمل', 'Update Work Progress')),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: gold,
//                   side: const BorderSide(color: gold),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(11),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Future<void> _showHireProgressDialog(
//       BuildContext context, HireRequest request) async {
//     double selected = request.progressPercent.toDouble();

//     String stageFor(int percent) {
//       if (percent >= 100) return 'awaiting_customer_confirmation';
//       if (percent >= 75) return 'finalizing';
//       if (percent >= 50) return 'work_in_progress';
//       if (percent >= 25) return 'materials_preparation';
//       return 'work_started';
//     }

//     String stageLabel(int percent) {
//       if (percent >= 100) {
//         return t('بانتظار تأكيد الزبون', 'Awaiting customer confirmation');
//       }
//       if (percent >= 75) return t('اللمسات الأخيرة', 'Finalizing work');
//       if (percent >= 50) return t('تنفيذ العمل', 'Work in progress');
//       if (percent >= 25) return t('تجهيز المواد', 'Preparing materials');
//       return t('بدء العمل', 'Work started');
//     }

//     final saved = await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) => StatefulBuilder(
//         builder: (context, setDialogState) {
//           final percent = selected.round();
//           return AlertDialog(
//             backgroundColor: surface,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//             title: Text(
//               t('تحديث تقدم العمل', 'Update Work Progress'),
//               style: TextStyle(color: text, fontWeight: FontWeight.bold),
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(stageLabel(percent),
//                     style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Slider(
//                         value: selected,
//                         min: 0,
//                         max: 100,
//                         divisions: 20,
//                         activeColor: gold,
//                         onChanged: (value) =>
//                             setDialogState(() => selected = value),
//                       ),
//                     ),
//                     Text('$percent%',
//                         style: TextStyle(
//                             color: text, fontWeight: FontWeight.bold)),
//                   ],
//                 ),
//                 if (percent == 100)
//                   Container(
//                     margin: const EdgeInsets.only(top: 8),
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: gold.withValues(alpha: 0.10),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Text(
//                       t(
//                         'سيبقى المبلغ في الضمان حتى تؤكد مرام استلام العمل.',
//                         'The payment stays in Escrow until Maram confirms completion.',
//                       ),
//                       style: TextStyle(color: dim, fontSize: 11),
//                     ),
//                   ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(dialogContext, false),
//                 child: Text(t('إلغاء', 'Cancel')),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(backgroundColor: gold),
//                 onPressed: () => Navigator.pop(dialogContext, true),
//                 child: Text(t('حفظ', 'Save'),
//                     style: const TextStyle(color: Colors.black)),
//               ),
//             ],
//           );
//         },
//       ),
//     );

//     if (saved != true || !context.mounted) return;

//     try {
//       final percent = selected.round();
//       await context.read<HireOrderProvider>().artisanUpdateProgress(
//             id: request.id,
//             progressStage: stageFor(percent),
//             progressPercent: percent,
//           );
//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         backgroundColor: Colors.green,
//         content: Text(percent == 100
//             ? t('تم إرسال طلب تأكيد الإنجاز للزبون',
//                 'Completion confirmation sent to customer')
//             : t('تم تحديث تقدم العمل', 'Work progress updated')),
//       ));
//     } catch (error) {
//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         backgroundColor: Colors.red,
//         content: Text(error.toString()),
//       ));
//     }
//   }
// }

// // ── In Progress Card ──────────────────────────────────────────────────────
// class _InProgressCard extends StatelessWidget {
//   final CustomOrderRequest request;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onUpdateProgress;
//   final VoidCallback onComplete;

//   const _InProgressCard({
//     required this.request,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onUpdateProgress,
//     required this.onComplete,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;

//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get border => isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get gold => const Color(0xFFD4A017);

//   @override
//   Widget build(BuildContext context) {
//     final progressPercent = request.progressPercent.clamp(0, 100);
//     final progressValue = progressPercent / 100.0;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Text(
//                 isArabic ? request.templateTitleAr : request.templateTitleEn,
//                 style: TextStyle(color: text, fontWeight: FontWeight.bold),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: gold.withValues(alpha: 0.15),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   t('قيد التنفيذ', 'In Progress'),
//                   style: TextStyle(
//                       color: gold, fontSize: 10, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             request.customerName,
//             style: TextStyle(color: dim, fontSize: 13),
//           ),
//           const SizedBox(height: 12),
//           // Progress bar
//           Row(
//             children: [
//               Text(t('التقدم', 'Progress'),
//                   style: TextStyle(color: dim, fontSize: 12)),
//               const Spacer(),
//               Text(
//                 '$progressPercent%',
//                 style: TextStyle(
//                     color: gold, fontWeight: FontWeight.bold, fontSize: 13),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(10),
//             child: LinearProgressIndicator(
//               value: progressValue,
//               backgroundColor: gold.withValues(alpha: 0.15),
//               valueColor: AlwaysStoppedAnimation<Color>(gold),
//               minHeight: 8,
//             ),
//           ),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onUpdateProgress,
//                   style: OutlinedButton.styleFrom(
//                     side: BorderSide(color: gold),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                   ),
//                   child: Text(
//                     t('تحديث التقدم', 'Update Progress'),
//                     style: TextStyle(
//                         color: gold, fontSize: 12, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: onComplete,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                   ),
//                   child: Text(
//                     t('إتمام', 'Complete'),
//                     style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Completed Card ────────────────────────────────────────────────────────
// class _CompletedCard extends StatelessWidget {
//   final CustomOrderRequest request;
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onReview;

//   const _CompletedCard({
//     required this.request,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onReview,
//   });

//   String t(String ar, String en) => isArabic ? ar : en;

//   Color get text => isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => isDarkMode ? Colors.white60 : Colors.black54;
//   Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get border => isDarkMode
//       ? Colors.white.withValues(alpha: 0.10)
//       : Colors.black.withValues(alpha: 0.08);
//   Color get gold => const Color(0xFFD4A017);

//   @override
//   Widget build(BuildContext context) {
//     final status = request.status;
//     final isCompleted = status == 'completed';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: border),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 44,
//                 height: 44,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: isCompleted
//                       ? Colors.green.withValues(alpha: 0.12)
//                       : Colors.grey.withValues(alpha: 0.12),
//                 ),
//                 child: Icon(
//                   isCompleted ? Icons.check_circle : Icons.cancel_outlined,
//                   color: isCompleted ? Colors.green : Colors.grey,
//                   size: 24,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       isArabic
//                           ? request.templateTitleAr
//                           : request.templateTitleEn,
//                       style:
//                           TextStyle(color: text, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       request.customerName,
//                       style: TextStyle(color: dim, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: isCompleted
//                       ? Colors.green.withValues(alpha: 0.12)
//                       : Colors.grey.withValues(alpha: 0.12),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   isCompleted
//                       ? t('مكتمل', 'Completed')
//                       : t('ملغي', 'Cancelled'),
//                   style: TextStyle(
//                     color: isCompleted ? Colors.green : Colors.grey,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Divider(color: border),
//           const SizedBox(height: 12),
//           if (isCompleted)
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: onReview,
//                     icon: Icon(Icons.star_rate, size: 18, color: gold),
//                     label: Text(
//                       t('تقييم الزبون', 'Rate Customer'),
//                       style:
//                           TextStyle(color: text, fontWeight: FontWeight.bold),
//                     ),
//                     style: OutlinedButton.styleFrom(
//                       side: BorderSide(color: border),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }
