import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_service.dart';

class AdminDeliveryOperationsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AdminDeliveryOperationsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AdminDeliveryOperationsScreen> createState() =>
      _AdminDeliveryOperationsScreenState();
}

class _AdminDeliveryOperationsScreenState
    extends State<AdminDeliveryOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Styling Tokens ────────────────────────────────────────────────────────
  String t(String ar, String en) => widget.isArabic ? ar : en;
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  // ── Global State ──────────────────────────────────────────────────────────
  bool _isLoading = true;
  Timer? _sosPulseTimer;
  bool _sosPulseState = false;

  // Tab 1: Dashboard Data
  Map<String, dynamic> _dashboardMetrics = {};
  Map<String, dynamic> _earningsSummary = {};
  List<dynamic> _activityFeed = [];

  // Tab 2: Orders Data
  List<dynamic> _ordersList = [];
  String _selectedOrderStatus = 'All';
  final TextEditingController _orderSearchController = TextEditingController();

  // Tab 3: Drivers Data
  List<dynamic> _driversList = [];
  String _selectedDriverStatus = 'All';
  final TextEditingController _driverSearchController = TextEditingController();

  // Tab 4: Issues Data
  Map<String, dynamic> _alertCounts = {};
  List<dynamic> _issuesList = [];
  String _selectedIssueType = 'All';
  String _selectedIssueStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _sosPulseTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _sosPulseState = !_sosPulseState);
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sosPulseTimer?.cancel();
    _orderSearchController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDashboardData(),
      _loadOrdersData(),
      _loadDriversData(),
      _loadIssuesData(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    final stats = await DeliveryService.getAdminDeliveryStats();
    if (stats != null && mounted) {
      setState(() {
        _dashboardMetrics = stats['metrics'] ?? {};
        _earningsSummary = stats['earnings'] ?? {};
        _activityFeed = stats['activityFeed'] ?? [];
      });
    }
  }

  Future<void> _loadOrdersData() async {
    final orders = await DeliveryService.getAdminDeliveryOrders(
      status: _selectedOrderStatus == 'All' ? null : _selectedOrderStatus,
      search: _orderSearchController.text.trim(),
    );
    if (mounted) {
      setState(() => _ordersList = orders);
    }
  }

  Future<void> _loadDriversData() async {
    final drivers = await DeliveryService.getAdminDeliveryDrivers(
      status: _selectedDriverStatus == 'All' ? null : _selectedDriverStatus,
      search: _driverSearchController.text.trim(),
    );
    if (mounted) {
      setState(() => _driversList = drivers);
    }
  }

  Future<void> _loadIssuesData() async {
    final res = await DeliveryService.getAdminDeliveryIssues(
      type: _selectedIssueType == 'All' ? null : _selectedIssueType,
      status: _selectedIssueStatus == 'All' ? null : _selectedIssueStatus,
    );
    if (res != null && mounted) {
      setState(() {
        _alertCounts = res['alertCounts'] ?? {};
        _issuesList = res['issues'] ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosCount = (_alertCounts['sosCount'] as num?)?.toInt() ?? 0;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('إدارة عمليات التوصيل', 'Delivery Operations'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: accent),
              onPressed: _loadAllData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: accent,
            indicatorWeight: 3,
            labelColor: accent,
            unselectedLabelColor: dim,
            labelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(t('الرئيسية', 'Dashboard')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(t('الطلبات', 'Orders')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(t('المندوبين', 'Drivers')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sosCount > 0 && _sosPulseState
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(t('البلاغات', 'Issues')),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildOrdersTab(),
                  _buildDriversTab(),
                  _buildIssuesTab(),
                ],
              ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: 📊 DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDashboardTab() {
    final totalOrders = _dashboardMetrics['totalOrders'] ?? 0;
    final activeOrders = _dashboardMetrics['activeOrders'] ?? 0;
    final completedToday = _dashboardMetrics['completedToday'] ?? 0;
    final avgTime = _dashboardMetrics['avgDeliveryTimeMins'] ?? 24;

    final todayEarnings = _earningsSummary['todayEarnings'] ?? 0.0;
    final weekEarnings = _earningsSummary['weekEarnings'] ?? 0.0;
    final monthEarnings = _earningsSummary['monthEarnings'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Top Stats Grid ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: t('إجمالي الطلبات', 'Total Orders'),
                  value: '$totalOrders',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: t('الطلبات النشطة', 'Active Orders'),
                  value: '$activeOrders',
                  icon: Icons.directions_run,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: t('مكتمل اليوم', 'Completed Today'),
                  value: '$completedToday',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: t('متوسط الوقت', 'Avg Time'),
                  value: '$avgTime min',
                  icon: Icons.timer_outlined,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Earnings Summary Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.15),
                  accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Color(0xFFD4A017), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      t('ملخص الأرباح والمستحقات', 'Earnings Summary'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildEarningItem(t('اليوم', 'Today'),
                        '₪${todayEarnings.toStringAsFixed(0)}'),
                    Container(
                        width: 1,
                        height: 36,
                        color: accent.withValues(alpha: 0.3)),
                    _buildEarningItem(t('هذا الأسبوع', 'This Week'),
                        '₪${weekEarnings.toStringAsFixed(0)}'),
                    Container(
                        width: 1,
                        height: 36,
                        color: accent.withValues(alpha: 0.3)),
                    _buildEarningItem(t('هذا الشهر', 'This Month'),
                        '₪${monthEarnings.toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick Actions ────────────────────────────────────────────────
          Text(
            t('إجراءات سريعة', 'Quick Actions'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _selectedOrderStatus = 'available');
                    _tabController.animateTo(1);
                    _loadOrdersData();
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text(
                    t('تعيين الغير معين', 'Assign Orders'),
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedDriverStatus = 'pending');
                    _tabController.animateTo(2);
                    _loadDriversData();
                  },
                  icon: const Icon(Icons.verified_user_outlined, size: 16),
                  label: Text(
                    t('توثيق المندوبين', 'Pending Verification'),
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Recent Activity Feed ──────────────────────────────────────────
          Text(
            t('آخر النشاطات الحية', 'Recent Activity Feed'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _activityFeed.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    t('لا توجد نشاطات حالياً', 'No recent activity'),
                    style: GoogleFonts.cairo(color: dim, fontSize: 13),
                  ),
                )
              : Column(
                  children: _activityFeed
                      .map((item) => _buildActivityItem(item))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: GoogleFonts.cairo(color: dim, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem(String label, String amount) {
    return Column(
      children: [
        Text(
          amount,
          style: GoogleFonts.cairo(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(color: dim, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildActivityItem(dynamic item) {
    final isIssue = item['type'] == 'sos' ||
        item['type'] == 'fraud' ||
        item['type'] == 'complaint';
    final iconColor = isIssue ? Colors.red : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isIssue ? Icons.warning_amber_rounded : Icons.notifications_none,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isArabic ? (item['textAr'] ?? '') : (item['text'] ?? ''),
              style: GoogleFonts.cairo(color: text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: 🚚 ORDERS MANAGEMENT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildOrdersTab() {
    return Column(
      children: [
        // ── Filter Bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          color: surface,
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _orderSearchController,
                style: GoogleFonts.cairo(color: text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: t(
                    'ابحث برقم الطلب، الزبون، العنوان...',
                    'Search by code, customer, address...',
                  ),
                  hintStyle: GoogleFonts.cairo(color: dim, fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: dim, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: dim, size: 18),
                    onPressed: () {
                      _orderSearchController.clear();
                      _loadOrdersData();
                    },
                  ),
                  filled: true,
                  fillColor: bg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _loadOrdersData(),
              ),
              const SizedBox(height: 10),
              // Status Filters horizontal scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'available',
                    'active',
                    'delivered',
                    'completed',
                    'cancelled'
                  ].map((st) {
                    final isSel =
                        _selectedOrderStatus.toLowerCase() == st.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(
                          _formatStatusLabel(st),
                          style: GoogleFonts.cairo(
                            color: isSel ? Colors.black : text,
                            fontSize: 11,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selectedColor: accent,
                        backgroundColor: bg,
                        onSelected: (_) {
                          setState(() => _selectedOrderStatus = st);
                          _loadOrdersData();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── Orders List ─────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOrdersData,
            color: accent,
            child: _ordersList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: dim),
                        const SizedBox(height: 12),
                        Text(
                          t('لا توجد طلبات مطابقة', 'No matching orders'),
                          style: GoogleFonts.cairo(color: dim, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ordersList.length,
                    itemBuilder: (context, index) {
                      final order = _ordersList[index];
                      return _buildOrderCard(order);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatStatusLabel(String st) {
    switch (st.toLowerCase()) {
      case 'all':
        return t('الكل', 'All');
      case 'available':
        return t('متاح للتوصيل', 'Available');
      case 'active':
        return t('قيد التنفيذ', 'Active');
      case 'delivered':
        return t('تم التسليم', 'Delivered');
      case 'completed':
        return t('مكتمل', 'Completed');
      case 'cancelled':
        return t('ملغي', 'Cancelled');
      default:
        return st;
    }
  }

  Widget _buildOrderCard(dynamic order) {
    final status = (order['status'] ?? 'available').toString();
    final orderCode = (order['orderCode'] ?? 'ORD-0000').toString();
    final driverName =
        order['driver'] != null ? (order['driver']['name']?.toString()) : null;
    final customerName = order['customer'] != null
        ? (order['customer']['name']?.toString() ?? t('زبون', 'Customer'))
        : t('زبون', 'Customer');
    final customerPhone = order['customer'] != null
        ? (order['customer']['phone']?.toString() ?? '')
        : '';
    final pickupAddr = (order['pickupAddress']?.toString() ?? '—');
    final dropoffAddr = (order['dropoffAddress']?.toString() ?? '—');

    Color statusColor = accent;
    if (status == 'completed' || status == 'delivered') {
      statusColor = Colors.green;
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
    } else if (status == 'active') {
      statusColor = Colors.orange;
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$orderCode',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatStatusLabel(status),
                  style: GoogleFonts.cairo(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: dim),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  customerPhone.isNotEmpty
                      ? '$customerName ($customerPhone)'
                      : customerName,
                  style: GoogleFonts.cairo(color: text, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$pickupAddr → $dropoffAddr',
                  style: GoogleFonts.cairo(color: dim, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.two_wheeler, size: 14, color: dim),
                    const SizedBox(width: 4),
                    Text(
                      driverName != null
                          ? '${t("المندوب:", "Driver:")} $driverName'
                          : t('غير معين', 'Unassigned'),
                      style: GoogleFonts.cairo(
                        color: driverName != null ? text : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showAssignDriverModal(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  driverName != null
                      ? t('إعادة تعيين', 'Reassign')
                      : t('تعيين مندوب', 'Assign Driver'),
                  style: GoogleFonts.cairo(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignDriverModal(dynamic order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('تعيين مندوب للطلب', 'Assign Driver to Order'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _driversList.isEmpty
                  ? Text(
                      t('لا يوجد مندوبين حالياً', 'No drivers available'),
                      style: GoogleFonts.cairo(color: dim),
                    )
                  : SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: _driversList.length,
                        itemBuilder: (_, i) {
                          final driver = _driversList[i];
                          final isSuspended = driver['isSuspended'] ?? false;
                          return ListTile(
                            enabled: !isSuspended,
                            leading: CircleAvatar(
                              backgroundColor: accent.withValues(alpha: 0.2),
                              child: Text(
                                (driver['name'] as String? ?? 'D')[0],
                                style: TextStyle(color: accent),
                              ),
                            ),
                            title: Text(
                              driver['name'] ?? '',
                              style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${t("الحمولة الحالية:", "Load:")} ${driver["activeLoadCount"]} | ${t("التقييم:", "Rating:")} ${driver["rating"]} ⭐',
                              style:
                                  GoogleFonts.cairo(color: dim, fontSize: 11),
                            ),
                            trailing: isSuspended
                                ? Text(t('موقوف', 'Suspended'),
                                    style: TextStyle(color: Colors.red))
                                : ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await DeliveryService.assignDriverToOrder(
                                        orderId: order['id'],
                                        driverId: driver['id'],
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(t(
                                                'تم تعيين المندوب بنجاح',
                                                'Driver assigned successfully')),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadOrdersData();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: accent),
                                    child: Text(t('اختيار', 'Select'),
                                        style: TextStyle(color: Colors.black)),
                                  ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: 👨‍✈️ DRIVERS FLEET MANAGEMENT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDriversTab() {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(12),
          color: surface,
          child: Column(
            children: [
              TextField(
                controller: _driverSearchController,
                style: GoogleFonts.cairo(color: text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: t(
                    'ابحث باسم المندوب، البريد، الهاتف...',
                    'Search driver by name, email, phone...',
                  ),
                  hintStyle: GoogleFonts.cairo(color: dim, fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: dim, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: dim, size: 18),
                    onPressed: () {
                      _driverSearchController.clear();
                      _loadDriversData();
                    },
                  ),
                  filled: true,
                  fillColor: bg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _loadDriversData(),
              ),
              const SizedBox(height: 10),
              Row(
                children: ['All', 'active', 'suspended', 'pending'].map((st) {
                  final isSel =
                      _selectedDriverStatus.toLowerCase() == st.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSel,
                      label: Text(
                        _formatDriverStatusLabel(st),
                        style: GoogleFonts.cairo(
                          color: isSel ? Colors.black : text,
                          fontSize: 11,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selectedColor: accent,
                      backgroundColor: bg,
                      onSelected: (_) {
                        setState(() => _selectedDriverStatus = st);
                        _loadDriversData();
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Drivers List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDriversData,
            color: accent,
            child: _driversList.isEmpty
                ? Center(
                    child: Text(
                      t('لا يوجد مندوبين مطابقين', 'No drivers found'),
                      style: GoogleFonts.cairo(color: dim),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _driversList.length,
                    itemBuilder: (context, index) {
                      final driver = _driversList[index];
                      return _buildDriverCard(driver);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDriverStatusLabel(String st) {
    switch (st.toLowerCase()) {
      case 'all':
        return t('الكل', 'All');
      case 'active':
        return t('نشط', 'Active');
      case 'suspended':
        return t('موقوف', 'Suspended');
      case 'pending':
        return t('قيد التوثيق', 'Pending');
      default:
        return st;
    }
  }

  Widget _buildDriverCard(dynamic driver) {
    final isSuspended = (driver['isSuspended'] as bool?) ?? false;
    final isVerified = (driver['isVerified'] as bool?) ?? true;
    final rating = (driver['rating'] ?? 4.9).toString();
    final totalDeliveries = driver['totalDeliveries'] ?? 0;
    final activeLoad = driver['activeLoadCount'] ?? 0;
    final vehicle = driver['vehicle'] as Map<String, dynamic>?;
    final driverName = driver['name']?.toString() ?? '—';
    final driverEmail = driver['email']?.toString() ?? '';
    final driverPhone = driver['phone']?.toString() ?? '';

    // Build vehicle label safely
    String vehicleLabel = t('لا توجد مركبة', 'No vehicle');
    if (vehicle != null) {
      final make = vehicle['make']?.toString() ?? '';
      final model = vehicle['model']?.toString() ?? '';
      final plate = vehicle['licensePlate']?.toString() ?? '';
      if (make.isNotEmpty) {
        vehicleLabel = '$make $model${plate.isNotEmpty ? " ($plate)" : ""}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuspended ? Colors.red.withValues(alpha: 0.5) : border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      [
                        if (driverEmail.isNotEmpty) driverEmail,
                        if (driverPhone.isNotEmpty) driverPhone
                      ].join(' • '),
                      style: GoogleFonts.cairo(color: dim, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuspended
                      ? Colors.red.withValues(alpha: 0.15)
                      : isVerified
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSuspended
                      ? t('موقوف', 'Suspended')
                      : isVerified
                          ? t('موثق', 'Verified')
                          : t('قيد التوثيق', 'Pending'),
                  style: GoogleFonts.cairo(
                    color: isSuspended
                        ? Colors.red
                        : isVerified
                            ? Colors.green
                            : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  vehicleLabel,
                  style: GoogleFonts.cairo(color: dim, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '⭐ $rating | $totalDeliveries ${t("توصيلة", "del")} | $activeLoad ${t("نشط", "active")}',
                style: GoogleFonts.cairo(
                    color: accent, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isVerified)
                ElevatedButton(
                  onPressed: () async {
                    await DeliveryService.verifyDriverAdmin(
                      driverId: driver['id']?.toString() ?? '',
                      status: 'verified',
                    );
                    _loadDriversData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(t('توثيق', 'Verify'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              if (!isVerified) const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await DeliveryService.suspendDriverAdmin(
                    driverId: driver['id']?.toString() ?? '',
                    isSuspended: !isSuspended,
                  );
                  _loadDriversData();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isSuspended ? Colors.green : Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isSuspended
                      ? t('تفعيل حساب', 'Reactivate')
                      : t('إيقاف حساب', 'Suspend'),
                  style: TextStyle(
                    color: isSuspended ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (driverPhone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:$driverPhone')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 4: ⚠️ ISSUES & SOS ALERTS RESOLUTION HUB
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildIssuesTab() {
    final fraudCount = _alertCounts['fraudCount'] ?? 0;
    final sosCount = _alertCounts['sosCount'] ?? 0;
    final complaintCount = _alertCounts['complaintCount'] ?? 0;

    return Column(
      children: [
        // Alert Counters Top Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: surface,
          child: Row(
            children: [
              Expanded(
                child: _buildAlertCard(
                  title: t('نداءات استغاثة', 'SOS Alerts'),
                  count: '$sosCount',
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlertCard(
                  title: t('تنبيهات احتيال', 'Fraud Alerts'),
                  count: '$fraudCount',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlertCard(
                  title: t('شكاوى الزبائن', 'Complaints'),
                  count: '$complaintCount',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),

        // Issues List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadIssuesData,
            color: accent,
            child: _issuesList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.green),
                        const SizedBox(height: 12),
                        Text(
                          t('لا توجد بلاغات نشطة', 'No active issues'),
                          style: GoogleFonts.cairo(color: dim, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _issuesList.length,
                    itemBuilder: (context, index) {
                      final issue = _issuesList[index];
                      return _buildIssueCard(issue);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(color: text, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(dynamic issue) {
    final type = (issue['issueType'] ?? 'complaint').toString().toLowerCase();
    final isSOS = type == 'sos';
    final isFraud = type == 'fraud';
    final driverName =
        issue['driver'] != null ? issue['driver']['name'] : 'Driver';
    final description = issue['description'] ?? '';
    final status = issue['status'] ?? 'new';
    final isResolved = status == 'resolved';

    final Color badgeColor = isSOS
        ? Colors.red
        : isFraud
            ? Colors.orange
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSOS
              ? (_sosPulseState
                  ? Colors.red
                  : Colors.red.withValues(alpha: 0.4))
              : border,
          width: isSOS ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSOS
                      ? Icons.crisis_alert
                      : isFraud
                          ? Icons.psychology_outlined
                          : Icons.report_problem_outlined,
                  color: badgeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$driverName (${type.toUpperCase()})',
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isResolved
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isResolved ? t('تم الحل', 'Resolved') : t('جديد', 'New'),
                  style: GoogleFonts.cairo(
                    color: isResolved ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.cairo(color: text, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (!isResolved)
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _resolveIssueDialog(issue['id']),
                  icon: const Icon(Icons.check, size: 14, color: Colors.white),
                  label: Text(t('معالجة وإغلاق', 'Resolve'),
                      style:
                          GoogleFonts.cairo(color: Colors.white, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await DeliveryService.dismissIssueAdmin(issue['id']);
                    _loadIssuesData();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: dim),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(t('تجاهل', 'Dismiss'),
                      style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _resolveIssueDialog(String issueId) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('حسم البلاغ', 'Resolve Issue'),
            style: GoogleFonts.cairo(color: text)),
        content: TextField(
          controller: notesCtrl,
          style: GoogleFonts.cairo(color: text),
          decoration: InputDecoration(
            hintText: t('ملاحظات الإدارة للحل...', 'Admin resolution notes...'),
            hintStyle: GoogleFonts.cairo(color: dim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DeliveryService.resolveIssueAdmin(
                issueId: issueId,
                notes: notesCtrl.text,
              );
              _loadIssuesData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(t('تأكيد الحل', 'Confirm Resolve'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
