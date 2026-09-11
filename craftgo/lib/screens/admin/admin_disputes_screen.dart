import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dispute_service.dart';
import '../customer/artisan_profile_page.dart';
import '../customer/customer_public_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminDisputesScreen — لوحة إدارة وحسم النزاعات للإدارة
// ─────────────────────────────────────────────────────────────────────────────

class AdminDisputesScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AdminDisputesScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  List<Map<String, dynamic>> _disputes = [];
  Map<String, dynamic>? _selectedDispute;
  bool _isLoading = true;
  bool _isResolving = false;
  String? _errorMessage;

  // Track suspended user IDs locally for admin toggle feedback
  final Set<String> _suspendedUserIds = {};

  // Filter state: 'pending', 'resolved', 'all'
  String _selectedFilter = 'pending';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Admin notes input
  final TextEditingController _adminNotesController = TextEditingController();

  // Theme Colors
  Color get bgColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accentColor =>
      widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get textColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get subTextColor => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get borderColor => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadDisputes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? statusParam = _selectedFilter == 'pending'
          ? 'pending'
          : (_selectedFilter == 'resolved' ? 'resolved_refunded' : null);

      final data = await DisputeService.getAdminDisputes(status: statusParam);
      final List<dynamic> list = data['disputes'] as List<dynamic>? ?? [];

      final formatted =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _disputes = formatted;
          _isLoading = false;

          // Keep selection if still present in list, otherwise select first or null
          if (_selectedDispute != null) {
            final found = _disputes.firstWhere(
              (d) => d['id']?.toString() == _selectedDispute!['id']?.toString(),
              orElse: () => _disputes.isNotEmpty ? _disputes.first : {},
            );
            _selectedDispute = found.isNotEmpty ? found : null;
          } else if (_disputes.isNotEmpty) {
            _selectedDispute = _disputes.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _resolveDispute(String resolutionType) async {
    if (_selectedDispute == null || _isResolving) return;

    final disputeId = _selectedDispute!['id']?.toString();
    if (disputeId == null) return;

    final adminNotes = _adminNotesController.text.trim();

    setState(() => _isResolving = true);

    try {
      await DisputeService.resolveDispute(
        disputeId: disputeId,
        resolutionType: resolutionType,
        adminNotes: adminNotes.isNotEmpty ? adminNotes : null,
      );

      if (!mounted) return;

      setState(() {
        _isResolving = false;
        _adminNotesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolutionType == 'customer_refund'
                ? t('تم استرداد المبلغ للزبون وإغلاق النزاع بنجاح',
                    'Refund processed for customer successfully')
                : resolutionType == 'artisan_release'
                    ? t('تم تحرير المبلغ للحرفي وإغلاق النزاع بنجاح',
                        'Payment released to artisan successfully')
                    : t('تم إغلاق البلاغ بنجاح',
                        'Dispute dismissed successfully'),
          ),
          backgroundColor: resolutionType == 'customer_refund'
              ? Colors.redAccent
              : resolutionType == 'artisan_release'
                  ? Colors.green
                  : Colors.grey,
        ),
      );

      await _loadDisputes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تنفيذ القرار: $e', 'Action failed: $e')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredDisputes {
    if (_searchQuery.isEmpty) return _disputes;
    final q = _searchQuery.toLowerCase();
    return _disputes.where((d) {
      final id = (d['id'] ?? '').toString().toLowerCase();
      final cat = (d['issueCategory'] ?? '').toString().toLowerCase();
      final desc = (d['description'] ?? '').toString().toLowerCase();
      final reporterName =
          (d['reporter']?['name'] ?? '').toString().toLowerCase();
      final reportedName =
          (d['reportedUser']?['name'] ?? '').toString().toLowerCase();
      return id.contains(q) ||
          cat.contains(q) ||
          desc.contains(q) ||
          reporterName.contains(q) ||
          reportedName.contains(q);
    }).toList();
  }

  // ── Helper getters for dispute object ─────────────────────────────────────
  String _getContractTitle(Map<String, dynamic> dispute) {
    final contract = dispute['contract'] as Map<String, dynamic>?;
    if (contract != null) {
      if (contract['templateTitleAr'] != null ||
          contract['templateTitleEn'] != null) {
        return widget.isArabic
            ? (contract['templateTitleAr'] ?? contract['templateTitleEn'] ?? '')
            : (contract['templateTitleEn'] ??
                contract['templateTitleAr'] ??
                '');
      }
      if (contract['jobDescription'] != null) {
        return contract['jobDescription'].toString();
      }
      final name = widget.isArabic
          ? (contract['nameAr'] ??
              contract['productName'] ??
              contract['titleAr'])
          : (contract['nameEn'] ??
              contract['productName'] ??
              contract['titleEn']);
      if (name != null && name.toString().isNotEmpty) return name.toString();
    }
    final shortId = (dispute['id']?.toString() ?? 'XXXX').substring(0, 8);
    return widget.isArabic ? 'طلب رقم #$shortId' : 'Order #$shortId';
  }

  String _getContractType(Map<String, dynamic> dispute) {
    if (dispute['customOrderRequestId'] != null) {
      return widget.isArabic ? 'طلب مخصص' : 'Custom Order';
    } else if (dispute['hireRequestId'] != null) {
      return widget.isArabic ? 'عمل في الموقع' : 'On-Site Work';
    } else if (dispute['orderId'] != null) {
      return widget.isArabic ? 'منتج جاهز' : 'Ready-Made';
    }
    return widget.isArabic ? 'نزاع عام' : 'General Dispute';
  }

  double _getEscrowAmount(Map<String, dynamic> dispute) {
    final payment = dispute['payment'] as Map<String, dynamic>?;
    if (payment != null && payment['amount'] != null) {
      return (payment['amount'] as num).toDouble();
    }
    final contract = dispute['contract'] as Map<String, dynamic>?;
    if (contract != null) {
      final amt = contract['totalAmount'] ??
          contract['price'] ??
          contract['artisanResponse']?['totalPrice'];
      if (amt is num) return amt.toDouble();
    }
    return 0.0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'resolved_refunded':
        return Colors.redAccent;
      case 'resolved_released':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return t('قيد الانتظار', 'Pending');
      case 'under_review':
        return t('قيد المراجعة', 'Under Review');
      case 'resolved_refunded':
        return t('تم الاسترداد', 'Refunded');
      case 'resolved_released':
        return t('تم التحرير', 'Released');
      case 'dismissed':
        return t('تم الرفض', 'Dismissed');
      default:
        return status;
    }
  }

  String _formatDate(dynamic input) {
    if (input == null) return '';
    try {
      final dt = DateTime.parse(input.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return input.toString();
    }
  }

  // ── Open User Admin Management Modal ──────────────────────────────────────
  void _showUserAdminModal(
      BuildContext context, Map<String, dynamic> user, String roleType) {
    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? t('مستخدم', 'User');
    final email = user['email']?.toString() ?? '—';
    final phone = user['phone']?.toString() ?? '—';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentlySuspended = _suspendedUserIds.contains(userId);

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // User Header Card
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: accentColor.withValues(alpha: 0.2),
                      child: Icon(
                        roleType == 'artisan' ? Icons.handyman : Icons.person,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: currentlySuspended
                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentlySuspended
                                      ? t('محظور / معلق', 'Suspended')
                                      : t('نشط', 'Active'),
                                  style: TextStyle(
                                    color: currentlySuspended
                                        ? Colors.redAccent
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${t('النوع:', 'Role:')} ${roleType == 'artisan' ? t('حرفي / صانع', 'Artisan Craftsman') : t('عميل / زبون', 'Customer Client')}',
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Details Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _infoRowModal(
                          Icons.phone, t('رقم الهاتف:', 'Phone:'), phone),
                      const SizedBox(height: 6),
                      _infoRowModal(Icons.email,
                          t('البريد الإلكتروني:', 'Email:'), email),
                      const SizedBox(height: 6),
                      _infoRowModal(
                          Icons.badge, t('معرف المستخدم:', 'User ID:'), userId),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  t('إجراءات وعناصر تحكم الإدارة:',
                      'Admin Management Controls:'),
                  style: GoogleFonts.cairo(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 12),

                // Action 1: View Profile Page
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (roleType == 'artisan') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtisanProfilePage(
                              artisan: user,
                              isArabic: widget.isArabic,
                              isDarkMode: widget.isDarkMode,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerPublicProfile(
                              customerId: userId,
                              isArabic: widget.isArabic,
                              isDarkMode: widget.isDarkMode,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(t('معاينة الملف الشخصي الكامل',
                        'View Full Public Profile')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action 2: Toggle Ban / Suspend Account
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setModalState(() {
                        if (currentlySuspended) {
                          _suspendedUserIds.remove(userId);
                        } else {
                          _suspendedUserIds.add(userId);
                        }
                      });
                      setState(() {}); // refresh main UI status badges

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            currentlySuspended
                                ? t('تم إلغاء حظر المستخدم بنجاح',
                                    'User account unblocked successfully')
                                : t('تم حظر وتجميد حساب المستخدم بواسطة الإدارة',
                                    'User account suspended by Admin'),
                          ),
                          backgroundColor: currentlySuspended
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                      );
                    },
                    icon: Icon(
                        currentlySuspended ? Icons.lock_open : Icons.block,
                        size: 18),
                    label: Text(
                      currentlySuspended
                          ? t('إلغاء حظر وتفعيل الحساب',
                              'Unblock & Activate Account')
                          : t('حظر وتجميد حساب المستخدم',
                              'Suspend / Ban User Account'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          currentlySuspended ? Colors.green : Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Open Full Contract & Order Inspector Modal ────────────────────────────
  void _showContractDetailsModal(
      BuildContext context, Map<String, dynamic> dispute) {
    final contract = dispute['contract'] as Map<String, dynamic>? ?? {};
    final title = _getContractTitle(dispute);
    final typeLabel = _getContractType(dispute);
    final escrowAmt = _getEscrowAmount(dispute);
    final contractId =
        contract['id']?.toString() ?? dispute['id']?.toString() ?? '—';
    final shippingAddress = contract['shippingAddress'] ??
        contract['pickupAddress'] ??
        contract['deliveryAddress'] ??
        '—';
    final customerPhone =
        contract['customerPhone'] ?? dispute['reporter']?['phone'] ?? '—';

    final specs = contract['customSpecifications'] ?? contract['filledFields'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(typeLabel,
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    Text(title,
                        style: GoogleFonts.cairo(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('₪${escrowAmt.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRowModal(Icons.numbers,
                        t('معرف العقد:', 'Contract ID:'), contractId),
                    const SizedBox(height: 8),
                    _infoRowModal(Icons.location_on_outlined,
                        t('عنوان التوصيل:', 'Address:'), shippingAddress),
                    const SizedBox(height: 8),
                    _infoRowModal(Icons.phone_outlined,
                        t('هاتف الاتصال:', 'Contact Phone:'), customerPhone),
                    const SizedBox(height: 12),
                    if (specs != null) ...[
                      Text(
                          t('المواصفات والتفاصيل المخصصة:',
                              'Custom Specifications:'),
                          style: GoogleFonts.cairo(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(specs.toString(),
                            style: TextStyle(color: textColor, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                        t('تفاصيل الضمان المالي:',
                            'Financial Escrow Breakdown:'),
                        style: GoogleFonts.cairo(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _infoRowModal(
                              Icons.account_balance_wallet,
                              t('إجمالي الضمان:', 'Total Escrow:'),
                              '₪${escrowAmt.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          _infoRowModal(
                              Icons.verified_user,
                              t('حالة الضمان:', 'Escrow Status:'),
                              dispute['payment']?['escrowStatus']?.toString() ??
                                  'held'),
                        ],
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

  Widget _infoRowModal(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
          child: isMobile
              ? (_selectedDispute == null
                  ? _buildMasterPane(isMobile)
                  : _buildDetailPane(isMobile))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: _buildMasterPane(isMobile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailPane(isMobile),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MASTER PANE (List & Filters)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMasterPane(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Refresh
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      t('إدارة النزاعات', 'Disputes & Claims'),
                      style: GoogleFonts.cairo(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: accentColor, size: 20),
                  onPressed: _loadDisputes,
                  tooltip: t('تحديث', 'Refresh'),
                ),
              ],
            ),
          ),

          // Status Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('pending', t('معلقة', 'Pending')),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', t('منتهية', 'Resolved')),
                const SizedBox(width: 8),
                _buildFilterChip('all', t('الكل', 'All')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    t('بحث برقم النزاع أو الاسم...', 'Search ID or name...'),
                hintStyle: TextStyle(color: subTextColor, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: subTextColor),
                filled: true,
                fillColor: bgColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 1),

          // List View Body
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 36, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadDisputes,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor),
                              child: Text(t('إعادة المحاولة', 'Retry'),
                                  style: const TextStyle(
                                      color: Colors.black, fontSize: 12)),
                            ),
                          ],
                        ),
                      )
                    : _filteredDisputes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 48,
                                    color: subTextColor.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  t('لا توجد نزاعات في هذا القسم',
                                      'No disputes found'),
                                  style: GoogleFonts.cairo(
                                      color: subTextColor, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredDisputes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _filteredDisputes[index];
                              final isSelected =
                                  _selectedDispute?['id']?.toString() ==
                                      item['id']?.toString();
                              final status =
                                  item['adminStatus']?.toString() ?? 'pending';
                              final statusColor = _getStatusColor(status);
                              final escrowAmt = _getEscrowAmount(item);
                              final title = _getContractTitle(item);
                              final categoryLabel =
                                  DisputeService.issueCategoryLabel(
                                item['issueCategory']?.toString() ?? 'other',
                                arabic: widget.isArabic,
                              );
                              final reporter =
                                  item['reporter'] as Map<String, dynamic>? ??
                                      {};
                              final reported = item['reportedUser']
                                      as Map<String, dynamic>? ??
                                  {};
                              final reporterName =
                                  reporter['name'] ?? t('مجهول', 'Unknown');
                              final reportedName =
                                  reported['name'] ?? t('مجهول', 'Unknown');
                              final shortId = (item['id']?.toString() ?? '')
                                  .substring(0, 8);

                              return InkWell(
                                onTap: () {
                                  setState(() => _selectedDispute = item);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentColor.withValues(alpha: 0.12)
                                        : bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor
                                          : borderColor,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top row: ID + Status badge
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'DSP-#$shortId',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getStatusLabel(status),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Title (Clickable for Contract Inspector)
                                      InkWell(
                                        onTap: () => _showContractDetailsModal(
                                            context, item),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.open_in_new,
                                                size: 14, color: accentColor),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Issue Category Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          categoryLabel,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Reporter vs Reported (Clickable to open user management modal)
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _showUserAdminModal(
                                              context,
                                              reporter,
                                              item['reporterRole'] == 'customer'
                                                  ? 'customer'
                                                  : 'artisan',
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.person_outline,
                                                    size: 12,
                                                    color: accentColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  reporterName,
                                                  style: TextStyle(
                                                      color: accentColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      decoration: TextDecoration
                                                          .underline),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(' ${t('ضد', 'vs')} ',
                                              style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 10)),
                                          InkWell(
                                            onTap: () => _showUserAdminModal(
                                              context,
                                              reported,
                                              item['reporterRole'] == 'customer'
                                                  ? 'artisan'
                                                  : 'customer',
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.shield_outlined,
                                                    size: 12,
                                                    color: Colors.orange),
                                                const SizedBox(width: 4),
                                                Text(
                                                  reportedName,
                                                  style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      decoration: TextDecoration
                                                          .underline),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Bottom row: Escrow amount & Date
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDate(item['createdAt']),
                                            style: TextStyle(
                                                color: subTextColor.withValues(
                                                    alpha: 0.7),
                                                fontSize: 10),
                                          ),
                                          Text(
                                            '₪${escrowAmt.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = filterKey);
          _loadDisputes();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accentColor : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? accentColor : borderColor),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: isSelected
                  ? (widget.isDarkMode ? Colors.black : Colors.white)
                  : subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DETAIL PANE (Dispute Inspection & Decision Actions)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDetailPane(bool isMobile) {
    if (_selectedDispute == null) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gavel_outlined,
                  size: 64, color: accentColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                t('اختر نزاعاً من القائمة الجانبية لمراجعته واتخاذ القرار',
                    'Select a dispute from the list to review and resolve'),
                style: GoogleFonts.cairo(color: subTextColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final d = _selectedDispute!;
    final status = d['adminStatus']?.toString() ?? 'pending';
    final isResolved = ['resolved_refunded', 'resolved_released', 'dismissed']
        .contains(status);
    final statusColor = _getStatusColor(status);
    final contractTitle = _getContractTitle(d);
    final contractType = _getContractType(d);
    final escrowAmt = _getEscrowAmount(d);
    final categoryLabel = DisputeService.issueCategoryLabel(
        d['issueCategory']?.toString() ?? 'other',
        arabic: widget.isArabic);
    final description = d['description']?.toString() ?? '';
    final requestedAction = d['requestedAction']?.toString() ?? 'none';
    final photoUrl = d['photoUrl']?.toString();

    final reporter = d['reporter'] as Map<String, dynamic>? ?? {};
    final reportedUser = d['reportedUser'] as Map<String, dynamic>? ?? {};
    final contract = d['contract'] as Map<String, dynamic>? ?? {};
    final payment = d['payment'] as Map<String, dynamic>? ?? {};
    final deliveryOrder = d['deliveryOrder'] as Map<String, dynamic>? ?? {};
    final driver = deliveryOrder['driver'] as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Top Header Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: accentColor,
                    onPressed: () => setState(() => _selectedDispute = null),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              contractType,
                              style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getStatusLabel(status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Clickable Title -> opens order details modal
                      InkWell(
                        onTap: () => _showContractDetailsModal(context, d),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                contractTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.open_in_new,
                                size: 16, color: accentColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Escrow Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(t('المبلغ المحتجز بالضمان', 'Escrow Amount'),
                          style: TextStyle(color: subTextColor, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(
                        '₪${escrowAmt.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Scrollable Inspector Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Parties Overview Row (Clickable to open user management modal)
                  Row(
                    children: [
                      // Reporter
                      Expanded(
                        child: InkWell(
                          onTap: () => _showUserAdminModal(
                            context,
                            reporter,
                            d['reporterRole'] == 'customer'
                                ? 'customer'
                                : 'artisan',
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: _buildPartyCard(
                            title: t('الطرف الشاكي (المُبلغ)', 'Reporter'),
                            name: reporter['name']?.toString() ?? '—',
                            role: d['reporterRole'] == 'customer'
                                ? t('زبون', 'Customer')
                                : t('حرفي', 'Artisan'),
                            phone: reporter['phone']?.toString() ?? '—',
                            email: reporter['email']?.toString() ?? '—',
                            icon: Icons.person_outline,
                            badgeColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Reported
                      Expanded(
                        child: InkWell(
                          onTap: () => _showUserAdminModal(
                            context,
                            reportedUser,
                            d['reporterRole'] == 'customer'
                                ? 'artisan'
                                : 'customer',
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: _buildPartyCard(
                            title: t('الطرف المشكو بحقه', 'Reported Party'),
                            name: reportedUser['name']?.toString() ?? '—',
                            role: d['reporterRole'] == 'customer'
                                ? t('حرفي', 'Artisan')
                                : t('زبون', 'Customer'),
                            phone: reportedUser['phone']?.toString() ?? '—',
                            email: reportedUser['email']?.toString() ?? '—',
                            icon: Icons.shield_outlined,
                            badgeColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Complaint Evidence & Description Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.report_problem_outlined,
                                      color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t('تفاصيل البلاغ والمطالبة',
                                          'Dispute Description & Request'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoryLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${t('المطلوب من الإدارة:', 'Requested Action:')} ${_translateRequestedAction(requestedAction)}',
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            description.isNotEmpty
                                ? description
                                : t('لا يوجد وصف إضافي',
                                    'No description provided.'),
                            style: TextStyle(
                                color: textColor, fontSize: 14, height: 1.4),
                          ),
                        ),

                        // Photo Evidence Preview
                        if (photoUrl != null && photoUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(t('إثبات الصور:', 'Photo Proof:'),
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                padding: const EdgeInsets.all(12),
                                color: surfaceColor,
                                child: Row(
                                  children: [
                                    const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                        t('تعذر تحميل الصورة الإثباتية',
                                            'Could not load photo proof'),
                                        style: TextStyle(
                                            color: subTextColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Contract & Delivery Audit Trail Row (Clickable)
                  InkWell(
                    onTap: () => _showContractDetailsModal(context, d),
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contract Info
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        t('بيانات العقد / الطلب',
                                            'Contract Data'),
                                        style: GoogleFonts.cairo(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    Icon(Icons.open_in_new,
                                        size: 14, color: accentColor),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _infoText(t('معرف العقد:', 'Contract ID:'),
                                    contract['id']?.toString() ?? '—'),
                                _infoText(
                                    t('عنوان التوصيل:', 'Shipping Address:'),
                                    contract['shippingAddress'] ??
                                        contract['pickupAddress'] ??
                                        '—'),
                                _infoText(t('هاتف التواصل:', 'Contact Phone:'),
                                    contract['customerPhone'] ?? '—'),
                                _infoText(
                                    t('حالة الدفع:', 'Payment Status:'),
                                    payment['paymentStatus']?.toString() ??
                                        'completed'),
                                if (payment['stripePaymentIntentId'] != null)
                                  _infoText(
                                      t('معرف Stripe:', 'Stripe Intent:'),
                                      payment['stripePaymentIntentId']
                                          .toString()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Delivery & Driver Info
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    t('بيانات التوصيل والمندوب',
                                        'Delivery & Driver'),
                                    style: GoogleFonts.cairo(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 8),
                                _infoText(
                                    t('رمز التوصيل:', 'Delivery Code:'),
                                    deliveryOrder['orderCode']?.toString() ??
                                        '—'),
                                _infoText(
                                    t('حالة التوصيل:', 'Delivery Status:'),
                                    deliveryOrder['status']?.toString() ?? '—'),
                                _infoText(
                                    t('اسم المندوب:', 'Driver Name:'),
                                    driver['name']?.toString() ??
                                        t('لم يتم تعيين مندوب',
                                            'No driver assigned')),
                                if (driver['phone'] != null)
                                  _infoText(t('هاتف المندوب:', 'Driver Phone:'),
                                      driver['phone'].toString()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Admin Resolution Decision Box
                  if (!isResolved) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.balance, color: accentColor, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                t('قرار الإدارة والحسم النهائي',
                                    'Admin Decision & Settlement'),
                                style: GoogleFonts.cairo(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _adminNotesController,
                            style: TextStyle(color: textColor, fontSize: 13),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: t(
                                  'أدخل سبب القرار وملاحظات الإدارة (تظهر للطرفين)...',
                                  'Enter resolution notes for audit log...'),
                              hintStyle:
                                  TextStyle(color: subTextColor, fontSize: 12),
                              filled: true,
                              fillColor: surfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3 Decision Action Buttons
                          Row(
                            children: [
                              // Option A: Refund Customer
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isResolving
                                      ? null
                                      : () =>
                                          _confirmResolution('customer_refund'),
                                  icon: const Icon(Icons.assignment_return,
                                      size: 16),
                                  label: Text(
                                      t('إرجاع للزبون', 'Refund Customer'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Option B: Release to Artisan
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isResolving
                                      ? null
                                      : () =>
                                          _confirmResolution('artisan_release'),
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 16),
                                  label: Text(
                                      t('تحرير للحرفي', 'Release Payment'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Option C: Dismiss / No Action
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isResolving
                                      ? null
                                      : () => _confirmResolution('no_action'),
                                  icon:
                                      const Icon(Icons.close_rounded, size: 16),
                                  label: Text(
                                      t('رفض النزاع', 'Dismiss Dispute'),
                                      style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: subTextColor,
                                    side: BorderSide(color: borderColor),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Already resolved banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: statusColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t('تم حسم النزاع بـ:', 'Dispute Resolved as:')} ${_getStatusLabel(status)}',
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                if (d['adminNotes'] != null)
                                  Text(
                                    '${t('ملاحظات الإدارة:', 'Admin Notes:')} ${d['adminNotes']}',
                                    style: TextStyle(
                                        color: textColor, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResolution(String actionType) {
    final title = actionType == 'customer_refund'
        ? t('تأكيد إرجاع المبلغ للزبون', 'Confirm Refund to Customer')
        : actionType == 'artisan_release'
            ? t('تأكيد تحرير المبلغ للحرفي', 'Confirm Release to Artisan')
            : t('تأكيد رفض النزاع وإغلاقه', 'Confirm Dismissing Dispute');

    final content = actionType == 'customer_refund'
        ? t('هل أنت تأكد من استرداد المبلغ للزبون وإلغاء المعاملة؟',
            'Are you sure you want to refund the customer via Stripe/Escrow?')
        : actionType == 'artisan_release'
            ? t('هل أنت تأكد من تحرير المستحقات للحرفي؟',
                'Are you sure you want to release the escrow funds to the artisan?')
            : t('هل أنت تأكد من رفض هذا البلاغ وإغلاقه بدون تغييرات مالية؟',
                'Dismiss dispute without changing payment escrow?');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.cairo(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        content:
            Text(content, style: TextStyle(color: subTextColor, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'),
                style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionType == 'customer_refund'
                  ? Colors.redAccent
                  : actionType == 'artisan_release'
                      ? Colors.green
                      : Colors.grey,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _resolveDispute(actionType);
            },
            child: Text(t('تأكيد وتنفيذ', 'Confirm & Execute'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyCard({
    required String title,
    required String name,
    required String role,
    required String phone,
    required String email,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(role,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.open_in_new, size: 14, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text('${t('الهاتف:', 'Phone:')} $phone',
              style: TextStyle(color: subTextColor, fontSize: 11)),
          Text('${t('الإيميل:', 'Email:')} $email',
              style: TextStyle(color: subTextColor, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, fontSize: 12),
          children: [
            TextSpan(
                text: '$label ',
                style: TextStyle(
                    color: subTextColor, fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _translateRequestedAction(String action) {
    switch (action) {
      case 'refund':
        return t('استرداد المبلغ كلياً', 'Full Refund');
      case 'release':
        return t('تحرير المستحقات', 'Release Escrow');
      case 'driver_penalty':
        return t('معاقبة المندوب', 'Driver Penalty');
      case 'none':
      default:
        return t('تقرير فقط (حل ودي)', 'Just Report (No Action)');
    }
  }
}
