import 'package:flutter/material.dart';

// ─── Product Monthly Stats ────────────────────────────────────────────────────
class ProductMonthlyStats {
  final String productId;
  final String productNameAr;
  final String productNameEn;
  final String productEmoji;
  final int month;
  final int year;

  final int totalOrders;
  final int prevMonthOrders;
  final double totalRevenue;
  final double prevMonthRevenue;
  final double avgRating;
  final double prevMonthRating;
  final int totalViews;
  final int rejectedOrders;
  final String bestDayAr;
  final String bestDayEn;
  final List<double> weeklyRevenue; // 4 weeks
  final List<String> aiInsightsAr;
  final List<String> aiInsightsEn;

  const ProductMonthlyStats({
    required this.productId,
    required this.productNameAr,
    required this.productNameEn,
    required this.productEmoji,
    required this.month,
    required this.year,
    required this.totalOrders,
    required this.prevMonthOrders,
    required this.totalRevenue,
    required this.prevMonthRevenue,
    required this.avgRating,
    required this.prevMonthRating,
    required this.totalViews,
    required this.rejectedOrders,
    required this.bestDayAr,
    required this.bestDayEn,
    required this.weeklyRevenue,
    required this.aiInsightsAr,
    required this.aiInsightsEn,
  });

  double get orderGrowth => prevMonthOrders == 0
      ? 0
      : ((totalOrders - prevMonthOrders) / prevMonthOrders) * 100;

  double get revenueGrowth => prevMonthRevenue == 0
      ? 0
      : ((totalRevenue - prevMonthRevenue) / prevMonthRevenue) * 100;

  double get ratingChange => avgRating - prevMonthRating;

  double get rejectionRate =>
      totalOrders == 0 ? 0 : (rejectedOrders / totalOrders) * 100;
}

// ─── Craftsman Admin Stats (Periodic) ─────────────────────────────────────────
class CraftsmanAdminStats {
  final String craftsmanId;
  final String craftsmanName;
  final String craftsmanCity;
  final String craftAr;
  final String craftEn;
  final int year;

  final int totalOrders;
  final double totalRevenue;
  final double avgRating;
  final int totalReports;
  final double onTimeDeliveryRate;
  final String bestMonthAr;
  final String bestMonthEn;
  final List<double> monthlyRevenue; // 12 months
  final CraftsmanPerformanceBadge badge;
  final String aiRecommendationAr;
  final String aiRecommendationEn;
  final Color aiColor;
  final IconData aiIcon;

  const CraftsmanAdminStats({
    required this.craftsmanId,
    required this.craftsmanName,
    required this.craftsmanCity,
    required this.craftAr,
    required this.craftEn,
    required this.year,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgRating,
    required this.totalReports,
    required this.onTimeDeliveryRate,
    required this.bestMonthAr,
    required this.bestMonthEn,
    required this.monthlyRevenue,
    required this.badge,
    required this.aiRecommendationAr,
    required this.aiRecommendationEn,
    required this.aiColor,
    required this.aiIcon,
  });
}

enum CraftsmanPerformanceBadge { gold, silver, bronze, warning }

