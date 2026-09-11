import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import '../../services/payment_service.dart';
import '../../services/api_service.dart';

class DeliveryEarningsScreen extends StatefulWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  State<DeliveryEarningsScreen> createState() => _DeliveryEarningsScreenState();
}

class _DeliveryEarningsScreenState extends State<DeliveryEarningsScreen> {
  String _selectedPeriod = 'Today';
  bool _isLoading = true;
  String? _errorMessage;

  // Real data state variables
  double _balance = 0.0;
  bool _hasStripeAccount = false;
  List<Map<String, dynamic>> _weeklyEarnings = [];
  List<Map<String, dynamic>> _breakdown = [];
  List<Map<String, dynamic>> _payoutHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEarningsData();
    });
  }

  Future<void> _fetchEarningsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final driverId = appState.userId ?? '';

    if (driverId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Driver ID not found.';
      });
      return;
    }

    final data = await DeliveryService.getEarnings(driverId);

    if (!mounted) return;

    if (data != null) {
      setState(() {
        _balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        _hasStripeAccount = data['hasStripeAccount'] == true;

        _weeklyEarnings = List<Map<String, dynamic>>.from(
          data['weeklyEarnings'] ?? [],
        );

        _breakdown = List<Map<String, dynamic>>.from(
          (data['breakdown'] as List? ?? []).map((e) => {
                'label': e['label'] ?? '',
                'labelEn': e['labelEn'] ?? '',
                'amount': (e['amount'] as num?)?.toDouble() ?? 0.0,
                'color': _parseColor(e['color']),
              }),
        );

        _payoutHistory = List<Map<String, dynamic>>.from(
          data['payoutHistory'] ?? [],
        );

        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = context.read<AppState>().isArabic
            ? 'فشل في تحميل بيانات الأرباح'
            : 'Failed to load earnings data.';
      });
    }
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      final hex = colorValue.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return const Color(0xFFD4A017);
  }

  // ── Theme helpers ─────────────────────────────────────────────────
  Color get bg => context.watch<AppState>().isDarkMode
      ? const Color(0xFF0D1420)
      : const Color(0xFFF5F6F8);
  Color get surface => context.watch<AppState>().isDarkMode
      ? const Color(0xFF1C2431)
      : Colors.white;
  Color get text =>
      context.watch<AppState>().isDarkMode ? Colors.white : Colors.black87;
  Color get dim =>
      context.watch<AppState>().isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => context.watch<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);
  Color get accentDark => const Color(0xFFB8860B);

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppState>().isArabic;
    final isDarkMode = context.watch<AppState>().isDarkMode;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            t('الأرباح', 'Earnings'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: text),
              onPressed: _fetchEarningsData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : RefreshIndicator(
                    onRefresh: _fetchEarningsData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWalletCard(isArabic, isDarkMode),
                          const SizedBox(height: 24),
                          _buildPeriodToggle(isArabic),
                          const SizedBox(height: 16),
                          _buildEarningsChart(isArabic, isDarkMode),
                          const SizedBox(height: 24),
                          _buildEarningsBreakdown(isArabic, isDarkMode),
                          const SizedBox(height: 24),
                          _buildPayoutHistory(isArabic, isDarkMode),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: GoogleFonts.cairo(color: text)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchEarningsData,
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: Text(t('إعادة المحاولة', 'Retry'),
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(bool isArabic, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.2),
            accent.withValues(alpha: 0.05)
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('المحفظة', 'Wallet'),
                style: GoogleFonts.cairo(color: dim, fontSize: 14),
              ),
              Icon(Icons.account_balance_wallet_rounded,
                  color: accent, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₪ ${_balance.toStringAsFixed(2)}',
            style: GoogleFonts.cairo(
              color: accent,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            t('الرصيد المتاح للسحب', 'Available Balance'),
            style: GoogleFonts.cairo(color: dim, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (!_hasStripeAccount)
            ElevatedButton.icon(
              onPressed: () async {
                final launched = await PaymentService.openPayoutOnboarding();
                if (!launched && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تعذر فتح صفحة ربط حساب Stripe',
                          'Could not open Stripe account linking')),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تم فتح صفحة ربط حساب Stripe',
                          'Stripe account linking page opened')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(
                t('ربط حساب Stripe', 'Link Stripe Account'),
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showPayoutDialog(context, isArabic, isDarkMode),
              icon: const Icon(Icons.arrow_circle_down_rounded, size: 18),
              label: Text(
                t('سحب الرصيد', 'Request Payout'),
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle(bool isArabic) {
    final periods = ['Today', 'Week', 'Month'];
    final labels = isArabic
        ? ['اليوم', 'هذا الأسبوع', 'هذا الشهر']
        : ['Today', 'This Week', 'This Month'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == periods[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = periods[index]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: isSelected ? Colors.black : dim,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEarningsChart(bool isArabic, bool isDarkMode) {
    final double maxAmount = _weeklyEarnings.fold(
        0.0,
        (max, e) => (e['amount'] as num).toDouble() > max
            ? (e['amount'] as num).toDouble()
            : max);

    return Container(
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
            t('الأرباح اليومية', 'Daily Earnings'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _weeklyEarnings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                        t('لا توجد بيانات متاحة', 'No chart data available'),
                        style: GoogleFonts.cairo(color: dim)),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklyEarnings.map((item) {
                    final day = item['day']?.toString() ?? '';
                    final double amount =
                        (item['amount'] as num?)?.toDouble() ?? 0.0;
                    final double height =
                        maxAmount > 0 ? (amount / maxAmount) * 80 : 0;

                    return Column(
                      children: [
                        Text(
                          '₪${amount.toStringAsFixed(0)}',
                          style: GoogleFonts.cairo(color: dim, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: height + 10,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent, accentDark],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day,
                          style: GoogleFonts.cairo(color: dim, fontSize: 11),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdown(bool isArabic, bool isDarkMode) {
    double netTotal = 0;
    for (var item in _breakdown) {
      netTotal += (item['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Container(
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
            t('تفاصيل الأرباح', 'Earnings Breakdown'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._breakdown.map((item) {
            final label = isArabic
                ? (item['label'] ?? '')
                : (item['labelEn'] ?? item['label'] ?? '');
            final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            final color = item['color'] as Color? ?? accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.cairo(color: text, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    amount >= 0
                        ? '+₪${amount.toStringAsFixed(2)}'
                        : '-₪${amount.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.cairo(
                      color: amount >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: Colors.grey),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('صافي الأرباح', 'Net Earnings'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₪${netTotal.toStringAsFixed(2)}',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutHistory(bool isArabic, bool isDarkMode) {
    return Container(
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
            t('سجل السحوبات', 'Payout History'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (_payoutHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t('لا يوجد سجل سحوبات سابق', 'No payout history found'),
                style: GoogleFonts.cairo(color: dim, fontSize: 12),
              ),
            )
          else
            ..._payoutHistory.map((item) {
              final statusRaw = item['status']?.toString() ?? 'Pending';
              final status = isArabic
                  ? statusRaw == 'Completed'
                      ? 'مكتمل'
                      : 'قيد المعالجة'
                  : statusRaw;
              final statusColor =
                  statusRaw == 'Completed' ? Colors.green : Colors.amber;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['date']?.toString() ?? '',
                          style: GoogleFonts.cairo(color: dim, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.cairo(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₪${item['amount']}',
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────

  void _showPayoutDialog(BuildContext context, bool isArabic, bool isDarkMode) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t('سحب الرصيد', 'Request Payout'),
          style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('أدخل المبلغ الذي تريد سحبه',
                  'Enter the amount you want to withdraw'),
              style: GoogleFonts.cairo(color: dim, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: dim),
                prefixIcon: Icon(Icons.attach_money, color: accent),
                filled: true,
                fillColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('الرصيد المتاح: ₪${_balance.toStringAsFixed(2)}',
                  'Available: ₪${_balance.toStringAsFixed(2)}'),
              style: GoogleFonts.cairo(color: dim, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          // Stripe Onboarding button (if not onboarded)
          if (!_hasStripeAccount)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final launched = await PaymentService.openPayoutOnboarding();
                if (!launched && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('تعذر فتح صفحة ربط حساب Stripe',
                          'Could not open Stripe account linking')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(t('ربط حساب Stripe', 'Link Stripe Account')),
            ),
          // Confirm Payout button (only if onboarded)
          if (_hasStripeAccount)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final amountStr = amountCtrl.text.trim();
                final amount = double.tryParse(amountStr);
                if (amount == null || amount <= 0 || amount > _balance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('الرجاء إدخال مبلغ صحيح',
                          'Please enter a valid amount')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close dialog
                Navigator.pop(ctx);

                // Call payout API
                try {
                  final response =
                      await ApiService.post('/delivery/payout/request', body: {
                    'driverId': context.read<AppState>().userId,
                    'amount': amount,
                  });
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('تم السحب بنجاح', 'Payout successful')),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchEarningsData(); // refresh balance
                  } else {
                    final error = jsonDecode(response.body);
                    if (error['onboardRequired']) {
                      // Open Stripe onboarding
                      final launched =
                          await PaymentService.openPayoutOnboarding();
                      if (!launched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('تعذر فتح صفحة الإعداد',
                                'Could not open onboarding')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      throw Exception(error['error'] ?? 'Payout failed');
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('فشل السحب: $e', 'Payout failed: $e')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                t('تأكيد', 'Confirm'),
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
