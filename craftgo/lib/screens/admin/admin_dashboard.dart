import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Function(int)? onNavigateTab;

  const AdminDashboard({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.onNavigateTab,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Colors mapping
  Color get backgroundColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get primaryTextColor =>
      widget.isDarkMode ? Colors.white : Colors.black87;

  Color get secondaryTextColor =>
      widget.isDarkMode ? Colors.white70 : Colors.black54;

  Color get cardBorderColor => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  Color get topIconColor => widget.isDarkMode ? Colors.white : Colors.black87;

  Color get topButtonBackground =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color get chipBorderColor =>
      widget.isDarkMode ? Colors.white12 : Colors.black12;

  List<Map<String, dynamic>> verifications = [];
  List<Map<String, dynamic>> _realDisputes = [];
  bool _isLoadingDisputes = true;
  List<Map<String, dynamic>> _pendingExhibitions = [];
  bool _isLoadingExhibitions = true;

  bool _isLoadingVerifications = true;
  String? _verificationError;
  final Set<String> _processingProfiles = <String>{};
  List<Map<String, dynamic>> _paymentTransactions = [];
  Map<String, dynamic> _paymentTotals = {
    'gross': 0,
    'admin': 0,
    'artisan': 0,
    'held': 0,
  };
  Map<String, dynamic> _userCounts = {
    'craftsmen': 0,
    'activeClients': 0,
  };
  bool _isLoadingPayments = true;
  String? _paymentsError;

  @override
  void initState() {
    super.initState();

    _loadPendingArtisans();
    _loadPaymentOverview();
    _loadDisputes();
    _loadPendingExhibitions();
  }

  Future<void> _loadDisputes() async {
    if (mounted) setState(() => _isLoadingDisputes = true);
    try {
      final response = await ApiService.get('/admin/disputes');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawList = decoded['disputes'];
        if (rawList is List) {
          setState(() {
            _realDisputes = rawList
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Admin disputes fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDisputes = false);
    }
  }

  Future<void> _loadPendingExhibitions() async {
    if (mounted) setState(() => _isLoadingExhibitions = true);
    try {
      final response = await ApiService.get('/admin/exhibitions');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final rawList = jsonDecode(response.body);
        if (rawList is List) {
          final items = rawList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) {
            final status = (item['status'] ?? '').toString().toLowerCase();
            final verified = item['verified'] == true;
            return status == 'pending' || !verified;
          }).toList();
          setState(() {
            _pendingExhibitions = items;
          });
        }
      }
    } catch (e) {
      debugPrint('Admin pending exhibitions fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingExhibitions = false);
    }
  }

  Future<void> _reviewExhibition(String id, bool approve) async {
    final action = approve ? 'approve' : 'reject';
    try {
      final response = await ApiService.post('/admin/exhibitions/$id/$action');
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? (widget.isArabic
                    ? 'تم قبول المعرض بنجاح'
                    : 'Exhibition approved successfully')
                : (widget.isArabic ? 'تم رفض المعرض' : 'Exhibition rejected')),
            backgroundColor: approve ? Colors.green : Colors.redAccent,
          ),
        );
        _loadPendingExhibitions();
      }
    } catch (e) {
      debugPrint('Review exhibition error: $e');
    }
  }

  Future<void> _loadPaymentOverview() async {
    if (mounted) {
      setState(() {
        _isLoadingPayments = true;
        _paymentsError = null;
      });
    }

    try {
      final response = await ApiService.get('/payments/admin/transactions');
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && decoded is Map) {
        final rawTransactions = decoded['transactions'];
        final rawTotals = decoded['totals'];
        final rawUserCounts = decoded['userCounts'];
        setState(() {
          _paymentTransactions = rawTransactions is List
              ? rawTransactions
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : <Map<String, dynamic>>[];
          _paymentTotals = rawTotals is Map
              ? Map<String, dynamic>.from(rawTotals)
              : <String, dynamic>{};
          _userCounts = rawUserCounts is Map
              ? Map<String, dynamic>.from(rawUserCounts)
              : <String, dynamic>{'craftsmen': 0, 'activeClients': 0};
        });
      } else {
        setState(() {
          _paymentsError = widget.isArabic
              ? 'تعذر تحميل المعاملات المالية.'
              : 'Could not load payment transactions.';
        });
      }
    } catch (error) {
      debugPrint('Admin payments error: $error');
      if (!mounted) return;
      setState(() {
        _paymentsError = widget.isArabic
            ? 'تعذر الاتصال بالخادم.'
            : 'Could not connect to the payment service.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  double _amount(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(dynamic value) => '${_amount(value).toStringAsFixed(2)} JOD';

  Future<void> _loadPendingArtisans() async {
    if (mounted) {
      setState(() {
        _isLoadingVerifications = true;
        _verificationError = null;
      });
    }

    try {
      final response = await ApiService.get('/admin/pending-artisans');
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final rawList = body['data'];
        setState(() {
          verifications = rawList is List
              ? rawList
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : <Map<String, dynamic>>[];
        });
      } else {
        setState(() {
          _verificationError = (body['error'] ??
                  (widget.isArabic
                      ? 'تعذر تحميل طلبات الحرفيين.'
                      : 'Could not load artisan requests.'))
              .toString();
        });
      }
    } catch (error) {
      debugPrint('Pending artisans error: $error');

      if (!mounted) return;
      setState(() {
        _verificationError = widget.isArabic
            ? 'تعذر الاتصال بالخادم. تأكدي من تشغيل الباك إند.'
            : 'Could not connect to the server. Make sure the backend is running.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingVerifications = false);
      }
    }
  }

  Future<void> _reviewArtisan({
    required Map<String, dynamic> artisan,
    required String action,
  }) async {
    final profileId = (artisan['artisanProfileId'] ?? '').toString();

    if (profileId.isEmpty || _processingProfiles.contains(profileId)) {
      return;
    }

    setState(() => _processingProfiles.add(profileId));

    try {
      final response = await ApiService.patch(
        '/admin/artisans/$profileId/review',
        body: {'action': action},
      );

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        setState(() {
          verifications.removeWhere(
            (item) => (item['artisanProfileId'] ?? '').toString() == profileId,
          );
        });

        final approved = action == 'approve';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? (widget.isArabic
                      ? 'تمت الموافقة على حساب الحرفي بنجاح.'
                      : 'Artisan account approved successfully.')
                  : (widget.isArabic
                      ? 'تم رفض طلب الحرفي.'
                      : 'Artisan request rejected.'),
            ),
            backgroundColor: approved ? Colors.green : Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (body['error'] ??
                      (widget.isArabic
                          ? 'تعذر تنفيذ العملية.'
                          : 'Could not complete the action.'))
                  .toString(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      debugPrint('Review artisan error: $error');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic
                ? 'تعذر الاتصال بالخادم.'
                : 'Could not connect to the server.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingProfiles.remove(profileId));
      }
    }
  }

  String _formatRegisteredDate(dynamic value) {
    if (value == null) {
      return widget.isArabic ? 'تاريخ غير متوفر' : 'Date unavailable';
    }

    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) {
      return widget.isArabic ? 'تاريخ غير متوفر' : 'Date unavailable';
    }

    final now = DateTime.now();
    final difference = now.difference(parsed);

    if (difference.inDays == 0) {
      return widget.isArabic ? 'اليوم' : 'Today';
    }
    if (difference.inDays == 1) {
      return widget.isArabic ? 'أمس' : 'Yesterday';
    }
    if (difference.inDays < 7) {
      return widget.isArabic
          ? 'قبل ${difference.inDays} أيام'
          : '${difference.inDays} days ago';
    }

    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final direction = widget.isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          Widget buildEscrowSection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.isArabic
                            ? 'أحدث معاملات الضمان'
                            : 'Recent Escrow Transactions',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.arefRuqaa(
                          color: primaryTextColor,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadPaymentOverview,
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFFD4A017),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (_isLoadingPayments)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4A017),
                      ),
                    ),
                  )
                else if (_paymentsError != null)
                  _buildPaymentsMessage(_paymentsError!, isError: true)
                else if (_paymentTransactions.isEmpty)
                  _buildPaymentsMessage(
                    widget.isArabic
                        ? 'لا توجد معاملات مالية حتى الآن.'
                        : 'No payment transactions yet.',
                  )
                else
                  ..._paymentTransactions
                      .take(5)
                      .map(_buildPaymentTransactionCard),
              ],
            );
          }

          Widget buildVerificationsSection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isArabic
                          ? "طلبات تفعيل حسابات الحرفيين"
                          : "Pending Artisan Accounts",
                      style: GoogleFonts.arefRuqaa(
                        color: primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A017).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${verifications.length}",
                        style: const TextStyle(
                          color: Color(0xFFD4A017),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (_isLoadingVerifications)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4A017),
                      ),
                    ),
                  )
                else if (_verificationError != null)
                  _buildVerificationErrorCard()
                else if (verifications.isEmpty)
                  _buildEmptyVerificationCard()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: verifications.length,
                    itemBuilder: (context, index) {
                      final item = verifications[index];
                      return _buildVerifyCard(
                        artisan: item,
                      );
                    },
                  ),
              ],
            );
          }

          Widget buildExhibitionsSection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isArabic
                          ? "معارض بانتظار الموافقة"
                          : "Pending Exhibitions",
                      style: GoogleFonts.arefRuqaa(
                        color: primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_pendingExhibitions.length}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (_isLoadingExhibitions)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          CircularProgressIndicator(color: Color(0xFFD4A017)),
                    ),
                  )
                else if (_pendingExhibitions.isEmpty)
                  _buildPaymentsMessage(
                    widget.isArabic
                        ? 'لا توجد معارض بانتظار الموافقة حالياً.'
                        : 'No pending exhibitions requiring approval.',
                  )
                else
                  ..._pendingExhibitions.map(_buildExhibitionApprovalCard),
              ],
            );
          }

          Widget buildDisputesSection() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isArabic
                          ? "نزاعات تجارية معلقة"
                          : "Ongoing Trade Disputes",
                      style: GoogleFonts.arefRuqaa(
                        color: primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_realDisputes.length}",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (_isLoadingDisputes)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          CircularProgressIndicator(color: Color(0xFFD4A017)),
                    ),
                  )
                else if (_realDisputes.isEmpty)
                  _buildPaymentsMessage(
                    widget.isArabic
                        ? 'لا توجد نزاعات معلقة حالياً.'
                        : 'No active trade disputes.',
                  )
                else
                  ..._realDisputes.map(_buildDisputeCard),
              ],
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 24,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header title
                  Text(
                    widget.isArabic
                        ? "لوحة الإشراف العام"
                        : "Admin Overview Dashboard",
                    style: GoogleFonts.arefRuqaa(
                      color: primaryTextColor,
                      fontSize: isDesktop ? 30 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isArabic
                        ? "إدارة الطلبات والنزاعات وتوثيق الحسابات"
                        : "Manage orders, disputes, and verifications",
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Analytics Stats Grid (4 columns on desktop, 2 on mobile)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isDesktop ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 1.6 : 1.4,
                    children: [
                      _buildStatCard(
                        title: widget.isArabic
                            ? "ودائع الضمان"
                            : "Escrow Deposits",
                        value: _isLoadingPayments
                            ? '...'
                            : _money(_paymentTotals['held']),
                        icon: Icons.lock_clock_outlined,
                      ),
                      _buildStatCard(
                        title: widget.isArabic
                            ? "عمولة النظام"
                            : "Platform Income",
                        value: _isLoadingPayments
                            ? '...'
                            : _money(_paymentTotals['admin']),
                        icon: Icons.account_balance_outlined,
                      ),
                      _buildStatCard(
                        title: widget.isArabic
                            ? "حسابات الحرفيين"
                            : "Craftsmen count",
                        value: _isLoadingPayments
                            ? '...'
                            : '${_userCounts['craftsmen'] ?? 0}',
                        icon: Icons.engineering_outlined,
                      ),
                      _buildStatCard(
                        title: widget.isArabic
                            ? "الزبائن النشطين"
                            : "Active Clients",
                        value: _isLoadingPayments
                            ? '...'
                            : '${_userCounts['activeClients'] ?? 0}',
                        icon: Icons.people_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildEscrowSection(),
                              const SizedBox(height: 35),
                              buildVerificationsSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right Column
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildExhibitionsSection(),
                              const SizedBox(height: 35),
                              buildDisputesSection(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    buildEscrowSection(),
                    const SizedBox(height: 35),
                    buildVerificationsSection(),
                    const SizedBox(height: 35),
                    buildExhibitionsSection(),
                    const SizedBox(height: 35),
                    buildDisputesSection(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorderColor, width: 1.5),
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFD4A017), size: 24),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsMessage(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (isError ? Colors.redAccent : const Color(0xFFD4A017))
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isError ? Colors.redAccent : cardBorderColor)
              .withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: primaryTextColor),
      ),
    );
  }

  Widget _buildPaymentTransactionCard(Map<String, dynamic> transaction) {
    final customer = transaction['customer'] is Map
        ? Map<String, dynamic>.from(transaction['customer'])
        : <String, dynamic>{};
    final artisan = transaction['artisan'] is Map
        ? Map<String, dynamic>.from(transaction['artisan'])
        : <String, dynamic>{};
    final escrowStatus = (transaction['escrowStatus'] ?? 'unpaid').toString();
    final released = escrowStatus == 'released';
    final held = escrowStatus == 'held';
    final statusColor = released
        ? Colors.green
        : held
            ? const Color(0xFFD4A017)
            : Colors.grey;
    final statusLabel = released
        ? (widget.isArabic ? 'تم التحرير' : 'Released')
        : held
            ? (widget.isArabic ? 'محجوز' : 'Held')
            : escrowStatus;
    final isReadyMade = transaction['transactionType'] == 'ready_made';
    final id = (isReadyMade
            ? transaction['orderId']
            : transaction['hireRequestId'] ?? transaction['id'])
        .toString();
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final product = transaction['product'] is Map
        ? Map<String, dynamic>.from(transaction['product'])
        : <String, dynamic>{};
    final productName =
        (product['titleEn'] ?? product['titleAr'] ?? 'Ready-Made Product')
            .toString();
    final transactionTitle = isReadyMade
        ? '${widget.isArabic ? 'منتج' : 'Product'} #$shortId'
        : '${widget.isArabic ? 'عمل موقعي' : 'Hire'} #$shortId';
    final paymentStatus =
        (transaction['paymentStatus'] ?? 'created').toString();
    final commissionRate = transaction['adminCommissionRate'] ?? 10;
    final createdAt = (transaction['createdAt'] ?? '').toString();
    final stripeReference = (transaction['stripePaymentIntentId'] ??
            transaction['stripeCheckoutSessionId'] ??
            '')
        .toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFD4A017),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  transactionTitle,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${customer['name'] ?? '—'}  →  ${artisan['name'] ?? '—'}',
            style: TextStyle(color: secondaryTextColor, fontSize: 13),
          ),
          if (isReadyMade) ...[
            const SizedBox(height: 6),
            Text(
              productName,
              style: const TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          _paymentRow(
            widget.isArabic ? 'إجمالي الطلب' : 'Order total',
            _money(transaction['grossAmount']),
          ),
          _paymentRow(
            widget.isArabic ? 'حصة الحرفي' : 'Artisan share',
            _money(transaction['artisanAmount']),
          ),
          _paymentRow(
            '${widget.isArabic ? 'عمولة CraftGo' : 'CraftGo commission'} ($commissionRate%)',
            _money(transaction['adminCommission']),
            highlight: true,
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12),
          _paymentRow(
            widget.isArabic ? 'حالة الدفع' : 'Payment status',
            paymentStatus,
          ),
          if (createdAt.isNotEmpty)
            _paymentRow(
              widget.isArabic ? 'تاريخ المعاملة' : 'Transaction date',
              createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
            ),
          if (stripeReference.isNotEmpty)
            _paymentRow(
              widget.isArabic ? 'مرجع Stripe' : 'Stripe reference',
              stripeReference.length > 14
                  ? '${stripeReference.substring(0, 14)}…'
                  : stripeReference,
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: secondaryTextColor, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFD4A017) : primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
        color: Colors.redAccent.withValues(alpha: 0.07),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.redAccent,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            _verificationError ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadPendingArtisans,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              widget.isArabic ? 'إعادة المحاولة' : 'Try Again',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVerificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFFD4A017),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            widget.isArabic
                ? 'لا توجد حسابات حرفيين بانتظار الموافقة.'
                : 'No artisan accounts are waiting for approval.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadPendingArtisans,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(widget.isArabic ? 'تحديث' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyCard({
    required Map<String, dynamic> artisan,
  }) {
    final profileId = (artisan['artisanProfileId'] ?? '').toString();
    final name = (artisan['name'] ??
            (widget.isArabic ? 'حرفي بدون اسم' : 'Unnamed artisan'))
        .toString();
    final craft = (artisan['category'] ??
            artisan['primaryCategory'] ??
            (widget.isArabic ? 'الحرفة غير محددة' : 'Craft not specified'))
        .toString();
    final city = (artisan['city'] ?? '').toString();
    final email = (artisan['email'] ?? '').toString();
    final date = _formatRegisteredDate(artisan['registeredAt']);
    final isProcessing = _processingProfiles.contains(profileId);

    return GestureDetector(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(2);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorderColor, width: 1.5),
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFD4A017).withValues(alpha: 0.12),
                          border: Border.all(
                            color:
                                const Color(0xFFD4A017).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Color(0xFFD4A017),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              craft,
                              style: const TextStyle(
                                color: Color(0xFFD4A017),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (city.isNotEmpty || email.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                [
                                  if (city.isNotEmpty) city,
                                  if (email.isNotEmpty) email,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: TextStyle(
                                color:
                                    secondaryTextColor.withValues(alpha: 0.65),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _reviewArtisan(
                                    artisan: artisan,
                                    action: 'reject',
                                  ),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            widget.isArabic ? 'رفض' : 'Reject',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _reviewArtisan(
                                    artisan: artisan,
                                    action: 'approve',
                                  ),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.black,
                                ),
                          label: Text(
                            widget.isArabic ? 'موافقة' : 'Approve',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A017),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    final reporterName =
        dispute['reporter']?['name'] ?? (widget.isArabic ? 'زبون' : 'Client');
    final reportedName = dispute['reportedUser']?['name'] ??
        (widget.isArabic ? 'حرفي' : 'Craftsman');
    final category = (dispute['issueCategory'] ??
            (widget.isArabic ? 'نزاع تجاري' : 'Trade Dispute'))
        .toString();
    final description = (dispute['description'] ?? '').toString();

    double amountVal = 0.0;
    if (dispute['payment'] != null && dispute['payment']['amount'] != null) {
      amountVal =
          double.tryParse(dispute['payment']['amount'].toString()) ?? 0.0;
    } else if (dispute['contract'] != null &&
        dispute['contract']['budget'] != null) {
      amountVal =
          double.tryParse(dispute['contract']['budget'].toString()) ?? 0.0;
    }

    final partiesStr = '$reporterName vs $reportedName';
    final amountStr =
        amountVal > 0 ? '${amountVal.toStringAsFixed(2)} JOD' : '—';

    return GestureDetector(
      onTap: () {
        if (widget.onNavigateTab != null) widget.onNavigateTab!(5);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorderColor, width: 1.5),
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          partiesStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        amountStr,
                        style: const TextStyle(
                          color: Color(0xFFD4A017),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, thickness: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isArabic
                            ? "بانتظار تدخلك لحل النزاع"
                            : "Awaiting your intervention",
                        style: TextStyle(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            widget.isArabic
                                ? "مراجعة التفاصيل"
                                : "Review Details",
                            style: const TextStyle(
                              color: Color(0xFFD4A017),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFFD4A017),
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExhibitionApprovalCard(Map<String, dynamic> exhibition) {
    final id = (exhibition['id'] ?? '').toString();
    final title = (exhibition['title'] ??
            exhibition['name'] ??
            (widget.isArabic ? 'معرض بدون عنوان' : 'Untitled Exhibition'))
        .toString();
    final ownerName = (exhibition['Owner']?['name'] ??
            exhibition['ownerName'] ??
            (widget.isArabic ? 'صاحب المعرض' : 'Exhibition Owner'))
        .toString();
    final aiScore = exhibition['aiAnalysisScore'] ?? 85;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      '${widget.isArabic ? "مقدم من:" : "By:"} $ownerName',
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AI Analysis Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.purpleAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.isArabic
                          ? "تحليل الذكاء الاصطناعي (ثقة $aiScore%)"
                          : "AI Analysis ($aiScore% Trust)",
                      style: GoogleFonts.cairo(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.isArabic
                            ? "تم التحقق من بيانات المعرض وصاحب العمل."
                            : "Exhibition parameters & owner verified.",
                        style: GoogleFonts.cairo(
                            color: primaryTextColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reviewExhibition(id, false),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.redAccent),
                  label: Text(widget.isArabic ? "رفض" : "Reject",
                      style: const TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _reviewExhibition(id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A017),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(widget.isArabic ? "قبول" : "Approve",
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
