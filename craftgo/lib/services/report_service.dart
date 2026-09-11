import 'package:flutter/material.dart';

// ─── Report Model ────────────────────────────────────────────────────────────
class CraftsmanReport {
  final String id;
  final String craftsmanId;
  final String craftsmanName;
  final String customerId;
  final String customerName;
  final String reason;
  final String reasonEn;
  final String description;
  final DateTime createdAt;
  ReportStatus status;
  final AiRecommendation aiRecommendation;

  CraftsmanReport({
    required this.id,
    required this.craftsmanId,
    required this.craftsmanName,
    required this.customerId,
    required this.customerName,
    required this.reason,
    required this.reasonEn,
    required this.description,
    required this.createdAt,
    this.status = ReportStatus.pending,
    required this.aiRecommendation,
  });
}

enum ReportStatus { pending, resolved, dismissed }

// ─── AI Recommendation Model ─────────────────────────────────────────────────
class AiRecommendation {
  final AiAction action;
  final String reasonAr;
  final String reasonEn;
  final Color color;
  final IconData icon;

  const AiRecommendation({
    required this.action,
    required this.reasonAr,
    required this.reasonEn,
    required this.color,
    required this.icon,
  });
}

enum AiAction { blockPermanent, blockTemp, warn, monitor }

// ─── Report Reasons ───────────────────────────────────────────────────────────
class ReportReason {
  final String ar;
  final String en;
  final int weight; // 1=light, 2=medium, 3=heavy, 4=critical

  const ReportReason({required this.ar, required this.en, required this.weight});
}

// ─── Report Service ───────────────────────────────────────────────────────────
class ReportService {
  // Static in-memory store (replace with real DB later)
  static final List<CraftsmanReport> _reports = [];

  static final List<ReportReason> reasons = [
    ReportReason(ar: '🔴 احتيال / لم يرسل المنتج', en: '🔴 Fraud / Product not delivered', weight: 4),
    ReportReason(ar: '🔴 محتوى مسيء أو غير لائق', en: '🔴 Offensive or inappropriate content', weight: 4),
    ReportReason(ar: '🟠 جودة مختلفة عن الصور', en: '🟠 Quality differs from photos', weight: 3),
    ReportReason(ar: '🟠 سعر مختلف عن المتفق', en: '🟠 Price different from agreement', weight: 3),
    ReportReason(ar: '🟡 تأخر في التسليم بدون إشعار', en: '🟡 Delivery delay without notice', weight: 2),
    ReportReason(ar: '🟡 تواصل غير محترم', en: '🟡 Disrespectful communication', weight: 2),
    ReportReason(ar: '🟢 أخرى', en: '🟢 Other', weight: 1),
  ];

  /// Submit a new report and get AI recommendation instantly
  static CraftsmanReport submitReport({
    required String craftsmanId,
    required String craftsmanName,
    required String customerId,
    required String customerName,
    required ReportReason reason,
    required String description,
  }) {
    final existingReports = getReportsByCraftsman(craftsmanId);
    final aiRec = _generateAiRecommendation(reason, existingReports.length);

    final report = CraftsmanReport(
      id: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
      craftsmanId: craftsmanId,
      craftsmanName: craftsmanName,
      customerId: customerId,
      customerName: customerName,
      reason: reason.ar,
      reasonEn: reason.en,
      description: description,
      createdAt: DateTime.now(),
      aiRecommendation: aiRec,
    );

    _reports.add(report);
    return report;
  }

  /// Get all reports (for admin)
  static List<CraftsmanReport> getAllReports() => List.unmodifiable(_reports.reversed.toList());

  /// Get reports for a specific craftsman
  static List<CraftsmanReport> getReportsByCraftsman(String craftsmanId) =>
      _reports.where((r) => r.craftsmanId == craftsmanId).toList();

