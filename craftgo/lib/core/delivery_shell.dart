import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../screens/delivery/delivery_dashboard_screen.dart';
import '../screens/delivery/delivery_orders_screen.dart';
import '../screens/delivery/delivery_earnings_screen.dart';
import '../screens/delivery/delivery_notifications_screen.dart';
import '../screens/delivery/delivery_profile_screen.dart';
import '../app_state.dart';

class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int _currentIndex = 0;

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
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final titles = [
      t('الرئيسية', 'Home'),
      t('الطلبات', 'Orders'),
      t('الأرباح', 'Earnings'),
      t('الإشعارات', 'Notifications'),
      t('الملف الشخصي', 'Profile'),
    ];

    final pages = [
      DeliveryDashboardScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
        onToggleLanguage: appState.toggleLanguage,
        onToggleTheme: appState.toggleTheme,
      ),
      const DeliveryOrdersScreen(),
      const DeliveryEarningsScreen(),
      const DeliveryNotificationsScreen(),
      DeliveryProfileScreen(
        isArabic: isArabic,
        isDarkMode: isDarkMode,
        onToggleLanguage: appState.toggleLanguage,
        onToggleTheme: appState.toggleTheme,
        deliveryName: appState.userName ?? 'سائق',
      ),
    ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          leadingWidth: 96,
          title: Text(
            'CraftGo',
            style: GoogleFonts.playfairDisplay(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _topBarButton(
                  icon: Icons.language,
                  label: isArabic ? 'EN' : 'عربي',
                  onTap: () => appState.toggleLanguage(),
                  color: text,
                  bg: surface,
                  border: Colors.black12,
                ),
                const SizedBox(width: 4),
                _topBarButton(
                  icon: isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: '',
                  onTap: () => appState.toggleTheme(),
                  color: text,
                  bg: surface,
                  border: Colors.black12,
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.black12),
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: surface,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: accent,
              unselectedItemColor: dim,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              selectedLabelStyle:
                  GoogleFonts.cairo(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.cairo(),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined, size: 24),
                  activeIcon: const Icon(Icons.home, size: 26),
                  label: titles[0],
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined, size: 24),
                  activeIcon: const Icon(Icons.receipt_long, size: 26),
                  label: titles[1],
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 24),
                  activeIcon:
                      const Icon(Icons.account_balance_wallet, size: 26),
                  label: titles[2],
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.notifications_outlined, size: 24),
                  activeIcon: const Icon(Icons.notifications, size: 26),
                  label: titles[3],
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline_rounded, size: 24),
                  activeIcon: const Icon(Icons.person_rounded, size: 26),
                  label: titles[4],
                ),
              ],
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
            Icon(icon, size: 14, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
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
