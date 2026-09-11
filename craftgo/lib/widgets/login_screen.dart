import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'home_screen.dart';
import 'login_role_selection.dart';
import '../theme/app_palette.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;
  String selectedRole = 'customer';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final isAr = appState.isArabic;
    final bg = AppPalette.background(isDark);
    final textColor = AppPalette.primaryText(isDark);
    final subColor = AppPalette.secondaryText(isDark);
    final inpBg = AppPalette.inputBackground(isDark);
    final inpBorder = AppPalette.inputBorder(isDark);
    final togBg = isDark ? const Color(0x12FFFFFF) : const Color(0xFFEDE9E1);
    final togInactive =
        isDark ? const Color(0x4DFFFFFF) : const Color(0xFFAAAAAA);
    final glassyBg = AppPalette.inputBackground(isDark);
    final glassyBorder = AppPalette.inputBorder(isDark);
    final divColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);
    final ghostBorder =
        isDark ? const Color(0x33FFFFFF) : const Color(0xFFCCC5BB);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Color(0xFFE8B84B),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MiniToggle(
                isDark: isDark,
                isAr: isAr,
                onTheme: () => appState.toggleTheme(),
                onLang: () => appState.toggleLanguage(),
              ),
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeIn,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppPalette.goldDark, AppPalette.goldBright],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment:
                        isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isLogin
                          ? (isAr
                              ? 'ظ…ط±ط­ط¨ط§ظ‹ ط¨ط¹ظˆط¯طھظƒ'
                              : 'Welcome Back')
                          : (isAr ? 'ط£ظ†ط´ط¦ ط­ط³ط§ط¨ط§ظ‹' : 'Create Account'),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment:
                        isAr ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      isLogin
                          ? (isAr
                              ? 'ط³ط¬ظ‘ظ„ ط¯ط®ظˆظ„ظƒ ظ„ظ„ظ…طھط§ط¨ط¹ط©'
                              : 'Sign in to continue')
                          : (isAr
                              ? 'ط§ظ†ط¶ظ… ط¥ظ„ظ‰ CraftGo ط§ظ„ظٹظˆظ…'
                              : 'Join CraftGo today'),
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: togBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE8B84B).withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ToggleBtn(
                            label: isAr ? 'طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„' : 'Sign In',
                            isActive: isLogin,
                            onTap: () => setState(() => isLogin = true),
                            inactiveColor: togInactive,
                          ),
                        ),
                        Expanded(
                          child: _ToggleBtn(
                            label: isAr ? 'ط­ط³ط§ط¨ ط¬ط¯ظٹط¯' : 'Sign Up',
                            isActive: !isLogin,
                            onTap: () => setState(() => isLogin = false),
                            inactiveColor: togInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role selector (signup only)
                  if (!isLogin) ...[
                    Align(
                      alignment:
                          isAr ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        isAr ? 'ط£ظ†ط§...' : 'I am...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.person_rounded,
                            label: isAr ? 'ط²ط¨ظˆظ†' : 'Customer',
                            isSelected: selectedRole == 'customer',
                            onTap: () =>
                                setState(() => selectedRole = 'customer'),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            icon: Icons.handyman_rounded,
                            label: isAr ? 'ط­ط±ظپظٹ' : 'Artisan',
                            isSelected: selectedRole == 'artisan',
                            onTap: () =>
                                setState(() => selectedRole = 'artisan'),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],

                  // Email
                  _InputField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    label: isAr
                        ? 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ'
                        : 'Email Address',
                    bg: inpBg,
                    border: inpBorder,
                    labelColor: subColor,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  _InputField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    label: isAr ? 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±' : 'Password',
                    isPassword: true,
                    bg: inpBg,
                    border: inpBorder,
                    labelColor: subColor,
                  ),

                  if (!isLogin) ...[
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _nameController,
                      icon: Icons.person_outline,
                      label: isAr ? 'ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„' : 'Full Name',
                      bg: inpBg,
                      border: inpBorder,
                      labelColor: subColor,
                    ),
                  ],

                  if (isLogin) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment:
                          isAr ? Alignment.centerLeft : Alignment.centerRight,
                      child: Text(
                        isAr
                            ? 'ظ†ط³ظٹطھ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±طں'
                            : 'Forgot Password?',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8B84B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              final name = _nameController.text.trim();

                              Map<String, dynamic>? result;
                              if (isLogin) {
                                result =
                                    await AuthService.login(email, password);
                              } else {
                                // Build roles list based on selectedRole
                                final roles = [
                                  selectedRole == 'artisan'
                                      ? 'artisan'
                                      : 'customer'
                                ];
                                result = await AuthService.signup(
                                  name: name,
                                  email: email,
                                  password: password,
                                  roles: roles, // âœ… use roles list
                                  city: 'Nablus',
                                  phone: '',
                                  category: '',
                                  experienceYears: 0,
                                  bio: '',
                                );
                              }

                              setState(() => isLoading = false);

                              if (mounted) {
                                if (result != null) {
                                  final token =
                                      await SessionService.getToken() ?? '';
                                  final roles = List<String>.from(
                                      result['roles'] ?? ['customer']);
                                  final isVerified =
                                      result['isVerified'] == true;
                                  if (!context.mounted) return;
                                  final appState = context.read<AppState>();
                                  appState.setAuth(
                                    userId: result['id']?.toString() ?? '',
                                    userName: result['name'] ?? '',
                                    token: token,
                                    roles: roles,
                                    isVerified: isVerified,
                                  );
                                  // Navigate based on number of roles
                                  if (roles.length == 1) {
                                    appState.setActiveRole(roles.first);
                                    if (!context.mounted) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            appState.getShellForActiveRole(),
                                      ),
                                    );
                                  } else {
                                    // Show role selection screen
                                    if (!context.mounted) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginRoleSelectionScreen(),
                                      ),
                                    );
                                  }
                                } else {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isAr
                                          ? 'ظپط´ظ„طھ ط§ظ„ط¹ظ…ظ„ظٹط©طŒ طھط£ظƒط¯ ظ…ظ† ط§ظ„ط¨ظٹط§ظ†ط§طھ'
                                          : 'Failed. Check your credentials.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8B84B),
                        foregroundColor: const Color(0xFF0A0A0A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF0A0A0A),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isLogin
                                  ? (isAr
                                      ? 'طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„'
                                      : 'Sign In')
                                  : (isAr
                                      ? 'ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨'
                                      : 'Create Account'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: divColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          isAr ? 'ط£ظˆ' : 'or',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ),
                      Expanded(child: Divider(color: divColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: glassyBg,
                        border: Border.all(color: glassyBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 24,
                            color: Color(0xFFE8B84B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAr
                                ? 'ظ…طھط§ط¨ط¹ط© ط¨ظ€ Google'
                                : 'Continue with Google',
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: ghostBorder, width: 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        isAr ? 'طھطµظپط­ ظƒط²ط§ط¦ط±' : 'Browse as Guest',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: subColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Helper widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MiniToggle extends StatelessWidget {
  final bool isDark;
  final bool isAr;
  final VoidCallback onTheme;
  final VoidCallback onLang;

  const _MiniToggle({
    required this.isDark,
    required this.isAr,
    required this.onTheme,
    required this.onLang,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTheme,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE8B84B).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 16,
              color: const Color(0xFFE8B84B),
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onLang,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE8B84B).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAr ? 'EN' : 'ط¹ط±ط¨ظٹ',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFE8B84B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color inactiveColor;

  const _ToggleBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFE8B84B), Color(0xFFC9962A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? const Color(0xFF0A0A0A) : inactiveColor,
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A1A1A)
              : (isDark ? Colors.transparent : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE8B84B)
                : (isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8)),
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE8B84B).withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFE8B84B) : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected ? const Color(0xFFE8B84B) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color border;
  final Color labelColor;
  final bool isPassword;
  final TextEditingController? controller;

  const _InputField({
    required this.icon,
    required this.label,
    required this.bg,
    required this.border,
    required this.labelColor,
    this.isPassword = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFE8B84B), size: 20),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8B84B), width: 1.5),
        ),
      ),
    );
  }
}