// ─── Analytics Service ────────────────────────────────────────────────────────
class AnalyticsService {
  // ── Craftsman Product Reports (Monthly) ──────────────────────────────────────
  static List<ProductMonthlyStats> getCraftsmanProductReports() {
    return [
      ProductMonthlyStats(
        productId: 'p1',
        productNameAr: 'طقم أكواب خزفية يدوية',
        productNameEn: 'Handmade Ceramic Cup Set',
        productEmoji: '🏺',
        month: 7,
        year: 2026,
        totalOrders: 14,
        prevMonthOrders: 9,
        totalRevenue: 420,
        prevMonthRevenue: 270,
        avgRating: 4.8,
        prevMonthRating: 4.5,
        totalViews: 230,
        rejectedOrders: 1,
        bestDayAr: 'الجمعة',
        bestDayEn: 'Friday',
        weeklyRevenue: [80, 110, 130, 100],
        aiInsightsAr: [
          '🏆 منتجك الأكثر مبيعاً هذا الشهر!',
          '📈 المبيعات ارتفعت 55% مقارنة بالشهر الماضي',
          '⭐ التقييم ممتاز — استمر بنفس الجودة',
          '💡 أفضل وقت للنشر: الجمعة صباحاً',
        ],
        aiInsightsEn: [
          '🏆 Your best-selling product this month!',
          '📈 Sales up 55% vs last month',
          '⭐ Excellent rating — keep up the quality',
          '💡 Best time to post: Friday morning',
        ],
      ),
      ProductMonthlyStats(
        productId: 'p2',
        productNameAr: 'سلة قش تراثية مطرزة',
        productNameEn: 'Embroidered Heritage Basket',
        productEmoji: '🧺',
        month: 7,
        year: 2026,
        totalOrders: 6,
        prevMonthOrders: 8,
        totalRevenue: 180,
        prevMonthRevenue: 240,
        avgRating: 3.9,
        prevMonthRating: 4.3,
        totalViews: 95,
        rejectedOrders: 2,
        bestDayAr: 'السبت',
        bestDayEn: 'Saturday',
        weeklyRevenue: [60, 45, 50, 25],
        aiInsightsAr: [
          '⚠️ المبيعات انخفضت 25% — راجع صور المنتج',
          '📉 التقييم انخفض — تحقق من التعليقات الأخيرة',
          '💡 حاول تخفيض السعر مؤقتاً لجذب زبائن جدد',
          '📸 إضافة فيديو قصير قد يزيد المشاهدات',
        ],
        aiInsightsEn: [
          '⚠️ Sales down 25% — review product photos',
          '📉 Rating dropped — check recent reviews',
          '💡 Consider a temporary discount to attract buyers',
          '📸 Adding a short video may boost views',
        ],
      ),
      ProductMonthlyStats(
        productId: 'p3',
        productNameAr: 'لوحة خط عربي مؤطرة',
        productNameEn: 'Framed Arabic Calligraphy',
        productEmoji: '🖼️',
        month: 7,
        year: 2026,
        totalOrders: 9,
        prevMonthOrders: 7,
        totalRevenue: 315,
        prevMonthRevenue: 245,
        avgRating: 4.6,
        prevMonthRating: 4.4,
        totalViews: 180,
        rejectedOrders: 0,
        bestDayAr: 'الخميس',
        bestDayEn: 'Thursday',
        weeklyRevenue: [70, 85, 90, 70],
        aiInsightsAr: [
          '✅ لا يوجد أي طلب مرفوض — أداء مثالي!',
          '📈 نمو جيد بنسبة 28%',
          '💡 هذا المنتج مناسب للهدايا — روّج له في المناسبات',
          '🎯 الزبائن يبحثون عن تخصيص الأسماء — فكر فيها',
        ],
        aiInsightsEn: [
          '✅ Zero rejected orders — perfect performance!',
          '📈 Good growth at 28%',
          '💡 Great gift item — promote for occasions',
          '🎯 Customers want name customization — consider it',
        ],
      ),
    ];
  }

