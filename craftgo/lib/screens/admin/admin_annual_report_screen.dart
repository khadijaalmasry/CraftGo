import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/analytics_service.dart';

class AdminAnnualReportScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const AdminAnnualReportScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<AdminAnnualReportScreen> createState() =>
      _AdminAnnualReportScreenState();
}

class _AdminAnnualReportScreenState extends State<AdminAnnualReportScreen>
    with SingleTickerProviderStateMixin {
  late bool isAr;
  late bool isDark;
  late TabController _tabController;
  String _filter = 'all'; // all, gold, warning
  String _period = 'monthly'; // monthly, quarterly, annual
  CraftsmanAdminStats? _expanded;

  @override
  void initState() {
    super.initState();
    isAr = widget.isArabic;
    isDark = widget.isDarkMode;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get bg => isDark ? const Color(0xFF0D1420) : const Color(0xFFF0F2F5);
  Color get surface => isDark ? const Color(0xFF1C2431) : Colors.white;
  Color get primaryText => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get secondaryText => isDark ? Colors.white60 : Colors.black54;
  Color get border => isDark ? Colors.white12 : Colors.black12;
  Color get gold => const Color(0xFFD4A017);

  List<CraftsmanAdminStats> get allStats =>
      AnalyticsService.getAdminReports(_period);

  List<CraftsmanAdminStats> get filtered {
    if (_filter == 'gold') {
      return allStats
          .where((s) => s.badge == CraftsmanPerformanceBadge.gold)
          .toList();
    }
    if (_filter == 'warning') {
      return allStats
          .where((s) => s.badge == CraftsmanPerformanceBadge.warning)
          .toList();
    }
    return allStats;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Summary Strip
            _buildSummaryStrip(),
            // Filter chips
            _buildFilterBar(),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCraftsmanList(),
                  _buildOverviewTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0D1420) : Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'تقارير الحرفيين' : 'Craftsmen Reports',
            style: GoogleFonts.cairo(
                color: primaryText, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            isAr ? '2026 • مدعوم بالذكاء الاصطناعي 🤖' : '2026 • AI-Powered 🤖',
            style: GoogleFonts.cairo(color: gold, fontSize: 10),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: gold,
        labelColor: gold,
        unselectedLabelColor: secondaryText,
        labelStyle:
            GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(text: isAr ? 'الحرفيون' : 'Craftsmen'),
          Tab(text: isAr ? 'نظرة عامة' : 'Overview'),
        ],
      ),
      actions: [
        _topBtn(Icons.language, isAr ? 'EN' : 'عربي', () {
          setState(() => isAr = !isAr);
          widget.onToggleLanguage();
        }),
        const SizedBox(width: 6),
        _topBtn(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, '',
            () {
          setState(() => isDark = !isDark);
          widget.onToggleTheme();
        }),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _topBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primaryText),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.cairo(color: primaryText, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Summary Strip ───────────────────────────────────────────────────────────
  Widget _buildSummaryStrip() {
    final total = allStats.fold(0.0, (s, c) => s + c.totalRevenue);
    final totalOrders = allStats.fold(0, (s, c) => s + c.totalOrders);
    final avgRating =
        allStats.fold(0.0, (s, c) => s + c.avgRating) / allStats.length;
    final warnings = allStats
        .where((c) => c.badge == CraftsmanPerformanceBadge.warning)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _strip(total.toStringAsFixed(0), isAr ? 'الإيرادات' : 'Revenue', gold,
              Icons.attach_money),
          _divider(),
          _strip('$totalOrders', isAr ? 'الطلبات' : 'Orders',
              const Color(0xFF5C6BC0), Icons.shopping_bag_outlined),
          _divider(),
          _strip(avgRating.toStringAsFixed(1), isAr ? 'التقييم' : 'Rating',
              const Color(0xFFFFB300), Icons.star_half),
          _divider(),
          _strip('$warnings', isAr ? 'تحذيرات' : 'Warnings',
              const Color(0xFFE53935), Icons.warning_amber),
        ],
      ),
    );
  }

  Widget _strip(String val, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(val,
              style: GoogleFonts.cairo(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label,
              style: GoogleFonts.cairo(color: secondaryText, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: border);

  // ── Filter Bar ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final periods = [
      ('monthly', isAr ? 'شهري' : 'Monthly'),
      ('quarterly', isAr ? 'فصلي' : 'Quarterly'),
      ('annual', isAr ? 'سنوي' : 'Annual'),
    ];
    final filters = [
      ('all', isAr ? '🔍 الكل' : '🔍 All'),
      ('gold', isAr ? '🥇 متميزون' : '🥇 Top'),
      ('warning', isAr ? '⚠️ تحذير' : '⚠️ Warning'),
    ];

    return Column(
      children: [
        // Period Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: periods.map((p) {
              final isSelected = _period == p.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _period = p.$1;
                    _expanded = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? gold.withValues(alpha: 0.15) : surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? gold : border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p.$2,
                        style: GoogleFonts.cairo(
                          color: isSelected ? gold : secondaryText,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Status Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: filters.map((f) {
              final isSelected = _filter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _filter = f.$1;
                    _expanded = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? gold : surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? gold : border),
                    ),
                    child: Text(f.$2,
                        style: GoogleFonts.cairo(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : secondaryText,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Craftsman List ──────────────────────────────────────────────────────────
  Widget _buildCraftsmanList() {
    if (filtered.isEmpty) {
      return Center(
        child: Text(isAr ? 'لا توجد نتائج' : 'No results',
            style: GoogleFonts.cairo(color: secondaryText)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _craftsmanCard(filtered[i]),
    );
  }

  Widget _craftsmanCard(CraftsmanAdminStats s) {
    final isExpanded = _expanded?.craftsmanId == s.craftsmanId;
    final badgeData = _getBadge(s.badge);

    return GestureDetector(
      onTap: () => setState(() => _expanded = isExpanded ? null : s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded ? badgeData.$1.withValues(alpha: 0.5) : border,
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar + Badge
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: badgeData.$1.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(s.craftsmanName[0],
                              style: GoogleFonts.cairo(
                                  color: badgeData.$1,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Text(badgeData.$2,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.craftsmanName,
                            style: GoogleFonts.cairo(
                                color: primaryText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: secondaryText, size: 12),
                            const SizedBox(width: 3),
                            Text(s.craftsmanCity,
                                style: GoogleFonts.cairo(
                                    color: secondaryText, fontSize: 11)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: secondaryText)),
                            const SizedBox(width: 8),
                            Text(isAr ? s.craftAr : s.craftEn,
                                style: GoogleFonts.cairo(
                                    color: secondaryText, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Quick Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFFFFB300), size: 13),
                          const SizedBox(width: 3),
                          Text(s.avgRating.toStringAsFixed(1),
                              style: GoogleFonts.cairo(
                                  color: primaryText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                      Text('${s.totalOrders} ${isAr ? "طلب" : "orders"}',
                          style: GoogleFonts.cairo(
                              color: secondaryText, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Expanded Details
            if (isExpanded) ...[
              Divider(height: 1, color: border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        _miniStat(
                            '${s.totalRevenue.toStringAsFixed(0)} د.أ',
                            isAr ? 'الإيرادات' : 'Revenue',
                            const Color(0xFFD4A017)),
                        _miniStat(
                            '${s.onTimeDeliveryRate.toInt()}%',
                            isAr ? 'التسليم في الوقت' : 'On-Time',
                            const Color(0xFF43A047)),
                        _miniStat(
                            '${s.totalReports}',
                            isAr ? 'البلاغات' : 'Reports',
                            s.totalReports == 0
                                ? const Color(0xFF43A047)
                                : const Color(0xFFE53935)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Mini Revenue Chart (12 months)
                    _buildMiniChart(s),
                    const SizedBox(height: 14),

                    // AI Recommendation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: s.aiColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: s.aiColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(s.aiIcon, color: s.aiColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAr
                                  ? s.aiRecommendationAr
                                  : s.aiRecommendationEn,
                              style: GoogleFonts.cairo(
                                  color: primaryText,
                                  fontSize: 11,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _actionBtn(
                            isAr ? '⚠️ تحذير' : '⚠️ Warn',
                            const Color(0xFFFBC02D),
                            () => _showConfirm(s, 'warn'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn(
                            isAr ? '🥇 منح شارة' : '🥇 Award Badge',
                            const Color(0xFF43A047),
                            () => _showConfirm(s, 'badge'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionBtn(
                            isAr ? '🚫 حظر' : '🚫 Block',
                            const Color(0xFFE53935),
                            () => _showConfirm(s, 'block'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String val, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(val,
              style: GoogleFonts.cairo(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: GoogleFonts.cairo(color: secondaryText, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMiniChart(CraftsmanAdminStats s) {
    final maxVal = s.monthlyRevenue.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr ? '📊 الإيرادات الشهرية لـ 2026' : '📊 2026 Monthly Revenue',
          style: GoogleFonts.cairo(color: secondaryText, fontSize: 11),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final ratio = maxVal == 0 ? 0.0 : s.monthlyRevenue[i] / maxVal;
              final isBest = s.monthlyRevenue[i] == maxVal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message:
                        '${AnalyticsService.monthName(i + 1, isAr)}: ${s.monthlyRevenue[i].toInt()}',
                    child: Container(
                      height: 50 * ratio + 4,
                      decoration: BoxDecoration(
                        color: isBest ? gold : s.aiColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isAr ? 'يناير' : 'Jan',
                style: GoogleFonts.cairo(color: secondaryText, fontSize: 8)),
            Text(isAr ? 'ديسمبر' : 'Dec',
                style: GoogleFonts.cairo(color: secondaryText, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.cairo(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Overview Tab ────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    final gold_ =
        allStats.where((s) => s.badge == CraftsmanPerformanceBadge.gold).length;
    final silver = allStats
        .where((s) => s.badge == CraftsmanPerformanceBadge.silver)
        .length;
    final bronze = allStats
        .where((s) => s.badge == CraftsmanPerformanceBadge.bronze)
        .length;
    final warning = allStats
        .where((s) => s.badge == CraftsmanPerformanceBadge.warning)
        .length;
    final topCraftsman =
        allStats.reduce((a, b) => a.totalRevenue > b.totalRevenue ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Badge Distribution
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? '🏅 توزيع الأداء' : '🏅 Performance Distribution',
                  style: GoogleFonts.cairo(
                      color: primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 16),
                _badgeRow('🥇', isAr ? 'ذهبي — متميز' : 'Gold — Excellent',
                    gold_, const Color(0xFFFFB300)),
                _badgeRow('🥈', isAr ? 'فضي — جيد' : 'Silver — Good', silver,
                    const Color(0xFF78909C)),
                _badgeRow('🥉', isAr ? 'برونزي — مقبول' : 'Bronze — Fair',
                    bronze, const Color(0xFFBF8970)),
                _badgeRow(
                    '⚠️',
                    isAr ? 'تحذير — بحاجة متابعة' : 'Warning — Needs Review',
                    warning,
                    const Color(0xFFE53935)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Top Craftsman Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF2D2D4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isAr
                        ? '🏆 الحرفي الأفضل لهذه الفترة'
                        : '🏆 Top Craftsman for Period',
                    style: GoogleFonts.cairo(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gold.withValues(alpha: 0.2),
                        border: Border.all(color: gold, width: 2),
                      ),
                      child: Center(
                        child: Text(topCraftsman.craftsmanName[0],
                            style: GoogleFonts.cairo(
                                color: gold,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topCraftsman.craftsmanName,
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                            isAr ? topCraftsman.craftAr : topCraftsman.craftEn,
                            style: GoogleFonts.cairo(
                                color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${topCraftsman.totalRevenue.toStringAsFixed(0)} د.أ  •  ${topCraftsman.totalOrders} ${isAr ? "طلب" : "orders"}  •  ⭐ ${topCraftsman.avgRating}',
                            style: GoogleFonts.cairo(
                                color: gold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // AI Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFF1565C0), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isAr ? '🤖 ملخص AI للفترة' : '🤖 AI Period Summary',
                      style: GoogleFonts.cairo(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _aiSummaryPoint(isAr
                    ? '✅ $gold_ حرفيين بأداء ذهبي — يستحقون مكافأة سنوية'
                    : '✅ $gold_ craftsmen with gold performance — deserve annual reward'),
                _aiSummaryPoint(isAr
                    ? '⚠️ $warning حرفيين بحاجة لمتابعة عاجلة قبل الموسم القادم'
                    : '⚠️ $warning craftsmen need urgent follow-up before next season'),
                _aiSummaryPoint(isAr
                    ? '📈 إجمالي إيرادات المنصة ارتفع مقارنة بالعام الماضي'
                    : '📈 Total platform revenue increased vs last year'),
                _aiSummaryPoint(isAr
                    ? '💡 توصية: تفعيل برنامج تدريبي للحرفيين ذوي الأداء المنخفض'
                    : '💡 Recommendation: Launch training program for low-performing craftsmen'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeRow(String emoji, String label, int count, Color color) {
    final total = allStats.length;
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: GoogleFonts.cairo(
                            color: primaryText, fontSize: 11)),
                    Text('$count',
                        style: GoogleFonts.cairo(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiSummaryPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, left: 4, right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text,
                style: GoogleFonts.cairo(
                    color: primaryText, fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ── Confirm Dialog ──────────────────────────────────────────────────────────
  void _showConfirm(CraftsmanAdminStats s, String action) {
    final titles = {
      'warn': isAr ? 'إرسال تحذير' : 'Send Warning',
      'badge': isAr ? 'منح شارة ذهبية' : 'Award Gold Badge',
      'block': isAr ? 'حظر الحرفي' : 'Block Craftsman',
    };
    final colors = {
      'warn': const Color(0xFFFBC02D),
      'badge': const Color(0xFF43A047),
      'block': const Color(0xFFE53935),
    };

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(titles[action]!,
              style: GoogleFonts.cairo(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: Text(
            '${isAr ? "هل أنت متأكد من هذا الإجراء على الحرفي" : "Are you sure about this action for craftsman"} ${s.craftsmanName}?',
            style: GoogleFonts.cairo(color: secondaryText, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: GoogleFonts.cairo(color: secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors[action],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    isAr
                        ? '✅ تم تنفيذ الإجراء بنجاح'
                        : '✅ Action executed successfully',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: colors[action],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: Text(isAr ? 'تأكيد' : 'Confirm',
                  style: GoogleFonts.cairo(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _getBadge(CraftsmanPerformanceBadge badge) {
    switch (badge) {
      case CraftsmanPerformanceBadge.gold:
        return (const Color(0xFFFFB300), '🥇');
      case CraftsmanPerformanceBadge.silver:
        return (const Color(0xFF78909C), '🥈');
      case CraftsmanPerformanceBadge.bronze:
        return (const Color(0xFFBF8970), '🥉');
      case CraftsmanPerformanceBadge.warning:
        return (const Color(0xFFE53935), '⚠️');
    }
  }
}
