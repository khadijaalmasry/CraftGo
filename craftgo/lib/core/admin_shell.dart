import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_verifications_screen.dart';
import '../screens/admin/admin_exhibition_screen.dart';
import '../screens/admin/admin_delivery_operations_screen.dart';
import '../screens/admin/admin_disputes_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final Color _gold = const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final backgroundColor =
        isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;

    final screens = [
      AdminDashboard(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      AdminUsersScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
      ),
      AdminVerificationsScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
      ),
      AdminExhibitionScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
      ),
      AdminDeliveryOperationsScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
      ),
      AdminDisputesScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
      ),
    ];

    final labels = [
      isArabic ? 'الرئيسية' : 'Dashboard',
      isArabic ? 'المستخدمين' : 'Users',
      isArabic ? 'التوثيق' : 'Verifications',
      isArabic ? 'المعارض' : 'Exhibitions',
      isArabic ? 'التوصيل' : 'Delivery',
      isArabic ? 'النزاعات' : 'Disputes',
    ];

    final icons = [
      Icons.dashboard_outlined,
      Icons.people_outline,
      Icons.verified_user_outlined,
      Icons.storefront_outlined,
      Icons.local_shipping_outlined,
      Icons.gavel_outlined,
    ];

    final activeIcons = [
      Icons.dashboard_rounded,
      Icons.people_rounded,
      Icons.verified_user_rounded,
      Icons.storefront_rounded,
      Icons.local_shipping_rounded,
      Icons.gavel_rounded,
    ];

    Widget buildMobileLayout() {
      return Directionality(
        textDirection: direction,
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: backgroundColor.withValues(alpha: 0.85),
                  padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logout button
                        _topBarButton(
                          icon: Icons.logout_rounded,
                          label: isArabic ? 'خروج' : 'Logout',
                          onTap: () =>
                              _showLogoutDialog(context, isArabic, isDarkMode),
                          color: Colors.red,
                          bg: surface,
                          border: Colors.black12,
                        ),
                        // App Title
                        Text(
                          "CraftGo",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _gold,
                          ),
                        ),
                        // Language & Theme Toggles
                        Row(
                          children: [
                            _topBarButton(
                              icon: Icons.language,
                              label: isArabic ? "EN" : "عربي",
                              onTap: () => appState.toggleLanguage(),
                              color: primaryTextColor,
                              bg: surface,
                              border: Colors.black12,
                            ),
                            const SizedBox(width: 8),
                            _topBarButton(
                              icon: isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              label: "",
                              onTap: () => appState.toggleTheme(),
                              color: primaryTextColor,
                              bg: surface,
                              border: Colors.black12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (idx) => setState(() => _currentIndex = idx),
                backgroundColor: backgroundColor,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _gold,
                unselectedItemColor: secondaryTextColor,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: isArabic ? 'Cairo' : null,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 10,
                  fontFamily: isArabic ? 'Cairo' : null,
                ),
                items: List.generate(6, (i) {
                  return BottomNavigationBarItem(
                    icon: Icon(icons[i], size: 22),
                    activeIcon: Icon(activeIcons[i], size: 24),
                    label: labels[i],
                  );
                }),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildDesktopLayout() {
      return Directionality(
        textDirection: direction,
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Row(
            children: [
              // Sidebar Navigation
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(
                    right: isArabic
                        ? BorderSide.none
                        : BorderSide(
                            color: isDarkMode ? Colors.white12 : Colors.black12),
                    left: isArabic
                        ? BorderSide(
                            color: isDarkMode ? Colors.white12 : Colors.black12)
                        : BorderSide.none,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "CraftGo",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          isArabic ? 'لوحة الإدارة' : 'Admin Panel',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(
                          height: 1,
                          color: isDarkMode ? Colors.white12 : Colors.black12),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: labels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final selected = _currentIndex == index;
                            return ListTile(
                              leading: Icon(
                                selected ? activeIcons[index] : icons[index],
                                color: selected ? _gold : secondaryTextColor,
                                size: 22,
                              ),
                              title: Text(
                                labels[index],
                                style: GoogleFonts.cairo(
                                  color: selected ? _gold : primaryTextColor,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              selected: selected,
                              selectedTileColor:
                                  _gold.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onTap: () =>
                                  setState(() => _currentIndex = index),
                            );
                          },
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: isDarkMode ? Colors.white12 : Colors.black12),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _topBarButton(
                                  icon: Icons.language,
                                  label: isArabic ? "EN" : "عربي",
                                  onTap: () => appState.toggleLanguage(),
                                  color: primaryTextColor,
                                  bg: backgroundColor,
                                  border: Colors.black12,
                                ),
                                _topBarButton(
                                  icon: isDarkMode
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  label: "",
                                  onTap: () => appState.toggleTheme(),
                                  color: primaryTextColor,
                                  bg: backgroundColor,
                                  border: Colors.black12,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.3)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.logout_rounded,
                                    size: 16),
                                label: Text(
                                  isArabic ? 'تسجيل الخروج' : 'Logout',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () => _showLogoutDialog(
                                    context, isArabic, isDarkMode),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Body
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return buildDesktopLayout();
        } else {
          return buildMobileLayout();
        }
      },
    );
  }

  void _showLogoutDialog(BuildContext context, bool isArabic, bool isDarkMode) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1C2431) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isArabic ? 'تسجيل الخروج' : 'Sign Out',
                      style: GoogleFonts.cairo(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'هل أنت متأكد من رغبتك بالخروج من لوحة الإدارة؟'
                          : 'Are you sure you want to exit the Admin panel?',
                      style: GoogleFonts.cairo(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white24
                                      : Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              isArabic ? 'إلغاء' : 'Cancel',
                              style: GoogleFonts.cairo(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.read<AppState>().logout();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/onboarding',
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              isArabic ? 'تأكيد الخروج' : 'Confirm',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    final buttonColor = color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: buttonColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: buttonColor,
                  fontSize: 10,
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