  // ── Admin Craftsman Reports (Dynamic Period) ──────────────────────────────
  static List<CraftsmanAdminStats> getAdminReports(String period) {
    // period: 'monthly', 'quarterly', 'annual'
    double multiplier = 1.0;
    if (period == 'monthly') multiplier = 1.0 / 12.0;
    if (period == 'quarterly') multiplier = 1.0 / 4.0;

    int scaleInt(int v) => (v * multiplier).ceil();
    double scaleDbl(double v) => v * multiplier;

    return [
      CraftsmanAdminStats(
        craftsmanId: 'c1',
        craftsmanName: 'خالد أبو النور',
        craftsmanCity: 'عمّان',
        craftAr: 'فخار وخزف',
        craftEn: 'Pottery & Ceramics',
        year: 2026,
        totalOrders: scaleInt(168),
        totalRevenue: scaleDbl(5040),
        avgRating: 4.7,
        totalReports: period == 'annual' ? 0 : 0,
        onTimeDeliveryRate: 96,
        bestMonthAr: 'ديسمبر',
        bestMonthEn: 'December',
        monthlyRevenue: [280, 320, 380, 400, 450, 490, 420, 380, 420, 460, 520, 520],
        badge: CraftsmanPerformanceBadge.gold,
        aiRecommendationAr: period == 'annual'
            ? '🤖 حرفي متميز ذو أداء استثنائي — يستحق شارة "موثوق ذهبي" ومكافأة سنوية'
            : '🤖 أداء استثنائي هذا ${period == "monthly" ? "الشهر" : "الربع"} — مرشح للمكافأة',
        aiRecommendationEn: period == 'annual'
            ? '🤖 Outstanding craftsman — deserves Gold Verified badge & annual reward'
            : '🤖 Outstanding performance this ${period == "monthly" ? "month" : "quarter"}',
        aiColor: Color(0xFFFFB300),
        aiIcon: Icons.emoji_events,
      ),
      CraftsmanAdminStats(
        craftsmanId: 'c2',
        craftsmanName: 'ليلى المراد',
        craftsmanCity: 'إربد',
        craftAr: 'خياطة وتطريز',
        craftEn: 'Embroidery & Sewing',
        year: 2026,
        totalOrders: scaleInt(94),
        totalRevenue: scaleDbl(2820),
        avgRating: 4.3,
        totalReports: period == 'annual' ? 1 : 0,
        onTimeDeliveryRate: 88,
        bestMonthAr: 'رمضان (مارس)',
        bestMonthEn: 'Ramadan (March)',
        monthlyRevenue: [140, 160, 380, 200, 220, 240, 180, 210, 230, 250, 280, 330],
        badge: CraftsmanPerformanceBadge.silver,
        aiRecommendationAr: '🤖 أداء جيد مع فرصة للتحسين — ينصح بتدريب على التسليم في الوقت',
        aiRecommendationEn: '🤖 Good performance with room to improve — recommend on-time delivery training',
        aiColor: Color(0xFF78909C),
        aiIcon: Icons.trending_up,
      ),
      CraftsmanAdminStats(
        craftsmanId: 'c3',
        craftsmanName: 'أحمد الشرقاوي',
        craftsmanCity: 'الزرقاء',
        craftAr: 'أعمال خشبية',
        craftEn: 'Woodworking',
        year: 2026,
        totalOrders: scaleInt(52),
        totalRevenue: scaleDbl(1560),
        avgRating: 3.8,
        totalReports: period == 'annual' ? 3 : (period == 'quarterly' ? 1 : 0),
        onTimeDeliveryRate: 74,
        bestMonthAr: 'يناير',
        bestMonthEn: 'January',
        monthlyRevenue: [200, 180, 140, 120, 110, 90, 130, 100, 110, 120, 130, 130],
        badge: CraftsmanPerformanceBadge.warning,
        aiRecommendationAr: '🤖 أداء متراجع مع بلاغات متعددة — يحتاج متابعة عاجلة ومراجعة الحساب',
        aiRecommendationEn: '🤖 Declining performance with multiple reports — needs urgent review & monitoring',
        aiColor: Color(0xFFE53935),
        aiIcon: Icons.warning_amber,
      ),
      CraftsmanAdminStats(
        craftsmanId: 'c4',
        craftsmanName: 'نور الهدى سالم',
        craftsmanCity: 'العقبة',
        craftAr: 'حلي ومجوهرات',
        craftEn: 'Jewelry & Accessories',
        year: 2026,
        totalOrders: scaleInt(121),
        totalRevenue: scaleDbl(3630),
        avgRating: 4.5,
        totalReports: 0,
        onTimeDeliveryRate: 92,
        bestMonthAr: 'أغسطس',
        bestMonthEn: 'August',
        monthlyRevenue: [200, 240, 280, 300, 320, 340, 420, 380, 310, 290, 280, 270],
        badge: CraftsmanPerformanceBadge.silver,
        aiRecommendationAr: '🤖 أداء ممتاز وثابت — يستحق الترقية لشارة ذهبية إذا استمر النمو',
        aiRecommendationEn: '🤖 Excellent steady performance — consider Gold badge if growth continues',
        aiColor: Color(0xFF43A047),
        aiIcon: Icons.star,
      ),
    ];
  }

  // ── Month names ──────────────────────────────────────────────────────────────
  static String monthName(int month, bool isAr) {
    const ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                 'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const en = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    return isAr ? ar[month - 1] : en[month - 1];
  }
}
