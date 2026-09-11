// lib/screens/auth/login_role_selection.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../main.dart'; // for OnboardingScreen
import '../screens/admin/admin_login_screen.dart';

class LoginRoleSelectionScreen extends StatelessWidget {
  const LoginRoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final userRoles = appState.roles;

    if (userRoles.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8),
        body: Center(
          child: Text(
            isArabic ? 'لا توجد أدوار متاحة' : 'No roles available',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      );
    }

    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    String t(String ar, String en) => isArabic ? ar : en;

    final Map<String, Map<String, dynamic>> roleData = {
      'customer': {
        'icon': Icons.shopping_bag_outlined,
        'title': t('زبون', 'Customer'),
        'description': t(
          'تسوّق الحرف اليدوية، اطلب منتجات مخصصة، واستأجر حرفيين',
          'Shop handcrafts, order custom products, and hire artisans',
        ),
      },
      'artisan': {
        'icon': Icons.handyman_outlined,
        'title': t('حرفي', 'Artisan'),
        'description': t(
          'اعرض منتجاتك، استقبل طلبات مخصصة، وشارك في المعارض',
          'Showcase your products, accept custom orders, and join exhibitions',
        ),
      },
      'delivery': {
        'icon': Icons.local_shipping_outlined,
        'title': t('مندوب توصيل', 'Delivery'),
        'description': t(
          'أدِر رحلات التوصيل الخاصة بك وسلّم طلبات الحرفيين للزبائن',
          'Manage your delivery trips and deliver artisans\' orders to customers',
        ),
      },
      'exhibition_owner': {
        'icon': Icons.museum_outlined,
        'title': t('منظم معارض', 'Exhibition Owner'),
        'description': t(
          'أنشئ المعارض، أدر الحرفيين المشاركين، وتابع الطلبات',
          'Create exhibitions, manage participating artisans, and track requests',
        ),
      },
      'admin': {
        'icon': Icons.admin_panel_settings_outlined,
        'title': t('مدير', 'Admin'),
        'description': t(
          'أدر المستخدمين، تحقق من الحرفيين، وحل النزاعات',
          'Manage users, verify artisans, and resolve disputes',
        ),
      },
    };

    final filteredRoleKeys =
        userRoles.where((role) => roleData.containsKey(role)).toList();

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          title: Text(
            t('اختر دورك', 'Choose Your Role'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: text),
            onPressed: () {
              // Navigate to OnboardingScreen and clear the stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            return Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('مرحباً ${appState.userName}!',
                          'Welcome ${appState.userName}!'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'اختر الدور الذي تريد استخدامه الآن. يمكنك التبديل لاحقاً.',
                        'Choose the role you want to use now. You can switch later.',
                      ),
                      style: TextStyle(color: dim, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: isDesktop
                          ? GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.3,
                              ),
                              itemCount: filteredRoleKeys.length,
                              itemBuilder: (context, index) {
                                final role = filteredRoleKeys[index];
                                final data = roleData[role]!;
                                return _LoginRoleCard(
                                  icon: data['icon'],
                                  title: data['title'],
                                  description: data['description'],
                                  isSelected: appState.activeRole == role,
                                  isArabic: isArabic,
                                  onTap: () {
                                    if (role == 'admin') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminLoginScreen(
                                            isArabic: isArabic,
                                            isDarkMode: isDarkMode,
                                            onToggleLanguage: () =>
                                                appState.toggleLanguage(),
                                            onToggleTheme: () =>
                                                appState.toggleTheme(),
                                          ),
                                        ),
                                      );
                                    } else {
                                      appState.setActiveRole(role);
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              appState.getShellForActiveRole(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                );
                              },
                            )
                          : ListView.separated(
                              itemCount: filteredRoleKeys.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final role = filteredRoleKeys[index];
                                final data = roleData[role]!;
                                return _LoginRoleCard(
                                  icon: data['icon'],
                                  title: data['title'],
                                  description: data['description'],
                                  isSelected: appState.activeRole == role,
                                  isArabic: isArabic,
                                  onTap: () {
                                    if (role == 'admin') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminLoginScreen(
                                            isArabic: isArabic,
                                            isDarkMode: isDarkMode,
                                            onToggleLanguage: () =>
                                                appState.toggleLanguage(),
                                            onToggleTheme: () =>
                                                appState.toggleTheme(),
                                          ),
                                        ),
                                      );
                                    } else {
                                      appState.setActiveRole(role);
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              appState.getShellForActiveRole(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        appState.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OnboardingScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        t('تسجيل الخروج', 'Logout'),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginRoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool isArabic;
  final VoidCallback onTap;

  const _LoginRoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: isSelected ? accent : text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      color: dim,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? accent : border,
                  width: 1,
                ),
              ),
              child: Text(
                isSelected ? '✓' : (isArabic ? 'اختر' : 'Select'),
                style: TextStyle(
                  color: isSelected ? Colors.black : accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
