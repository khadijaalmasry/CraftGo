// admin_exhibition_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/exhibitions_service.dart';
import '../exhibitions/exhibition_detail_screen.dart';
import '../exhibitions/exhibition_add_screen.dart';
import 'pdf_viewer_screen.dart'; // PDF viewer screen (same directory)

// ─── AI Trust Score Model ──────────────────────────────────────────────
class AdminTrustScore {
  final int score;
  final bool locationVerified;
  final bool datesValid;
  final bool isNewAccount;
  final String recommendation;
  final Color color;

  AdminTrustScore({
    required this.score,
    required this.locationVerified,
    required this.datesValid,
    required this.isNewAccount,
    required this.recommendation,
    required this.color,
  });
}

class AdminExhibitionScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  const AdminExhibitionScreen(
      {super.key, required this.isArabic, required this.isDarkMode});
  @override
  State<AdminExhibitionScreen> createState() => _AdminExhibitionScreenState();
}

class _AdminExhibitionScreenState extends State<AdminExhibitionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allExhibitions = [];
  List<Map<String, dynamic>> _pendingExhibitions = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  String? _statusFilter;
  String? _cityFilter;

  // Theme helpers
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);
  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final all = await ExhibitionsService.getAdminExhibitions();
      final analytics = await ExhibitionsService.getAdminAnalytics();
      if (all.isNotEmpty) {
        setState(() {
          _allExhibitions = all.cast<Map<String, dynamic>>().toList();
          _pendingExhibitions = _allExhibitions
              .where((e) =>
                  e['verified'] == false ||
                  e['status']?.toString().toLowerCase() == 'pending')
              .toList();
        });
      }
      if (analytics != null) {
        setState(() {
          _analytics = analytics;
        });
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
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
            icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('إدارة المعارض', 'Exhibition Management'),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                  t('لوحة تحكم شاملة للمعارض',
                      'Complete Exhibition Control Panel'),
                  style: GoogleFonts.cairo(color: dim, fontSize: 11)),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
                icon: Icon(Icons.refresh, color: text), onPressed: _loadData),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: dim,
            labelStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
            tabs: [
              Tab(text: t('الدليل', 'Directory')),
              Tab(text: t('قيد المراجعة', 'Approvals')),
              Tab(text: t('الرؤى', 'Insights')),
              Tab(text: t('التحكم', 'Rules')),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error, style: GoogleFonts.cairo(color: dim)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black),
                          child: Text(t('إعادة المحاولة', 'Retry')),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 900;
                      return Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 1200 : double.infinity,
                          ),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildDirectoryTab(isDesktop),
                              _buildApprovalsTab(isDesktop),
                              _buildInsightsTab(isDesktop),
                              _buildRulesTab(isDesktop),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  // ─── Directory Tab ──────────────────────────────────────────────────────
  Widget _buildDirectoryTab(bool isDesktop) {
    final filtered = _allExhibitions.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final nameEn = (e['nameEn'] ?? '').toString().toLowerCase();
      final owner = (e['Owner']?['name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          nameEn.contains(query) ||
          owner.contains(query);
      final status = e['status']?.toString().toLowerCase() ?? '';
      final matchesStatus = _statusFilter == null ||
          _statusFilter == t('الكل', 'All') ||
          status == _statusFilter!.toLowerCase();
      final location = (e['location'] ?? '').toString().toLowerCase();
      final matchesCity = _cityFilter == null ||
          _cityFilter == t('الكل', 'All') ||
          location.contains(_cityFilter!.toLowerCase());
      return matchesSearch && matchesStatus && matchesCity;
    }).toList();

    final statuses = [
      t('الكل', 'All'),
      'Active',
      'Upcoming',
      'Past',
      'Pending',
      'Suspended'
    ];
    final cities = _allExhibitions
        .map((e) => e['location']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: text),
                decoration: InputDecoration(
                  hintText: t('ابحث عن معرض...', 'Search exhibitions...'),
                  hintStyle: TextStyle(color: dim),
                  prefixIcon: Icon(Icons.search, color: dim),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...statuses.map((s) => _filterChip(s, _statusFilter)),
                    const SizedBox(width: 8),
                    ...cities.map((c) => _filterChip(c, _cityFilter)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 48, color: dim),
                      const SizedBox(height: 12),
                      Text(t('لا توجد معارض', 'No exhibitions'),
                          style: GoogleFonts.cairo(color: dim)),
                    ],
                  ),
                )
              : isDesktop
                  ? GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 280,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        return _buildExhibitionCard(ex);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        return _buildExhibitionCard(ex);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? selected) {
    final isSelected =
        selected == label || (selected == null && label == t('الكل', 'All'));
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected == label) {
            final isStatus = [
              'Active',
              'Upcoming',
              'Past',
              'Pending',
              'Suspended'
            ].contains(label);
            if (isStatus) {
              _statusFilter = t('الكل', 'All');
            } else {
              _cityFilter = null;
            }
          } else {
            final isStatus = [
              'Active',
              'Upcoming',
              'Past',
              'Pending',
              'Suspended'
            ].contains(label);
            if (isStatus) {
              _statusFilter = label;
            } else {
              _cityFilter = label;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? accent : border),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : text,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Exhibition Card ──────────────────────────────────────────────────
  Widget _buildExhibitionCard(Map<String, dynamic> ex) {
    final isActive = ex['status'] == 'active';
    final isPending = ex['status'] == 'pending' || ex['verified'] == false;
    final isSuspended = ex['status'] == 'suspended';
    final statusColor = isActive
        ? Colors.green
        : isPending
            ? Colors.orange
            : isSuspended
                ? Colors.red
                : Colors.grey;

    final owner = ex['Owner'] ?? {};
    final ownerName = owner['name'] ?? 'غير معروف';
    final artisanCount = (ex['ExhibitionCraftsmen'] as List?)?.length ?? 0;
    final capacity = ex['capacity'] ?? ex['maxCapacity'] ?? 0;
    final trustScore = _getTrustScore(ex);

    // Location display
    String locationDisplay = ex['city']?.toString() ?? '';
    if (locationDisplay.isEmpty) {
      locationDisplay = ex['location']?.toString() ?? '';
    }
    if (locationDisplay.isEmpty &&
        ex['latitude'] != null &&
        ex['longitude'] != null) {
      final lat = ex['latitude'].toStringAsFixed(4);
      final lng = ex['longitude'].toStringAsFixed(4);
      locationDisplay = 'Lat: $lat, Lng: $lng';
    }
    if (locationDisplay.isEmpty) {
      locationDisplay = t('غير محدد', 'Not specified');
    }

    final permitUrl = ex['permitDocumentUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isArabic
                          ? (ex['name'] ?? '')
                          : (ex['nameEn'] ?? ex['name'] ?? ''),
                      style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(ownerName,
                            style: GoogleFonts.cairo(color: dim, fontSize: 11)),
                        const SizedBox(width: 4),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(ex['status'] ?? 'Upcoming',
                            style: GoogleFonts.cairo(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  (ex['featured'] ?? false) ? Icons.star : Icons.star_border,
                  color: (ex['featured'] ?? false) ? Colors.amber : dim,
                  size: 28,
                ),
                onPressed: () async {
                  final exhibId = ex['id']?.toString();
                  if (exhibId == null) return;
                  final newVal = !(ex['featured'] ?? false);
                  final success =
                      await ExhibitionsService.toggleFeatured(exhibId, newVal);
                  if (success != null) {
                    setState(() {
                      ex['featured'] = newVal;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newVal
                              ? t('تم إضافة المعرض للمميزين',
                                  'Exhibition featured')
                              : t('تم إزالة المعرض من المميزين',
                                  'Exhibition removed from featured'),
                        ),
                        backgroundColor: newVal ? Colors.green : Colors.grey,
                      ),
                    );
                  }
                },
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Metrics ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _metricChip(Icons.people, '$artisanCount/$capacity',
                      t('حرفي', 'Artisans'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricChip(Icons.calendar_today,
                      _formatDate(ex['startDate']) ?? '', '')),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricChip(Icons.location_on, locationDisplay, '')),
            ],
          ),
          const SizedBox(height: 8),

          // ── AI Trust Score ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trustScore.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: trustScore.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: trustScore.color, size: 14),
                const SizedBox(width: 6),
                Text('AI ${t('الثقة', 'Trust')}: ${trustScore.score}%',
                    style: GoogleFonts.cairo(
                        color: trustScore.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(trustScore.recommendation,
                    style: GoogleFonts.cairo(
                        color: trustScore.color, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Actions (Wrapped) ──────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              // View
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExhibitionDetailScreen(
                        exhibition: ex,
                        isAdminView: true,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.visibility, size: 16, color: accent),
                label: Text(t('عرض', 'View'),
                    style: GoogleFonts.cairo(color: accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ),
              // Edit
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExhibitionAddScreen(
                        existingExhibition: ex,
                        isAdminView: true,
                      ),
                    ),
                  ).then((result) {
                    if (result != null) _loadData();
                  });
                },
                icon: Icon(Icons.edit, size: 16, color: accent),
                label: Text(t('تعديل', 'Edit'),
                    style: GoogleFonts.cairo(color: accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ),
              // Permit (if exists) – open PDF viewer
              if (permitUrl != null && permitUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PDFViewerScreen(
                          url: permitUrl, // Correct parameter name
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.picture_as_pdf, size: 16, color: accent),
                  label: Text(t('التصريح', 'Permit'),
                      style: GoogleFonts.cairo(color: accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  ),
                ),
              // Suspend / Reactivate
              if (!isSuspended)
                ElevatedButton.icon(
                  onPressed: () => _showSuspendDialog(ex),
                  icon: Icon(Icons.block, size: 16, color: Colors.white),
                  label: Text(t('تعليق', 'Suspend'),
                      style: GoogleFonts.cairo(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _showUnsuspendDialog(ex),
                  icon: Icon(Icons.check_circle, size: 16, color: Colors.white),
                  label: Text(t('إعادة تفعيل', 'Reactivate'),
                      style: GoogleFonts.cairo(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: dim),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  color: text, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          if (label.isNotEmpty)
            Text(' $label', style: GoogleFonts.cairo(color: dim, fontSize: 9)),
        ],
      ),
    );
  }

  // ─── Approvals Tab ──────────────────────────────────────────────────────
  Widget _buildApprovalsTab([bool isDesktop = false]) {
    if (_pendingExhibitions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            Text(
                t('لا توجد معارض بانتظار المراجعة',
                    'No exhibitions awaiting review'),
                style: GoogleFonts.cairo(color: dim, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingExhibitions.length,
      itemBuilder: (context, index) {
        final ex = _pendingExhibitions[index];
        final trustScore = _getTrustScore(ex);
        final permitUrl = ex['permitDocumentUrl']?.toString();

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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.hourglass_top, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isArabic
                              ? (ex['name'] ?? '')
                              : (ex['nameEn'] ?? ex['name'] ?? ''),
                          style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        Text(
                          '${t('مقدم من', 'Submitted by')}: ${ex['Owner']?['name'] ?? 'غير معروف'}',
                          style: GoogleFonts.cairo(color: dim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(t('قيد المراجعة', 'Pending'),
                        style: GoogleFonts.cairo(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // AI Trust Score breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trustScore.color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: trustScore.color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: trustScore.color, size: 16),
                        const SizedBox(width: 6),
                        Text(t('تحليل الذكاء الاصطناعي', 'AI Trust Analysis'),
                            style: GoogleFonts.cairo(
                                color: trustScore.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const Spacer(),
                        Text('${trustScore.score}%',
                            style: GoogleFonts.cairo(
                                color: trustScore.color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                            trustScore.locationVerified
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: trustScore.locationVerified
                                ? Colors.green
                                : Colors.red,
                            size: 14),
                        const SizedBox(width: 4),
                        Text(t('الموقع محقق', 'Location Verified'),
                            style: TextStyle(
                                color: trustScore.locationVerified
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 11)),
                        const SizedBox(width: 12),
                        Icon(
                            trustScore.datesValid
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: trustScore.datesValid
                                ? Colors.green
                                : Colors.red,
                            size: 14),
                        const SizedBox(width: 4),
                        Text(t('التواريخ منطقية', 'Dates Valid'),
                            style: TextStyle(
                                color: trustScore.datesValid
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 11)),
                        const SizedBox(width: 12),
                        Icon(
                            trustScore.isNewAccount
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color: trustScore.isNewAccount
                                ? Colors.orange
                                : Colors.green,
                            size: 14),
                        const SizedBox(width: 4),
                        Text(
                            trustScore.isNewAccount
                                ? t('حساب حديث', 'New Account')
                                : t('حساب موثق', 'Verified'),
                            style: TextStyle(
                                color: trustScore.isNewAccount
                                    ? Colors.orange
                                    : Colors.green,
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: trustScore.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: trustScore.color, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(trustScore.recommendation,
                                  style: GoogleFonts.cairo(
                                      color: trustScore.color, fontSize: 11))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Actions (with Wrap)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  // Review
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExhibitionDetailScreen(
                              exhibition: ex, isAdminView: true),
                        ),
                      );
                    },
                    icon: Icon(Icons.visibility, size: 16, color: accent),
                    label: Text(t('مراجعة', 'Review'),
                        style: GoogleFonts.cairo(color: accent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                    ),
                  ),
                  // Permit (if exists) – open PDF viewer
                  if (permitUrl != null && permitUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PDFViewerScreen(
                              url: permitUrl, // Correct parameter name
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.picture_as_pdf, size: 16, color: accent),
                      label: Text(t('التصريح', 'Permit'),
                          style: GoogleFonts.cairo(color: accent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                      ),
                    ),
                  // Reject
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(ex),
                    icon: Icon(Icons.close, size: 16, color: Colors.red),
                    label: Text(t('رفض', 'Reject'),
                        style: GoogleFonts.cairo(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                    ),
                  ),
                  // Approve
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveExhibition(ex),
                      icon: Icon(Icons.check, size: 16, color: Colors.black),
                      label: Text(t('موافقة', 'Approve'),
                          style: GoogleFonts.cairo(color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                      ),
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

  // ── Approve, Reject, Suspend, Unsuspend dialogs ──────────────────────────
  Future<void> _approveExhibition(Map<String, dynamic> ex) async {
    final exhibId = ex['id']?.toString();
    if (exhibId == null) return;
    final result = await ExhibitionsService.approveExhibition(exhibId);
    if (result != null) {
      setState(() {
        ex['verified'] = true;
        ex['status'] = 'active';
        _pendingExhibitions.remove(ex);
        final idx = _allExhibitions.indexWhere((e) => e['id'] == exhibId);
        if (idx != -1) {
          _allExhibitions[idx]['verified'] = true;
          _allExhibitions[idx]['status'] = 'active';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم الموافقة على المعرض بنجاح',
              'Exhibition approved successfully')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showRejectDialog(Map<String, dynamic> ex) {
    final isArabic = widget.isArabic;
    String? selectedReason;
    String customReason = '';

    final reasons = [
      t('تفاصيل المكان غير صحيحة', 'Invalid venue details'),
      t('التسعير غير واقعي', 'Unrealistic pricing'),
      t('معرض مكرر', 'Duplicate listing'),
      t('المعلومات غير كاملة', 'Incomplete information'),
      t('سبب آخر', 'Other'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              t('رفض المعرض', 'Reject Exhibition'),
              style: GoogleFonts.cairo(
                color: text,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isArabic
                      ? (ex['name'] ?? '')
                      : (ex['nameEn'] ?? ex['name'] ?? ''),
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(
                        reason,
                        style: GoogleFonts.cairo(color: text),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (v) =>
                          setDialogState(() => selectedReason = v),
                      activeColor: accent,
                    )),
                if (selectedReason == reasons.last)
                  TextField(
                    onChanged: (v) => customReason = v,
                    maxLines: 2,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      hintText: t('اكتب السبب...', 'Write reason...'),
                      hintStyle: TextStyle(color: dim),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إلغاء', 'Cancel'),
                    style: GoogleFonts.cairo(color: dim)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final reason = selectedReason == reasons.last
                      ? customReason
                      : selectedReason ?? reasons[0];
                  final result = await ExhibitionsService.rejectExhibition(
                      ex['id'].toString(), reason);
                  if (result != null) {
                    setState(() {
                      _pendingExhibitions.remove(ex);
                      _allExhibitions.remove(ex);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t('تم رفض المعرض', 'Exhibition rejected'),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(t('تأكيد الرفض', 'Confirm Reject'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuspendDialog(Map<String, dynamic> ex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          t('تعليق المعرض', 'Suspend Exhibition'),
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          t('هل أنت متأكد من تعليق هذا المعرض؟ سيتم إخفاؤه من المجتمع.',
              'Are you sure you want to suspend this exhibition? It will be hidden from the community.'),
          style: GoogleFonts.cairo(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ExhibitionsService.adminOverrideStatus(
                  ex['id'].toString(), 'suspended');
              if (result != null) {
                setState(() {
                  ex['status'] = 'suspended';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('تم تعليق المعرض', 'Exhibition suspended')),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(t('تأكيد التعليق', 'Confirm Suspend'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUnsuspendDialog(Map<String, dynamic> ex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          t('إعادة تفعيل المعرض', 'Reactivate Exhibition'),
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          t('هل أنت متأكد من إعادة تفعيل هذا المعرض؟ سيعود للظهور في المجتمع.',
              'Are you sure you want to reactivate this exhibition? It will reappear in the community.'),
          style: GoogleFonts.cairo(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ExhibitionsService.adminOverrideStatus(
                  ex['id'].toString(), 'active');
              if (result != null) {
                setState(() {
                  ex['status'] = 'active';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        t('تم إعادة تفعيل المعرض', 'Exhibition reactivated')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(t('تأكيد التفعيل', 'Confirm Reactivate'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // TAB 3: INSIGHTS (unchanged)
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildInsightsTab([bool isDesktop = false]) {
    final totalCapacity = _analytics?['totalCapacity'] ?? 0;
    final totalArtisans = _analytics?['totalArtisans'] ?? 0;
    final occupancy = _analytics?['occupancy'] ?? 0.0;
    final active = _analytics?['active'] ?? 0;
    final categoryCount = _analytics?['categoryCount'] ?? {};
    final cityCount = _analytics?['cityCount'] ?? {};

    final sortedCategories = (categoryCount as Map).entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final sortedCities = (cityCount as Map).entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats Grid ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  t('الإشغال', 'Occupancy'),
                  '${(occupancy * 100).toInt()}%',
                  Colors.blue,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  t('الطلب', 'Demand'),
                  '$totalArtisans',
                  Colors.purple,
                  Icons.people,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  t('السعة الكلية', 'Total Capacity'),
                  '$totalCapacity',
                  Colors.green,
                  Icons.event_seat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  t('المعارض النشطة', 'Active'),
                  '$active',
                  Colors.orange,
                  Icons.event_available,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── AI Forecast ──────────────────────────────────────────────────
          Container(
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
                  children: [
                    Icon(Icons.auto_awesome, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      t('توقعات AI للموسم القادم', 'AI Season Forecast'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '+45%',
                            style: GoogleFonts.cairo(
                              color: Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            t('نمو في الطلبات', 'Request Growth'),
                            style: GoogleFonts.cairo(color: dim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: border),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            t('ممتاز', 'Excellent'),
                            style: GoogleFonts.cairo(
                              color: Colors.amber,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            t('فرصة المبيعات', 'Sales Chance'),
                            style: GoogleFonts.cairo(color: dim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: border),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '+1200',
                            style: GoogleFonts.cairo(
                              color: Colors.blue,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            t('زائر متوقع', 'Expected Visitors'),
                            style: GoogleFonts.cairo(color: dim, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Category Distribution ──────────────────────────────────────
          if (sortedCategories.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('توزيع الحرف', 'Craft Distribution'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedCategories.take(5).map((entry) {
                    final pct = _allExhibitions.isEmpty
                        ? 0
                        : (entry.value / _allExhibitions.length);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              widget.isArabic
                                  ? _getArabicCategory(entry.key)
                                  : entry.key,
                              style: GoogleFonts.cairo(
                                color: text,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                backgroundColor: border,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).toInt()}%',
                            style: GoogleFonts.cairo(
                              color: dim,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── City Distribution ──────────────────────────────────────────
          if (sortedCities.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('التوزيع الجغرافي', 'Geographic Distribution'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sortedCities.map((entry) {
                      final pct = _allExhibitions.isEmpty
                          ? 0
                          : (entry.value / _allExhibitions.length);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.cairo(
                                color: text,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _insightCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(color: dim, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getArabicCategory(String en) {
    final map = {
      'Woodworking': 'نجارة',
      'Pottery': 'فخار',
      'Jewelry': 'مجوهرات',
      'Textiles': 'نسيج',
      'Painting': 'رسم',
      'Calligraphy': 'خط',
      'Ceramics': 'خزف',
      'Leatherwork': 'جلديات',
      'Glass': 'زجاج',
      'Metalwork': 'نحاسيات',
      'Digital Art': 'فن رقمي',
      'Other': 'أخرى',
    };
    return map[en] ?? en;
  }

  // ──────────────────────────────────────────────────────────────────────
  // TAB 4: RULES & FEATURED SPOTLIGHT (unchanged)
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildRulesTab([bool isDesktop = false]) {
    final featured =
        _allExhibitions.where((e) => e['featured'] == true).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Featured Carousel Manager ──────────────────────────────────
          Text(
            t('المعرض المميز', 'Featured Spotlight'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('إدارة المعارض المميزة التي تظهر في الواجهة الرئيسية',
                'Manage featured exhibitions that appear on the home feed'),
            style: GoogleFonts.cairo(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (featured.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Center(
                child: Text(
                  t('لا توجد معارض مميزة حالياً', 'No featured exhibitions'),
                  style: GoogleFonts.cairo(color: dim),
                ),
              ),
            )
          else
            ...featured.map((ex) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.star, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isArabic
                              ? (ex['name'] ?? '')
                              : (ex['nameEn'] ?? ex['name'] ?? ''),
                          style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: dim),
                        onPressed: () async {
                          final exhibId = ex['id']?.toString();
                          if (exhibId == null) return;
                          final success =
                              await ExhibitionsService.toggleFeatured(
                                  exhibId, false);
                          if (success != null) {
                            setState(() {
                              ex['featured'] = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t('تم إزالة المعرض من المميزين',
                                    'Exhibition removed from featured')),
                                backgroundColor: Colors.grey,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                )),

          const SizedBox(height: 24),

          // ── Platform Rules ─────────────────────────────────────────────
          Text(
            t('ضوابط المنصة', 'Platform Rules'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('إعدادات الحدود الدنيا والعليا للمعارض',
                'Global exhibition configuration'),
            style: GoogleFonts.cairo(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _ruleItem(
                  title: t('الحد الأدنى لعدد الأكشاك', 'Min Booth Size'),
                  value: '2 × 2',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(t('سيتم التطوير قريباً', 'Coming soon'))),
                    );
                  },
                ),
                Divider(color: border),
                _ruleItem(
                  title: t('الحد الأقصى لعدد الأكشاك', 'Max Booth Size'),
                  value: '5 × 5',
                  onTap: () {},
                ),
                Divider(color: border),
                _ruleItem(
                  title: t('سقف سعر الكشك', 'Max Booth Price'),
                  value: '50 JOD',
                  onTap: () {},
                ),
                Divider(color: border),
                _ruleItem(
                  title: t('طلب موافقة مسبقة', 'Require Pre-Approval'),
                  value: t('مفعل', 'Enabled'),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Reported Exhibitions ──────────────────────────────────────
          Text(
            t('المعارض المبلغ عنها', 'Reported Exhibitions'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.flag_outlined, size: 40, color: dim),
                  const SizedBox(height: 8),
                  Text(
                    t('لا توجد بلاغات حالياً', 'No reported exhibitions'),
                    style: GoogleFonts.cairo(color: dim),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleItem({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: GoogleFonts.cairo(
            color: text,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.cairo(color: dim, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: dim, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  String? _formatDate(dynamic dateVal) {
    if (dateVal == null) return null;
    try {
      final dt = DateTime.parse(dateVal.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateVal.toString().substring(0, 10);
    }
  }

  AdminTrustScore _getTrustScore(Map<String, dynamic> ex) {
    final hasPermit = ex['hasPermit'] ?? false;
    final isNewAccount = true;
    final hasLocation = ex['latitude'] != null && ex['longitude'] != null;

    final score = (hasPermit ? 40 : 0) +
        (hasLocation ? 30 : 0) +
        (isNewAccount ? 10 : 30);
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    final recommendation = score >= 80
        ? t('موصى بالموافقة', 'Recommended for approval')
        : score >= 60
            ? t('مراجعة إضافية', 'Additional review needed')
            : t('توصية بالرفض', 'Recommended for rejection');

    return AdminTrustScore(
      score: score,
      locationVerified: hasLocation,
      datesValid: true,
      isNewAccount: isNewAccount,
      recommendation: recommendation,
      color: color,
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../services/exhibitions_service.dart';
// import '../../services/ai_service.dart';
// import '../../services/api_service.dart';

// class AdminExhibitionScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;

//   const AdminExhibitionScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//   });

//   @override
//   State<AdminExhibitionScreen> createState() => _AdminExhibitionScreenState();
// }

// class _AdminExhibitionScreenState extends State<AdminExhibitionScreen> {
//   Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
//   Color get border => widget.isDarkMode
//       ? Colors.white.withValues(alpha: 0.1)
//       : Colors.black.withValues(alpha: 0.1);
//   Color get accent => const Color(0xFFD4A017);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   late Future<List<dynamic>> _exhibitionsFuture;

//   @override
//   void initState() {
//     super.initState();
//     _exhibitionsFuture = ExhibitionsService.getAllExhibitions();
//   }

//   void _refresh() {
//     setState(() {
//       _exhibitionsFuture = ExhibitionsService.getAllExhibitions();
//     });
//   }

//   Future<void> _runAIMatching(String exhibitionId, String exhibitionName) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => Directionality(
//         textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//         child: AlertDialog(
//           backgroundColor: surface,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//           title: Row(
//             children: [
//               const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
//               const SizedBox(width: 8),
//               Text(
//                 t('ترشيح بالذكاء الاصطناعي', 'AI Matching'),
//                 style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 18),
//               ),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const CircularProgressIndicator(color: Colors.purpleAccent),
//               const SizedBox(height: 16),
//               Text(
//                 t('جاري تحليل قائمة الاحتياط لاختيار أفضل بديل...', 'Analyzing standby list to find the best replacement...'),
//                 style: GoogleFonts.cairo(color: dim, fontSize: 14),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );

//     final matchResult = await AiService.matchStandby(exhibitionId);
    
//     if (!mounted) return;
//     Navigator.pop(context); // Close loading dialog

//     if (matchResult != null && matchResult['match'] != null) {
//       final match = matchResult['match'];
//       showDialog(
//         context: context,
//         builder: (ctx) => Directionality(
//           textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//           child: AlertDialog(
//             backgroundColor: surface,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//             title: Row(
//               children: [
//                 const Icon(Icons.check_circle, color: Colors.green),
//                 const SizedBox(width: 8),
//                 Text(
//                   t('تم اختيار بديل!', 'Replacement Selected!'),
//                   style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 18),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.purpleAccent.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           t('الذكاء الاصطناعي يوصي بـ:', 'AI Recommends:'),
//                           style: GoogleFonts.cairo(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   match['name']?.toString() ?? match['username']?.toString() ?? 'حرفي',
//                   style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   match['specialty'] != null ? '${t('التخصص:', 'Specialty:')} ${match['specialty']}' : '',
//                   style: GoogleFonts.cairo(color: dim, fontSize: 14),
//                 ),
//                 Text(
//                   match['rating'] != null ? '${t('التقييم:', 'Rating:')} ⭐ ${match['rating']}' : '',
//                   style: GoogleFonts.cairo(color: Colors.amber, fontSize: 14),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   t('تم إرسال إشعار للحرفي لتأكيد مشاركته بدلاً من المعتذر.', 'A notification has been sent to the craftsman to confirm their participation.'),
//                   style: GoogleFonts.cairo(color: dim, fontSize: 12),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(ctx);
//                   _refresh();
//                 },
//                 child: Text(t('إغلاق', 'Close'), style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
//               ),
//             ],
//           ),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(t('لا يوجد بدلاء في قائمة الاحتياط أو حدث خطأ', 'No standby replacements available or an error occurred')),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//     }
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
//             icon: Icon(Icons.arrow_back_ios_new, color: text, size: 20),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: Text(
//             t('إدارة معارضي', 'Manage My Exhibitions'),
//             style: GoogleFonts.cairo(
//               color: text,
//               fontWeight: FontWeight.bold,
//               fontSize: 18,
//             ),
//           ),
//           centerTitle: true,
//           actions: [
//             IconButton(
//               icon: Icon(Icons.refresh, color: text),
//               onPressed: _refresh,
//             ),
//           ],
//         ),
//         body: FutureBuilder<List<dynamic>>(
//           future: _exhibitionsFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator(color: accent));
//             }
//             if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.business_center, color: dim, size: 64),
//                     const SizedBox(height: 16),
//                     Text(
//                       t('لا توجد معارض لعرضها', 'No exhibitions to show'),
//                       style: GoogleFonts.cairo(color: dim, fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               );
//             }

//             final exhibitions = snapshot.data!;
//             return ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: exhibitions.length,
//               itemBuilder: (context, index) {
//                 final ex = exhibitions[index] as Map<String, dynamic>;
                
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   decoration: BoxDecoration(
//                     color: surface,
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: border),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withValues(alpha: 0.05),
//                         blurRadius: 10,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     children: [
//                       // Header
//                       Padding(
//                         padding: const EdgeInsets.all(16),
//                         child: Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Container(
//                               width: 50,
//                               height: 50,
//                               decoration: BoxDecoration(
//                                 color: accent.withValues(alpha: 0.1),
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: Icon(Icons.event, color: accent),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     ex['name']?.toString() ?? 'معرض',
//                                     style: GoogleFonts.cairo(
//                                       color: text,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     ex['startDate'] != null
//                                         ? ex['startDate'].toString().substring(0, 10)
//                                         : 'TBD',
//                                     style: GoogleFonts.cairo(color: dim, fontSize: 12),
//                                   ),
//                                   Text(
//                                     ex['location']?.toString() ?? '',
//                                     style: GoogleFonts.cairo(color: dim, fontSize: 12),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const Divider(height: 1),
//                       // Actions
//                       Padding(
//                         padding: const EdgeInsets.all(12),
//                         child: Column(
//                           children: [
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () {},
//                                     icon: const Icon(Icons.people, size: 18),
//                                     label: Text(
//                                       t('إدارة الحرفيين', 'Manage Craftsmen'),
//                                       style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
//                                     ),
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: surface,
//                                       foregroundColor: text,
//                                       side: BorderSide(color: border),
//                                       elevation: 0,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             SizedBox(
//                               width: double.infinity,
//                               child: ElevatedButton.icon(
//                                 onPressed: () => _runAIMatching(ex['id'].toString(), ex['name'].toString()),
//                                 icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
//                                 label: Text(
//                                   t('إيجاد بديل بالذكاء الاصطناعي', 'Find AI Replacement'),
//                                   style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.purpleAccent,
//                                   elevation: 0,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ),
//     );
//   }
// }