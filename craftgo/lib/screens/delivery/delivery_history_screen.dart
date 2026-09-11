import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/delivery_service.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  final String driverId;
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;

  const DeliveryHistoryScreen({
    super.key,
    required this.driverId,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
  });

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _historyData = [];

  // Dynamic Stats
  String _weeklyEarnings = '₪ 0';
  String _totalDeliveries = '0';
  String _totalDistance = '0 km';

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch delivered/completed orders and earnings stats in parallel
      final results = await Future.wait([
        DeliveryService.getDriverOrders(widget.driverId, status: 'delivered'),
        DeliveryService.getEarnings(widget.driverId),
      ]);

      final orders = results[0] as List<dynamic>;
      final earningsData = results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _historyData = orders;
          if (earningsData != null) {
            _weeklyEarnings =
                '₪ ${earningsData['weeklyEarnings'] ?? earningsData['totalEarnings'] ?? 0}';
            _totalDeliveries =
                '${earningsData['completedDeliveries'] ?? orders.length}';
            _totalDistance = '${earningsData['totalDistance'] ?? 0} km';
          } else {
            _totalDeliveries = '${orders.length}';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isArabic;
    final isDark = widget.isDarkMode;

    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F6F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark ? const Color(0x66FFFFFF) : const Color(0xFF999999);
    final cardBg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final cardBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
    final highlight = const Color(0xFFD4A017);
    final success = Colors.greenAccent.shade400;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isAr ? 'السجل (History)' : 'History',
          style: GoogleFonts.cairo(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          _topBarButton(
            icon: Icons.language,
            label: isAr ? "EN" : "عربي",
            onTap: widget.onToggleLanguage,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _topBarButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            label: "",
            onTap: widget.onToggleTheme,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistoryData,
          child: Column(
            children: [
              // Stats Row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        title: isAr ? 'هذا الأسبوع' : 'This Week',
                        value: _weeklyEarnings,
                        icon: Icons.account_balance_wallet,
                        color: highlight,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        title: isAr ? 'المشاوير' : 'Deliveries',
                        value: _totalDeliveries,
                        icon: Icons.local_shipping,
                        color: Colors.blueAccent,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        title: isAr ? 'المسافة' : 'Distance',
                        value: _totalDistance,
                        icon: Icons.map,
                        color: success,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _historyData.isEmpty
                        ? Center(
                            child: Text(
                              isAr
                                  ? 'لا يوجد سجل طلبات'
                                  : 'No order history found',
                              style: GoogleFonts.cairo(color: subColor),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _historyData.length,
                            itemBuilder: (context, index) {
                              final item = _historyData[index];
                              final orderId = item['id']?.toString() ?? '';
                              final shortId = orderId.length > 8
                                  ? orderId.substring(0, 8)
                                  : orderId;
                              final date =
                                  item['createdAt'] ?? item['date'] ?? '';
                              final earnings = item['totalAmount'] != null
                                  ? '+${item['totalAmount']} ₪'
                                  : (item['earnings'] ?? '0 ₪');
                              final rating =
                                  item['rating']?.toString() ?? '5.0';
                              final shopName = item['craftsman']?['name'] ??
                                  item['shop'] ??
                                  'Craft Shop';
                              final customerName = item['customer']?['name'] ??
                                  item['customer'] ??
                                  'Customer';
                              final distance = item['distance'] ?? '1.0 km';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          date,
                                          style: GoogleFonts.cairo(
                                              color: subColor, fontSize: 12),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                success.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            earnings,
                                            style: GoogleFonts.cairo(
                                                color: success,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '#$shortId',
                                          style: GoogleFonts.cairo(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating,
                                              style: GoogleFonts.cairo(
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(
                                        height: 24, color: Colors.white10),
                                    Row(
                                      children: [
                                        Icon(Icons.storefront,
                                            color: subColor, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          shopName,
                                          style: GoogleFonts.cairo(
                                              color: textColor, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline,
                                            color: subColor, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          customerName,
                                          style: GoogleFonts.cairo(
                                              color: textColor, fontSize: 13),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.directions_car_outlined,
                                            color: subColor, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          distance,
                                          style: GoogleFonts.cairo(
                                              color: subColor, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(color: subColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

Widget _topBarButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2431) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black87),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
