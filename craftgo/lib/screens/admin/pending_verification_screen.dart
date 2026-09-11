import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/craftsman_shell.dart';

class PendingVerificationScreen extends StatelessWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final Map<String, dynamic> selectedCategory;

  const PendingVerificationScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.selectedCategory,
  });

  Color get backgroundColor =>
      isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black54;
  Color get topButtonBackground =>
      isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get chipBorderColor => isDarkMode ? Colors.white12 : Colors.black12;
  Color get topIconColor => isDarkMode ? Colors.white : Colors.black87;

  @override
  Widget build(BuildContext context) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _topBarButton(
                          icon: Icons.language,
                          label: isArabic ? "EN" : "عربي",
                          onTap: onToggleLanguage,
                        ),
                        const SizedBox(width: 10),
                        _topBarButton(
                          icon: isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: "",
                          onTap: onToggleTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A017).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hourglass_bottom,
                          size: 60,
                          color: Color(0xFFD4A017),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Title
                      Text(
                        isArabic
                            ? "حسابك قيد المراجعة"
                            : "Account Pending Verification",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.arefRuqaa(
                          color: primaryTextColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Message
                      Text(
                        isArabic
                            ? "شكراً لتسجيلك معنا! الإدارة تقوم حالياً بمراجعة ملفك وأعمالك، وإذا طلبت شارة الأيدي الموثوقة فسيتم أيضاً مراجعة الهوية. ستصلك رسالة عند تفعيل الحساب."
                            : "Thank you for registering! Our admins are reviewing your profile and portfolio. If you requested Trusted Hands, your ID will also be reviewed. You will be notified once your account is activated.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A017).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFD4A017,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Color(0xFFD4A017),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isArabic
                                  ? "عادة ما تستغرق المراجعة 24-48 ساعة"
                                  : "Usually takes 24-48 hours",
                              style: const TextStyle(
                                color: Color(0xFFD4A017),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Button to go to Dashboard (Empty State)
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF7B500,
                              ).withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 1,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CraftsmanShell(
                                  isArabic: isArabic,
                                  isDarkMode: isDarkMode,
                                  onToggleLanguage: onToggleLanguage,
                                  onToggleTheme: onToggleTheme,
                                  // The shell/dashboard load the logged-in artisan's
                                  // real data from the current session/backend.
                                  // Do not inject fake profile information here.
                                  craftsmanName: '',
                                  craftsmanCategoryAr:
                                  selectedCategory['titleAr'] ?? 'حرفي',
                                  craftsmanCategoryEn:
                                  selectedCategory['titleEn'] ?? 'Craftsman',
                                  craftsmanCity: '',
                                  craftsmanBio: '',
                                  craftsmanExperience: '',
                                  verificationStatus: 'pending_review',
                                  isVerified: false,
                                  isPending: true,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            isArabic
                                ? "استكشف لوحة التحكم"
                                : "Explore Dashboard",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: topButtonBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: topIconColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: topIconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