  /// Admin actions
  static void resolveReport(String reportId) {
    final i = _reports.indexWhere((r) => r.id == reportId);
    if (i != -1) _reports[i].status = ReportStatus.resolved;
  }

  static void dismissReport(String reportId) {
    final i = _reports.indexWhere((r) => r.id == reportId);
    if (i != -1) _reports[i].status = ReportStatus.dismissed;
  }

  // ── AI Engine ──────────────────────────────────────────────────────────────
  static AiRecommendation _generateAiRecommendation(ReportReason reason, int previousCount) {
    // Critical reasons → immediate block
    if (reason.weight == 4) {
      return const AiRecommendation(
        action: AiAction.blockPermanent,
        reasonAr: '🤖 بلاغ خطير جداً — أنصح بحظر فوري ومراجعة الحساب',
        reasonEn: '🤖 Critical report — Recommend immediate block & account review',
        color: Color(0xFFE53935),
        icon: Icons.block,
      );
    }

    // 3+ previous reports → temp block
    if (previousCount >= 3) {
      return const AiRecommendation(
        action: AiAction.blockTemp,
        reasonAr: '🤖 تراكم بلاغات متعددة — أنصح بحظر مؤقت 7 أيام',
        reasonEn: '🤖 Multiple repeated reports — Recommend 7-day temporary block',
        color: Color(0xFFF57C00),
        icon: Icons.timer_off,
      );
    }

    // Heavy reason or 2 previous reports → warning
    if (reason.weight == 3 || previousCount >= 2) {
      return const AiRecommendation(
        action: AiAction.warn,
        reasonAr: '🤖 بلاغ ذو وزن — أنصح بإرسال تحذير رسمي للحرفي',
        reasonEn: '🤖 Significant report — Recommend sending official warning',
        color: Color(0xFFFBC02D),
        icon: Icons.warning_amber,
      );
    }

    // First light report → just monitor
    return const AiRecommendation(
      action: AiAction.monitor,
      reasonAr: '🤖 بلاغ خفيف وأول مرة — أنصح بالمراقبة فقط دون إجراء',
      reasonEn: '🤖 Light first-time report — Recommend monitoring only',
      color: Color(0xFF43A047),
      icon: Icons.visibility,
    );
  }

  /// Seed demo data so admin sees something
  static void seedDemoData() {
    if (_reports.isNotEmpty) return;
    final now = DateTime.now();

    _reports.addAll([
      CraftsmanReport(
        id: 'RPT-001',
        craftsmanId: 'c1',
        craftsmanName: 'خالد الصنايعي',
        customerId: 'u1',
        customerName: 'سارة أحمد',
        reason: reasons[0].ar,
        reasonEn: reasons[0].en,
        description: 'دفعت ثمن المنتج منذ أسبوعين ولم يصل شيء ولم يرد على رسائلي',
        createdAt: now.subtract(const Duration(hours: 2)),
        aiRecommendation: _generateAiRecommendation(reasons[0], 1),
      ),
      CraftsmanReport(
        id: 'RPT-002',
        craftsmanId: 'c2',
        craftsmanName: 'ليلى الحرفية',
        customerId: 'u2',
        customerName: 'محمد خالد',
        reason: reasons[2].ar,
        reasonEn: reasons[2].en,
        description: 'المنتج وصل بجودة أقل بكثير من الصور المعروضة',
        createdAt: now.subtract(const Duration(hours: 6)),
        aiRecommendation: _generateAiRecommendation(reasons[2], 0),
      ),
      CraftsmanReport(
        id: 'RPT-003',
        craftsmanId: 'c3',
        craftsmanName: 'أحمد الخزاف',
        customerId: 'u3',
        customerName: 'نور علي',
        reason: reasons[4].ar,
        reasonEn: reasons[4].en,
        description: '',
        createdAt: now.subtract(const Duration(days: 1)),
        aiRecommendation: _generateAiRecommendation(reasons[4], 3),
      ),
    ]);
  }
}
