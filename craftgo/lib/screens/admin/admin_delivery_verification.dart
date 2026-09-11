import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart'; // adjust path as needed

class AdminDeliveryVerificationScreen extends StatelessWidget {
  const AdminDeliveryVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>(); // ظ£à use Provider
    final isAr = appState.isArabic;
    final isDark = appState.isDarkMode;

    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F6F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final cardBg = isDark ? const Color(0x0DFFFFFF) : Colors.white;
    final cardBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFFE8B84B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? '╪ز┘é┘è┘è┘à ╪╖┘╪ذ ┘à┘╪»┘ê╪ذ ╪ز┘ê╪╡┘è┘' : 'Delivery Application',
          style: TextStyle(
              color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Profile Summary
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cardBg,
                  backgroundImage:
                      const NetworkImage('https://i.pravatar.cc/150?img=11'),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('╪ث╪ص┘à╪» ╪د┘┘à┘╪»┘ê╪ذ',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('╪د┘╪│┘è╪د╪▒╪ر: Toyota Prius 2018',
                        style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 30),

            // AI Trust Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.green.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology,
                              color: Colors.green, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            isAr
                                ? '┘╪│╪ذ╪ر ╪د┘╪س┘é╪ر ╪د┘┘à╪»╪╣┘ê┘à╪ر ╪ذ╪د┘┘ AI'
                                : 'AI Trust Score',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        '96%',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.96,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: Colors.green,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 20),
                  _TrustFactorRow(
                      isAr: isAr,
                      isDark: isDark,
                      title:
                          isAr ? '┘à╪╖╪د╪ذ┘é╪ر ╪د┘┘ê╪ش┘ç ┘à╪╣ ╪د┘┘ç┘ê┘è╪ر' : 'Face to ID Match',
                      isGood: true),
                  _TrustFactorRow(
                      isAr: isAr,
                      isDark: isDark,
                      title: isAr ? '╪╡┘╪د╪ص┘è╪ر ╪▒╪«╪╡╪ر ╪د┘┘é┘è╪د╪»╪ر' : 'License Validity',
                      isGood: true),
                  _TrustFactorRow(
                      isAr: isAr,
                      isDark: isDark,
                      title: isAr ? '╪د┘╪│╪ش┘ ╪د┘╪ث┘à┘┘è' : 'Security Record Check',
                      isGood: true),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isAr
                          ? '╪ز┘ê╪╡┘è╪ر ╪د┘╪░┘â╪د╪ة ╪د┘╪د╪╡╪╖┘╪د╪╣┘è: "╪د┘┘à┘╪»┘ê╪ذ ┘à┘ê╪س┘ê┘é ╪ش╪»╪د┘ï ┘ê╪ز┘à ╪د┘╪ز╪ث┘â╪» ┘à┘ ╪ش┘à┘è╪╣ ╪ث┘ê╪▒╪د┘é┘ç ╪ذ┘╪ش╪د╪ص. ┘è┘┘╪╡╪ص ╪ذ╪د┘┘à┘ê╪د┘┘é╪ر."'
                          : 'AI Recommendation: "Driver is highly trustworthy. All documents verified. Approval Recommended."',
                      style: const TextStyle(
                          color: Colors.green, fontSize: 13, height: 1.5),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isAr ? '╪▒┘╪╢' : 'Reject',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isAr
                                ? '╪ز┘à ╪د┘┘à┘ê╪د┘┘é╪ر ╪╣┘┘ë ╪د┘┘à┘╪»┘ê╪ذ ╪ذ┘╪ش╪د╪ص!'
                                : 'Driver Approved Successfully!')),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isAr ? '┘à┘ê╪د┘┘é╪ر' : 'Approve',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ظ¤ظ¤ Trust Factor Row (unchanged) ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤ظ¤
class _TrustFactorRow extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final String title;
  final bool isGood;

  const _TrustFactorRow({
    required this.isAr,
    required this.isDark,
    required this.title,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            color: isGood ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
