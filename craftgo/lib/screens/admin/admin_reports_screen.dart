import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/report_service.dart';

class AdminReportsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AdminReportsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late bool isAr;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    isAr = widget.isArabic;
    _tabController = TabController(length: 3, vsync: this);
    ReportService.seedDemoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get isDark => widget.isDarkMode;
  Color get bg => isDark ? const Color(0xFF0D1420) : const Color(0xFFF0F2F5);
  Color get surface => isDark ? const Color(0xFF1C2431) : Colors.white;
  Color get primaryText => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get secondaryText => isDark ? Colors.white60 : Colors.black54;
  Color get border => isDark ? Colors.white12 : Colors.black12;

  List<CraftsmanReport> get pendingReports => ReportService.getAllReports()
      .where((r) => r.status == ReportStatus.pending)
      .toList();
  List<CraftsmanReport> get resolvedReports => ReportService.getAllReports()
      .where((r) => r.status == ReportStatus.resolved)
      .toList();
  List<CraftsmanReport> get dismissedReports => ReportService.getAllReports()
      .where((r) => r.status == ReportStatus.dismissed)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D1420) : Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'البلاغات' : 'Reports',
                style: GoogleFonts.cairo(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              Text(
                isAr
                    ? 'مدعوم بتوصيات الذكاء الاصطناعي 🤖'
                    : 'AI-Powered Recommendations 🤖',
                style: GoogleFonts.cairo(
                    color: const Color(0xFFD4A017), fontSize: 10),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFD4A017),
            labelColor: const Color(0xFFD4A017),
            unselectedLabelColor: secondaryText,
            labelStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(
                  text: isAr
                      ? 'معلقة (${pendingReports.length})'
                      : 'Pending (${pendingReports.length})'),
              Tab(text: isAr ? 'محلولة' : 'Resolved'),
              Tab(text: isAr ? 'مرفوضة' : 'Dismissed'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Stats Bar
            _buildStatsBar(),
            // Reports List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReportsList(pendingReports, showActions: true),
                  _buildReportsList(resolvedReports, showActions: false),
                  _buildReportsList(dismissedReports, showActions: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Bar ───────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final all = ReportService.getAllReports();
    final critical = all
        .where((r) => r.aiRecommendation.action == AiAction.blockPermanent)
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _statItem(
            all.length.toString(),
            isAr ? 'إجمالي' : 'Total',
            const Color(0xFF5C6BC0),
            Icons.bar_chart,
          ),
          _divider(),
          _statItem(
            pendingReports.length.toString(),
            isAr ? 'معلقة' : 'Pending',
            const Color(0xFFF57C00),
            Icons.hourglass_empty,
          ),
          _divider(),
          _statItem(
            critical.toString(),
            isAr ? 'حرجة' : 'Critical',
            const Color(0xFFE53935),
            Icons.warning_amber,
          ),
          _divider(),
          _statItem(
            resolvedReports.length.toString(),
            isAr ? 'محلولة' : 'Resolved',
            const Color(0xFF43A047),
            Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.cairo(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: GoogleFonts.cairo(color: secondaryText, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: border);

  // ── Reports List ────────────────────────────────────────────────────────────
  Widget _buildReportsList(List<CraftsmanReport> reports,
      {required bool showActions}) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: secondaryText),
            const SizedBox(height: 12),
            Text(
              isAr ? 'لا توجد بلاغات' : 'No reports found',
              style: GoogleFonts.cairo(color: secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reports.length,
      itemBuilder: (context, i) =>
          _reportCard(reports[i], showActions: showActions),
    );
  }

  // ── Report Card ─────────────────────────────────────────────────────────────
  Widget _reportCard(CraftsmanReport report, {required bool showActions}) {
    final rec = report.aiRecommendation;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFFE53935), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.craftsmanName,
                        style: GoogleFonts.cairo(
                            color: primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        '${isAr ? "بلاغ من:" : "Reported by:"} ${report.customerName}',
                        style: GoogleFonts.cairo(
                            color: secondaryText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(report.createdAt),
                  style: GoogleFonts.cairo(color: secondaryText, fontSize: 10),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: border),
          const SizedBox(height: 10),

          // Reason
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined,
                    color: Color(0xFFE53935), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAr ? report.reason : report.reasonEn,
                    style: GoogleFonts.cairo(
                        color: primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                report.description,
                style: GoogleFonts.cairo(
                    color: secondaryText, fontSize: 11, height: 1.5),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // AI Recommendation Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rec.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rec.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(rec.icon, color: rec.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'توصية الذكاء الاصطناعي:' : 'AI Recommendation:',
                        style: GoogleFonts.cairo(
                            color: rec.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAr ? rec.reasonAr : rec.reasonEn,
                        style: GoogleFonts.cairo(
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A2E),
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons (only for pending)
          if (showActions) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      label: isAr ? 'تحذير' : 'Warn',
                      icon: Icons.warning_amber,
                      color: const Color(0xFFFBC02D),
                      onTap: () => _showActionDialog(report, AiAction.warn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn(
                      label: isAr ? 'حظر مؤقت' : 'Temp Block',
                      icon: Icons.timer_off,
                      color: const Color(0xFFF57C00),
                      onTap: () =>
                          _showActionDialog(report, AiAction.blockTemp),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn(
                      label: isAr ? 'حظر دائم' : 'Block',
                      icon: Icons.block,
                      color: const Color(0xFFE53935),
                      onTap: () =>
                          _showActionDialog(report, AiAction.blockPermanent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    label: isAr ? 'تجاهل' : 'Dismiss',
                    icon: Icons.close,
                    color: secondaryText,
                    onTap: () {
                      ReportService.dismissReport(report.id);
                      setState(() {});
                    },
                    compact: true,
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: compact ? 10 : 0, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: compact
            ? Icon(icon, color: color, size: 16)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(height: 2),
                  Text(label,
                      style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  // ── Action Dialog ───────────────────────────────────────────────────────────
  void _showActionDialog(CraftsmanReport report, AiAction action) {
    String title, body;
    IconData icon;
    Color color;

    switch (action) {
      case AiAction.warn:
        title = isAr ? 'إرسال تحذير' : 'Send Warning';
        body = isAr
            ? 'سيتم إرسال تحذير رسمي للحرفي "${report.craftsmanName}"'
            : 'An official warning will be sent to "${report.craftsmanName}"';
        icon = Icons.warning_amber;
        color = const Color(0xFFFBC02D);
        break;
      case AiAction.blockTemp:
        title = isAr ? 'حظر مؤقت 7 أيام' : '7-Day Temp Block';
        body = isAr
            ? 'سيتم حظر "${report.craftsmanName}" مؤقتاً لمدة 7 أيام'
            : '"${report.craftsmanName}" will be blocked for 7 days';
        icon = Icons.timer_off;
        color = const Color(0xFFF57C00);
        break;
      default:
        title = isAr ? 'حظر دائم' : 'Permanent Block';
        body = isAr
            ? 'سيتم حظر "${report.craftsmanName}" بشكل دائم من المنصة'
            : '"${report.craftsmanName}" will be permanently blocked from the platform';
        icon = Icons.block;
        color = const Color(0xFFE53935);
    }

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.cairo(
                      color: primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          content: Text(body,
              style: GoogleFonts.cairo(
                  color: secondaryText, fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: GoogleFonts.cairo(color: secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                ReportService.resolveReport(report.id);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      isAr
                          ? '✅ تم تنفيذ الإجراء بنجاح'
                          : '✅ Action executed successfully',
                      style: GoogleFonts.cairo()),
                  backgroundColor: color,
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return isAr ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    }
    return isAr ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }
}
