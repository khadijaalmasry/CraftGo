import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../screens/customer/client_dashboard.dart';
import '../screens/customer/client_profile.dart';
import '../screens/customer/chat_inbox_screen.dart';
import '../screens/customer/my_orders_screen.dart';
import '../screens/customer/ai_order_screen.dart';
import '../widgets/customer_login_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/notifications_screen.dart';
import '../screens/customer/favorites_screen.dart';
import '../services/session_service.dart';

class MainShell extends StatefulWidget {
  final bool isGuest;
  final String? userName;

  const MainShell({
    super.key,
    this.isGuest = false,
    this.userName,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _verifySessionBeforeShowingShell();
  }

  Future<void> _verifySessionBeforeShowingShell() async {
    if (widget.isGuest) {
      if (mounted) setState(() => _checkingSession = false);
      return;
    }

    final isLoggedIn = await SessionService.hasValidSession();
    if (!mounted) return;

    if (!isLoggedIn) {
      context.read<AppState>().logout();
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/onboarding',
        (route) => false,
      );
      return;
    }

    setState(() => _checkingSession = false);
  }

  bool get _isArabic => context.watch<AppState>().isArabic;
  bool get _isDarkMode => context.watch<AppState>().isDarkMode;

  void _toggleLanguage() => context.read<AppState>().toggleLanguage();
  void _toggleTheme() => context.read<AppState>().toggleTheme();

  static const Color _gold = Color(0xFFFFD700);
  static const Color _navy = Color(0xFF0D1B33);

  Color get _bg =>
      _isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get _surface => _isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get _primaryText => _isDarkMode ? Colors.white : Colors.black87;
  Color get _border => _isDarkMode ? Colors.white12 : Colors.black12;
  Color get _accent => _isDarkMode ? _gold : _navy;
  Color get _unselected => _isDarkMode ? Colors.white38 : Colors.black38;

  List<Map<String, dynamic>> get _navItems => [
        {
          'icon': Icons.home_rounded,
          'label': _isArabic ? 'الرئيسية' : 'Home',
        },
        {
          'icon': Icons.auto_awesome_rounded,
          'label': _isArabic ? 'AI بحث' : 'AI Search',
        },
        {
          'icon': Icons.receipt_long_rounded,
          'label': _isArabic ? 'طلباتي' : 'Orders',
        },
        {
          'icon': Icons.chat_bubble_outline_rounded,
          'label': _isArabic ? 'الرسائل' : 'Chats',
        },
        {
          'icon': Icons.person_outline_rounded,
          'label': _isArabic ? 'حسابي' : 'Profile',
        },
      ];

  List<Widget> get _pages => [
        ClientDashboard(
          isArabic: _isArabic,
          isDarkMode: _isDarkMode,
          onToggleLanguage: _toggleLanguage,
          onToggleTheme: _toggleTheme,
          isGuest: widget.isGuest,
        ),
        widget.isGuest
            ? _buildLoginRequiredView(Icons.auto_awesome, _navItems[1]['label'])
            : AIOrderScreen(
                isArabic: _isArabic,
                isDarkMode: _isDarkMode,
              ),
        widget.isGuest
            ? _buildLoginRequiredView(Icons.receipt_long, _navItems[2]['label'])
            : MyOrdersScreen(
                isArabic: _isArabic,
                isDarkMode: _isDarkMode,
              ),
        widget.isGuest
            ? _buildLoginRequiredView(
                Icons.chat_bubble_outline, _navItems[3]['label'])
            : ChatInboxScreen(
                isArabic: _isArabic,
                isDarkMode: _isDarkMode,
              ),
        widget.isGuest
            ? _buildLoginRequiredView(
                Icons.person_outline, _navItems[4]['label'])
            : CustomerProfileScreen(
                isArabic: _isArabic,
                isDarkMode: _isDarkMode,
                onToggleLanguage: _toggleLanguage,
                onToggleTheme: _toggleTheme,
                userName: widget.userName ?? 'User',
              ),
      ];

