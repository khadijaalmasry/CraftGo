import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme/app_palette.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../widgets/craftsman_registration_screen.dart';

class CraftsmanLoginScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final Map<String, dynamic> selectedCategory;
  final String heroTag;

  const CraftsmanLoginScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.selectedCategory,
    required this.heroTag,
  });

  @override
  State<CraftsmanLoginScreen> createState() => _CraftsmanLoginScreenState();
}

class _CraftsmanLoginScreenState extends State<CraftsmanLoginScreen> {
  late bool isArabic;
  late bool isDarkMode;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    isDarkMode = widget.isDarkMode;
  }

  // Colors mapping
  Color get backgroundColor =>
      isDarkMode ? AppPalette.background(true) : AppPalette.background(false);

  Color get primaryTextColor => AppPalette.primaryText(isDarkMode);

  Color get secondaryTextColor => AppPalette.secondaryText(isDarkMode);

  Color get inputFillColor => AppPalette.inputBackground(isDarkMode);

  Color get borderColor => AppPalette.borderColor(isDarkMode);

  Color get topIconColor => AppPalette.topIconColor(isDarkMode);

  Color get topButtonBackground => AppPalette.topButtonBackground(isDarkMode);

  Color get chipBorderColor => AppPalette.borderColor(isDarkMode);

  void toggleLanguage() {
    setState(() {
      isArabic = !isArabic;
    });
    widget.onToggleLanguage();
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    widget.onToggleTheme();
  }

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topBarButton(
                      icon: isArabic
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios,
                      label: "",
                      onTap: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        _topBarButton(
                          icon: Icons.language,
                          label: isArabic ? "EN" : "عربي",
                          onTap: toggleLanguage,
                        ),
                        const SizedBox(width: 10),
                        _topBarButton(
                          icon: isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: "",
                          onTap: toggleTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              // Header Icon â€” Hero shared element from category card
                              Hero(
                                tag: widget.heroTag,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF7B500),
                                        Color(0xFFD89A00)
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF7B500)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.selectedCategory['icon']
                                            as IconData? ??
                                        Icons.login,
                                    size: 40,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Title
                              Text(
                                isArabic ? "طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„" : "Login",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.arefRuqaa(
                                  color: primaryTextColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Dynamic category subtitle
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4A017)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFD4A017)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  isArabic
                                      ? 'ظ„ظ„ط§ظ†ط¶ظ…ط§ظ… ظƒط­ط±ظپظٹ ظپظٹ ظ…ط¬ط§ظ„ ${widget.selectedCategory['titleAr'] ?? ''}'
                                      : 'To join as a craftsman in ${widget.selectedCategory['titleEn'] ?? ''}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFD4A017),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Fields
                              _buildTextField(
                                label: isArabic
                                    ? "ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ط£ظˆ ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ"
                                    : "Email or Phone",
                                icon: Icons.person_outline,
                                controller: _emailController,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                label: isArabic
                                    ? "ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±"
                                    : "Password",
                                icon: Icons.lock_outline,
                                isPassword: true,
                                controller: _passwordController,
                              ),
                              const SizedBox(height: 15),

                              // Forgot Password
                              Align(
                                alignment: isArabic
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    isArabic
                                        ? "ظ†ط³ظٹطھ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±طں"
                                        : "Forgot Password?",
                                    style: const TextStyle(
                                      color: Color(0xFFD4A017),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Login Button
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF7B500),
                                      Color(0xFFD89A00),
                                    ],
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
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          if (!_formKey.currentState!
                                              .validate()) return;
                                          setState(() => isLoading = true);

                                          final email =
                                              _emailController.text.trim();
                                          final password =
                                              _passwordController.text;

                                          // Capture context-dependents before async gaps
                                          final nav = Navigator.of(context);
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final appState =
                                              context.read<AppState>();

                                          final result =
                                              await AuthService.login(
                                                  email, password);

                                          setState(() => isLoading = false);

                                          if (!mounted) return;

                                          if (result != null) {
                                            final token = await SessionService
                                                    .getToken() ??
                                                '';
                                            if (!mounted) return;

                                            final roles = List<String>.from(
                                                result['roles'] ??
                                                    ['customer']);
                                            // ًں”چ DEBUG: ط·ط¨ط§ط¹ط© ط§ظ„ظ€ roles ط§ظ„ط±ط§ط¬ط¹ط© ظ…ظ† ط§ظ„ط¨ط§ظƒ-ط¥ظ†ط¯
                                            debugPrint(
                                                'ًں”چ [CraftsmanLogin] result keys: ${result.keys.toList()}');
                                            debugPrint(
                                                'ًں”چ [CraftsmanLogin] roles from backend: $roles');
                                            debugPrint(
                                                'ًں”چ [CraftsmanLogin] raw result[roles]: ${result['roles']}');
                                            final isVerified =
                                                result['isVerified'] == true;
                                            appState.setAuth(
                                              userId:
                                                  result['id']?.toString() ??
                                                      '',
                                              userName: result['name'] ?? '',
                                              token: token,
                                              roles: roles,
                                              isVerified: isVerified,
                                            );

                                            // â”€â”€ ظ‡ط°ظ‡ ط´ط§ط´ط© ط­ط±ظپظٹظٹظ† â€” ظ†ظڈظپط¹ظ‘ظ„ ط¯ط§ط¦ظ…ط§ظ‹ role artisan â”€â”€
                                            if (roles.contains('artisan')) {
                                              appState.setActiveRole('artisan');
                                              nav.pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (_) => appState
                                                      .getShellForActiveRole(),
                                                ),
                                                (route) => false,
                                              );
                                            } else {
                                              // ط§ظ„ط­ط³ط§ط¨ ط؛ظٹط± ظ…ط³ط¬ظ„ ظƒط­ط±ظپظٹ
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(isArabic
                                                      ? 'ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨ ط؛ظٹط± ظ…ط³ط¬ظ„ ظƒط­ط±ظپظٹ. ظٹط±ط¬ظ‰ ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط­ط±ظپظٹ ط¬ط¯ظٹط¯.'
                                                      : 'This account is not registered as an artisan.'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } else {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(isArabic
                                                    ? 'ظپط´ظ„طھ ط§ظ„ط¹ظ…ظ„ظٹط©طŒ طھط£ظƒط¯ ظ…ظ† ط§ظ„ط¨ظٹط§ظ†ط§طھ'
                                                    : 'Failed. Check your credentials.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          isArabic ? "ط¯ط®ظˆظ„" : "Login",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // â”€â”€ Register link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isArabic
                                        ? 'ظ„ظٹط³ ظ„ط¯ظٹظƒ ط­ط³ط§ط¨طں '
                                        : 'No account? ',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CraftsmanRegistrationScreen(
                                            selectedCategory:
                                                widget.selectedCategory,
                                            isArabic: isArabic,
                                            isDarkMode: isDarkMode,
                                            onToggleLanguage:
                                                widget.onToggleLanguage,
                                            onToggleTheme: widget.onToggleTheme,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isArabic
                                          ? 'ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط¬ط¯ظٹط¯'
                                          : 'Create New Account',
                                      style: const TextStyle(
                                        color: Color(0xFFD4A017),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextEditingController? controller,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: primaryTextColor),
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: Icon(icon, color: secondaryTextColor),
        filled: true,
        fillColor: inputFillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
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