  Widget _buildLoginRequiredView(IconData icon, String title) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 60, color: _accent),
              ),
              const SizedBox(height: 24),
              Text(
                _isArabic ? "ميزة للأعضاء فقط" : "Members Only Feature",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isArabic
                    ? "يرجى تسجيل الدخول للوصول إلى هذه الميزة والاستمتاع بكامل خدمات CraftGo."
                    : "Please log in to access this feature and enjoy all CraftGo services.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: _primaryText.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerLoginScreen(),
                      ),
                    );
                  },
                  child: Text(
                    _isArabic ? "تسجيل الدخول" : "Login Now",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestPromptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isArabic ? 'تنبيه' : 'Notice',
          style: TextStyle(color: _primaryText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _isArabic
              ? 'يرجى تسجيل الدخول للوصول إلى هذه الميزة.'
              : 'Please log in to access this feature.',
          style: TextStyle(color: _primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: _primaryText.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerLoginScreen(),
                ),
              );
            },
            child: Text(
              _isArabic ? 'تسجيل الدخول' : 'Login',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- MOBILE LAYOUT (unchanged) ----------
  Widget _buildMobileLayout() {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  // ---------- DESKTOP LAYOUT (sidebar) ----------
  Widget _buildDesktopLayout() {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: Row(
            children: [
              // Sidebar
              Container(
                width: 220,
                color: _surface,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Logo / Brand
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          'CraftGo',
                          style: GoogleFonts.playfairDisplay(
                            color: _accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      Divider(color: _border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _navItems.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 4, color: Colors.transparent),
                          itemBuilder: (context, index) {
                            final item = _navItems[index];
                            final selected = _currentIndex == index;
                            return ListTile(
                              leading: Icon(
                                item['icon'],
                                color: selected ? _accent : _unselected,
                              ),
                              title: Text(
                                item['label'],
                                style: TextStyle(
                                  color: selected ? _accent : _primaryText,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: selected,
                              selectedTileColor: _accent.withValues(alpha: 0.1),
                              onTap: () =>
                                  setState(() => _currentIndex = index),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                      ),
                      // Theme/Language buttons at bottom (optional)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _topBarButton(
                              icon: Icons.language,
                              label: _isArabic ? 'EN' : 'عربي',
                              onTap: _toggleLanguage,
                              color: _primaryText,
                              bg: _surface,
                              border: _border,
                            ),
                            _topBarButton(
                              icon: _isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              label: '',
                              onTap: _toggleTheme,
                              color: _primaryText,
                              bg: _surface,
                              border: _border,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- SHARED APP BAR ----------
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 96,
      title: Text(
        'CraftGo',
        style: GoogleFonts.playfairDisplay(
          color: _accent,
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
              label: _isArabic ? 'EN' : 'عربي',
              onTap: _toggleLanguage,
              color: _primaryText,
              bg: _surface,
              border: _border,
            ),
            const SizedBox(width: 4),
            _topBarButton(
              icon: _isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              label: '',
              onTap: _toggleTheme,
              color: _primaryText,
              bg: _surface,
              border: _border,
            ),
          ],
        ),
      ),
      actions: [
        _iconButton(
          icon: Icons.favorite_border_rounded,
          onTap: () {
            if (widget.isGuest) {
              _showGuestPromptDialog();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritesScreen(
                    isArabic: _isArabic,
                    isDarkMode: _isDarkMode,
                  ),
                ),
              );
            }
          },
          color: _primaryText,
          bg: _surface,
          border: _border,
        ),
        const SizedBox(width: 4),
        _iconButton(
          icon: Icons.shopping_cart_outlined,
          onTap: () {
            if (widget.isGuest) {
              _showGuestPromptDialog();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                    isArabic: _isArabic,
                    isDarkMode: _isDarkMode,
                  ),
                ),
              );
            }
          },
          color: _primaryText,
          bg: _surface,
          border: _border,
        ),
        const SizedBox(width: 4),
        Stack(
          children: [
            _iconButton(
              icon: Icons.notifications_none_rounded,
              onTap: () {
                if (widget.isGuest) {
                  _showGuestPromptDialog();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                        isArabic: _isArabic,
                        isDarkMode: _isDarkMode,
                      ),
                    ),
                  );
                }
              },
              color: _primaryText,
              bg: _surface,
              border: _border,
              showBadge: true,
            ),
          ],
        ),
        const SizedBox(width: 4),
        if (widget.isGuest)
          _topBarButton(
            icon: Icons.exit_to_app_rounded,
            label: _isArabic ? 'خروج' : 'Exit',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerLoginScreen(),
                ),
              );
            },
            color: Colors.redAccent,
            bg: _surface,
            border: _border,
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
    );
  }

  // ---------- BOTTOM NAV (mobile) ----------
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: _isArabic ? 'الرئيسية' : 'Home',
                index: 0,
                current: _currentIndex,
                accent: _accent,
                unselected: _unselected,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                icon: Icons.auto_awesome_rounded,
                label: _isArabic ? 'AI بحث' : 'AI Search',
                index: 1,
                current: _currentIndex,
                accent: _accent,
                unselected: _unselected,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItemCenter(
                icon: Icons.receipt_long_rounded,
                label: _isArabic ? 'طلباتي' : 'Orders',
                index: 2,
                current: _currentIndex,
                accent: _accent,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: _isArabic ? 'الرسائل' : 'Chats',
                index: 3,
                current: _currentIndex,
                accent: _accent,
                unselected: _unselected,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: _isArabic ? 'حسابي' : 'Profile',
                index: 4,
                current: _currentIndex,
                accent: _accent,
                unselected: _unselected,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- HELPER WIDGETS ----------
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

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color bg,
    required Color border,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Stack(
          children: [
            Icon(icon, size: 18, color: color),
            if (showBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }
}

// ---------- NAV ITEMS (unchanged) ----------
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final Color accent, unselected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.accent,
    required this.unselected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: sel ? accent : unselected),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                color: sel ? accent : unselected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemCenter extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final Color accent;
  final ValueChanged<int> onTap;

  const _NavItemCenter({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: sel ? accent : accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 22, color: sel ? Colors.black : accent),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                color: sel ? accent : accent.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
