import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../screens/exhibitions/exhibition_owner_dashboard.dart';
import '../screens/exhibitions/my_exhibitions_screen.dart';
import '../screens/exhibitions/craftsmen_browse_screen.dart';
import '../screens/exhibitions/community_exhibitions_screen.dart';
import '../app_state.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ExhibitionOwnerShell extends StatelessWidget {
  final String ownerName;

  const ExhibitionOwnerShell({
    super.key,
    required this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return _ExhibitionOwnerShellContent(
          ownerName: ownerName,
          isArabic: state.isArabic,
          isDarkMode: state.isDarkMode,
        );
      },
    );
  }
}

class _ExhibitionOwnerShellContent extends StatefulWidget {
  final String ownerName;
  final bool isArabic;
  final bool isDarkMode;

  const _ExhibitionOwnerShellContent({
    required this.ownerName,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<_ExhibitionOwnerShellContent> createState() =>
      _ExhibitionOwnerShellContentState();
}

class _ExhibitionOwnerShellContentState
    extends State<_ExhibitionOwnerShellContent> {
  int _currentIndex = 0;

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final String currentOwnerName = (appState.userName?.isNotEmpty ?? false)
        ? appState.userName!
        : widget.ownerName;

    final navTitles = [
      t('الرئيسية', 'Home'),
      t('المعارض', 'Exhibitions'),
      t('الحرفيون', 'Artisans'),
      t('المجتمع', 'Community'),
      t('الملف الشخصي', 'Profile'),
    ];

    final navIcons = [
      Icons.home_outlined,
      Icons.museum_outlined,
      Icons.people_outline,
      Icons.explore_outlined,
      Icons.person_outline,
    ];

    final navActiveIcons = [
      Icons.home,
      Icons.museum,
      Icons.people,
      Icons.explore,
      Icons.person,
    ];

    Widget buildMobileLayout() {
      return Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                    label: widget.isArabic ? 'EN' : 'عربي',
                    onTap: () => appState.toggleLanguage(),
                    color: text,
                    bg: surface,
                    border: Colors.black12,
                  ),
                  const SizedBox(width: 4),
                  _topBarButton(
                    icon: widget.isDarkMode
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
            children: [
              ExhibitionOwnerDashboard(
                ownerName: currentOwnerName,
              ),
              const MyExhibitionsScreen(),
              CraftsmenBrowseScreen(
                exhibitions: appState.exhibitions,
              ),
              const CommunityExhibitionsScreen(),
              _OwnerProfileTab(
                onProfileUpdated: () {
                  setState(() {});
                },
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: surface,
            selectedItemColor: accent,
            unselectedItemColor: dim,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.cairo(),
            items: List.generate(5, (i) {
              return BottomNavigationBarItem(
                icon: Icon(navIcons[i]),
                activeIcon: Icon(navActiveIcons[i]),
                label: navTitles[i],
              );
            }),
          ),
        ),
      );
    }

    Widget buildDesktopLayout() {
      return Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: bg,
          body: Row(
            children: [
              // Sidebar Navigation
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(
                    right: widget.isArabic
                        ? BorderSide.none
                        : BorderSide(color: Colors.black12),
                    left: widget.isArabic
                        ? BorderSide(color: Colors.black12)
                        : BorderSide.none,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'CraftGo',
                        style: GoogleFonts.playfairDisplay(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          t('منظم المعارض', 'Exhibition Portal'),
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: Colors.black12),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: navTitles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final selected = _currentIndex == index;
                            return ListTile(
                              leading: Icon(
                                selected
                                    ? navActiveIcons[index]
                                    : navIcons[index],
                                color: selected ? accent : dim,
                                size: 22,
                              ),
                              title: Text(
                                navTitles[index],
                                style: GoogleFonts.cairo(
                                  color: selected ? accent : text,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              selected: selected,
                              selectedTileColor:
                                  accent.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onTap: () =>
                                  setState(() => _currentIndex = index),
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: Colors.black12),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _topBarButton(
                              icon: Icons.language,
                              label: widget.isArabic ? 'EN' : 'عربي',
                              onTap: () => appState.toggleLanguage(),
                              color: text,
                              bg: bg,
                              border: Colors.black12,
                            ),
                            _topBarButton(
                              icon: widget.isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              label: '',
                              onTap: () => appState.toggleTheme(),
                              color: text,
                              bg: bg,
                              border: Colors.black12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content Pane
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    ExhibitionOwnerDashboard(
                      ownerName: currentOwnerName,
                    ),
                    const MyExhibitionsScreen(),
                    CraftsmenBrowseScreen(
                      exhibitions: appState.exhibitions,
                    ),
                    const CommunityExhibitionsScreen(),
                    _OwnerProfileTab(
                      onProfileUpdated: () {
                        setState(() {});
                      },
                    ),
                  ],
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

// ── Profile Screen Tab ──────────────────────────────────────────────

class _OwnerProfileTab extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const _OwnerProfileTab({required this.onProfileUpdated});

  @override
  State<_OwnerProfileTab> createState() => _OwnerProfileTabState();
}

class _OwnerProfileTabState extends State<_OwnerProfileTab> {
  String _name = '';
  String _email = '';
  String _phone = '';
  String _city = '';
  String _profileImage = '';
  String _bankName = '';
  String _accountTitle = '';
  String _iban = '';
  bool _isLoading = true;
  String _error = '';

  // Notification Preferences State
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final user = await AuthService.getProfile();
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _name = user['name'] ?? '';
          _email = user['email'] ?? '';
          _phone = user['phone'] ?? '';
          _city = user['city'] ?? '';
          _profileImage = user['profileImage'] ?? '';
          _bankName = user['bankName'] ?? '';
          _accountTitle = user['accountTitle'] ?? '';
          _iban = user['iban'] ?? '';
          _isLoading = false;
        });
        if (_name.isNotEmpty) {
          context.read<AppState>().updateUserName(_name);
        }
      } else {
        setState(() {
          _error = 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String t(String ar, String en, [AppState? state]) =>
      (state?.isArabic ?? context.read<AppState>().isArabic) ? ar : en;

  void _showEditProfileDialog(BuildContext context, AppState appState) {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final cityCtrl = TextEditingController(text: _city);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    final isDarkMode = appState.isDarkMode;
    final surfaceColor = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardBorderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final accent = const Color(0xFFD4A017);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Directionality(
            textDirection:
                appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: cardBorderColor),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: secondaryTextColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('تعديل الملف الشخصي', 'Edit Profile', appState),
                        style: GoogleFonts.arefRuqaa(
                          color: primaryTextColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Avatar with camera icon
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: accent.withValues(alpha: 0.2),
                              backgroundImage: _profileImage.isNotEmpty
                                  ? NetworkImage(_profileImage)
                                  : null,
                              child: _profileImage.isEmpty
                                  ? Icon(Icons.person, size: 50, color: accent)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: surfaceColor, width: 2),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      size: 18, color: Colors.black),
                                  onPressed: () {},
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      _buildOwnerEditField(
                        label: t('الاسم الكامل', 'Full Name', appState),
                        controller: nameCtrl,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        cardBorderColor: cardBorderColor,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? t('الاسم مطلوب', 'Name is required', appState)
                            : null,
                      ),

                      // Email (Read Only style)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('البريد الإلكتروني', 'Email Address', appState),
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _email,
                                      style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 14),
                                    ),
                                  ),
                                  Icon(Icons.lock_outline,
                                      size: 16, color: secondaryTextColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Phone
                      _buildOwnerEditField(
                        label: t('رقم الهاتف', 'Phone Number', appState),
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        cardBorderColor: cardBorderColor,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        validator: (val) =>
                            (val == null || val.trim().length < 8)
                                ? t('رقم الهاتف غير صحيح',
                                    'Invalid phone number', appState)
                                : null,
                      ),

                      // City / Location
                      _buildOwnerEditField(
                        label: t('المدينة', 'City', appState),
                        controller: cityCtrl,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        cardBorderColor: cardBorderColor,
                        accent: accent,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 30),

                      // Bottom action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: cardBorderColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                t('إلغاء', 'Cancel', appState),
                                style: TextStyle(color: primaryTextColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF7B500),
                                    Color(0xFFD89A00)
                                  ],
                                ),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                onPressed: () async {
                                  if (formKey.currentState?.validate() ??
                                      false) {
                                    setSheetState(() => isSaving = true);
                                    final payload = {
                                      'name': nameCtrl.text.trim(),
                                      'email': emailCtrl.text.trim(),
                                      'phone': phoneCtrl.text.trim(),
                                      'city': cityCtrl.text.trim(),
                                    };
                                    try {
                                      final response = await ApiService.put(
                                          '/auth/profile',
                                          body: payload);

                                      if (!context.mounted) return;

                                      if (response.statusCode == 200) {
                                        final data = jsonDecode(response.body);
                                        final updatedUser = data['user'];
                                        setState(() {
                                          _name = updatedUser['name'] ?? _name;
                                          _email =
                                              updatedUser['email'] ?? _email;
                                          _phone =
                                              updatedUser['phone'] ?? _phone;
                                          _city = updatedUser['city'] ?? _city;
                                        });
                                        appState.updateUserName(_name);
                                        widget.onProfileUpdated();

                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(t(
                                                'تم تحديث الملف الشخصي بنجاح',
                                                'Profile updated successfully',
                                                appState)),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        throw Exception('Failed to update');
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(t('فشل التحديث',
                                              'Update failed', appState)),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      if (ctx.mounted) {
                                        setSheetState(() => isSaving = false);
                                      }
                                    }
                                  }
                                },
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        t('حفظ', 'Save', appState),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerEditField({
    required String label,
    required TextEditingController controller,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color cardBorderColor,
    required Color accent,
    required bool isDarkMode,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
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
                borderSide: BorderSide(color: accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payout Account Dialog (Bank & IBAN Setup) ────────────────────
  void _showPayoutAccountDialog(BuildContext context, AppState appState) {
    final bankCtrl = TextEditingController(text: _bankName);
    final titleCtrl = TextEditingController(text: _accountTitle);
    final ibanCtrl = TextEditingController(text: _iban);
    final formKey = GlobalKey<FormState>();

    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final accent = const Color(0xFFD4A017);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.account_balance, color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('حساب استلام الأرباح (البنك)', 'Payout Bank Details',
                      appState),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t(
                        'أدخل معلومات حسابك البنكي لتحويل أرباح المعارض إليك تلقائياً',
                        'Enter your bank details to disburse your exhibition booth earnings',
                        appState),
                    style: GoogleFonts.cairo(color: dim, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: bankCtrl,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText: t('اسم البنك', 'Bank Name', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon: Icon(Icons.account_balance, color: accent),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? t('اسم البنك مطلوب', 'Bank name is required',
                            appState)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtrl,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText:
                          t('اسم صاحب الحساب', 'Account Holder Name', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon: Icon(Icons.person, color: accent),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? t('اسم صاحب الحساب مطلوب',
                            'Account holder name is required', appState)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ibanCtrl,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText: t('رقم الآيبان (IBAN)',
                          'IBAN / Account Number', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon: Icon(Icons.credit_card, color: accent),
                    ),
                    validator: (val) => (val == null || val.trim().length < 8)
                        ? t('رقم الآيبان غير صحيح', 'Invalid IBAN', appState)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel', appState),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final payload = {
                    'bankName': bankCtrl.text.trim(),
                    'accountTitle': titleCtrl.text.trim(),
                    'iban': ibanCtrl.text.trim(),
                  };
                  try {
                    final response =
                        await ApiService.put('/auth/profile', body: payload);
                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    if (response.statusCode == 200) {
                      setState(() {
                        _bankName = bankCtrl.text.trim();
                        _accountTitle = titleCtrl.text.trim();
                        _iban = ibanCtrl.text.trim();
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(t(
                              'تم حفظ حساب استلام الأرباح بنجاح',
                              'Payout bank details saved successfully',
                              appState)),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('فشل حفظ الحساب البنكي',
                            'Failed to save bank details', appState)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(
                t('حفظ الحساب', 'Save Payout Account', appState),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Change Password Dialog ──────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context, AppState appState) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final accent = const Color(0xFFD4A017);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('تغيير كلمة المرور', 'Change Password', appState),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPassCtrl,
                    obscureText: true,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText: t(
                          'كلمة المرور الحالية', 'Current Password', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon: Icon(Icons.lock_outline, color: accent),
                    ),
                    validator: (val) => (val == null || val.isEmpty)
                        ? t('أدخل كلمة المرور الحالية',
                            'Enter current password', appState)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText:
                          t('كلمة المرور الجديدة', 'New Password', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon: Icon(Icons.lock_reset, color: accent),
                    ),
                    validator: (val) => (val == null || val.length < 6)
                        ? t('كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                            'Password must be at least 6 chars', appState)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    style: TextStyle(color: text),
                    decoration: InputDecoration(
                      labelText: t('تأكيد كلمة المرور الجديدة',
                          'Confirm New Password', appState),
                      labelStyle: TextStyle(color: dim),
                      prefixIcon:
                          Icon(Icons.check_circle_outline, color: accent),
                    ),
                    validator: (val) {
                      if (val != newPassCtrl.text) {
                        return t('كلمتا المرور غير متطابقتين',
                            'Passwords do not match', appState);
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel', appState),
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('تم تغيير كلمة المرور بنجاح',
                            'Password changed successfully', appState)),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(
                t('تأكيد', 'Confirm', appState),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notification Preferences Dialog ──────────────────────────────
  void _showNotificationPreferencesDialog(
      BuildContext context, AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final accent = const Color(0xFFD4A017);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection:
              appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('تفضيلات الإشعارات', 'Notification Preferences',
                        appState),
                    style: GoogleFonts.cairo(
                        color: text, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                      t('إشعارات التطبيق', 'Push Notifications', appState),
                      style: TextStyle(color: text)),
                  subtitle: Text(
                      t('تنبيهات فورية للطلبات الجديدة',
                          'Instant alerts for new requests', appState),
                      style: TextStyle(color: dim, fontSize: 12)),
                  value: _pushNotifications,
                  activeTrackColor: accent,
                  onChanged: (val) {
                    setState(() => _pushNotifications = val);
                    setDialogState(() {});
                  },
                ),
                SwitchListTile(
                  title: Text(
                      t('إشعارات البريد الإلكتروني', 'Email Notifications',
                          appState),
                      style: TextStyle(color: text)),
                  subtitle: Text(
                      t('ملخص أسبوعي للنشاط والتقارير',
                          'Weekly digest of activity and reports', appState),
                      style: TextStyle(color: dim, fontSize: 12)),
                  value: _emailNotifications,
                  activeTrackColor: accent,
                  onChanged: (val) {
                    setState(() => _emailNotifications = val);
                    setDialogState(() {});
                  },
                ),
                SwitchListTile(
                  title: Text(
                      t('تنبيهات الرسائل النصية', 'SMS Alerts', appState),
                      style: TextStyle(color: text)),
                  subtitle: Text(
                      t('رسائل نصية للأحداث الهامة',
                          'SMS messages for urgent events', appState),
                      style: TextStyle(color: dim, fontSize: 12)),
                  value: _smsNotifications,
                  activeTrackColor: accent,
                  onChanged: (val) {
                    setState(() => _smsNotifications = val);
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إغلاق', 'Close', appState),
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Privacy Policy Dialog ──────────────────────────────────────────
  void _showPrivacyPolicyDialog(BuildContext context, AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final accent = const Color(0xFFD4A017);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('سياسة الخصوصية', 'Privacy Policy', appState),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('سياسة خصوصية CraftGo', 'CraftGo Privacy Policy'),
                  style: GoogleFonts.cairo(
                      color: accent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'نحن نلتزم بحماية بياناتك وسجلك التجاري. تُستخدم بيانات المعارض والتواصل حصرياً لتمكين الحرفيين والزوار من التفاعل بأمان مع معارضك.',
                    'We are committed to protecting your data and commercial registration. Exhibition data and communication are used strictly to enable artisans and visitors to safely interact with your exhibitions.',
                    appState,
                  ),
                  style: TextStyle(color: dim, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  t('حماية البيانات والتراخيص', 'Data Protection & Licenses'),
                  style: GoogleFonts.cairo(
                      color: text, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'جميع التراخيص والسجلات مشفرة على خوادم آمنة وفقاً لمعايير الأمان المعتمدة.',
                    'All licenses and records are encrypted on secure servers following standard security practices.',
                    appState,
                  ),
                  style: TextStyle(color: dim, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(
                t('أوافق', 'I Agree', appState),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout Confirm Dialog ─────────────────────────────────────────
  void _confirmLogout(BuildContext context, AppState appState) {
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            t('تأكيد تسجيل الخروج', 'Confirm Logout', appState),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            t('هل أنت متأكد من أنك تريد تسجيل الخروج؟',
                'Are you sure you want to log out?', appState),
            style: TextStyle(color: dim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel', appState),
                  style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                appState.logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/onboarding',
                  (route) => false,
                );
              },
              child: Text(t('تسجيل الخروج', 'Logout', appState),
                  style: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final accent = const Color(0xFFD4A017);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error, style: TextStyle(color: text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: Text(t('إعادة المحاولة', 'Retry', appState)),
            ),
          ],
        ),
      );
    }

    final exhibitionCount = appState.exhibitions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Avatar & Header
          CircleAvatar(
            radius: 46,
            backgroundColor: accent.withValues(alpha: 0.2),
            backgroundImage:
                _profileImage.isNotEmpty ? NetworkImage(_profileImage) : null,
            child: _profileImage.isEmpty
                ? Text(
                    _name.isNotEmpty ? _name[0] : 'R',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: accent),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _name,
            style: GoogleFonts.cairo(
                color: text, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            _email,
            style: GoogleFonts.cairo(color: dim, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            _phone.isNotEmpty
                ? _phone
                : t('غير محدد', 'Not specified', appState),
            style: GoogleFonts.cairo(color: dim, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Registration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${t('السجل التجاري:', 'Reg / License:', appState)} CR-9048123-JO',
                    style: GoogleFonts.cairo(
                        color: text, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Edit Button
          ElevatedButton.icon(
            onPressed: () => _showEditProfileDialog(context, appState),
            icon: const Icon(Icons.edit, size: 16, color: Colors.black),
            label: Text(
              t('تعديل الملف الشخصي', 'Edit Profile', appState),
              style: GoogleFonts.cairo(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          const SizedBox(height: 28),

          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildStat(t('المعارض', 'Exhibitions', appState),
                      '$exhibitionCount', text, dim),
                ),
                Container(width: 1, height: 36, color: border),
                Expanded(
                  child: _buildStat(
                      t('الحرفيون', 'Artisans', appState), '18', text, dim),
                ),
                Container(width: 1, height: 36, color: border),
                Expanded(
                  child: _buildStat(
                      t('الطلبات', 'Requests', appState), '15', text, dim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Switch to Customer View Shortcut Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                appState.setActiveRole('customer');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('تم الانتقال إلى وضع الزبون',
                        'Switched to Customer View', appState)),
                    backgroundColor: const Color(0xFF1B3A66),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined,
                  color: Colors.white, size: 20),
              label: Text(
                t('تصفح كزبون (Customer View)', 'Switch to Customer View',
                    appState),
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3A66),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Settings Options
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _buildOptionTile(
                  icon: Icons.account_balance_outlined,
                  title: _iban.isNotEmpty
                      ? '${t('حساب الأرباح:', 'Payout Account:', appState)} $_bankName (${_iban.length > 8 ? '${_iban.substring(0, 4)}...${_iban.substring(_iban.length - 4)}' : _iban})'
                      : t('ربط حساب استلام الأرباح (IBAN / Bank)',
                          'Connect Payout Bank Account', appState),
                  onTap: () => _showPayoutAccountDialog(context, appState),
                  text: text,
                  dim: dim,
                  accent: accent,
                  border: border,
                  isArabic: isArabic,
                ),
                Divider(color: border, height: 1),
                _buildOptionTile(
                  icon: Icons.lock_outline,
                  title: t('تغيير كلمة المرور', 'Change Password', appState),
                  onTap: () => _showChangePasswordDialog(context, appState),
                  text: text,
                  dim: dim,
                  accent: accent,
                  border: border,
                  isArabic: isArabic,
                ),
                Divider(color: border, height: 1),
                _buildOptionTile(
                  icon: Icons.notifications_outlined,
                  title: t('تفضيلات الإشعارات', 'Notification Preferences',
                      appState),
                  onTap: () =>
                      _showNotificationPreferencesDialog(context, appState),
                  text: text,
                  dim: dim,
                  accent: accent,
                  border: border,
                  isArabic: isArabic,
                ),
                Divider(color: border, height: 1),
                _buildOptionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: t('سياسة الخصوصية', 'Privacy Policy', appState),
                  onTap: () => _showPrivacyPolicyDialog(context, appState),
                  text: text,
                  dim: dim,
                  accent: accent,
                  border: border,
                  isArabic: isArabic,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, appState),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text(
              t('تسجيل الخروج', 'Logout', appState),
              style:
                  GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color text, Color dim) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.cairo(
                color: text, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.cairo(color: dim, fontSize: 13)),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color text,
    required Color dim,
    required Color accent,
    required Color border,
    required bool isArabic,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(
            color: text, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        isArabic ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
        color: dim,
        size: 16,
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import '../screens/exhibitions/exhibition_owner_dashboard.dart';
// import '../screens/exhibitions/my_exhibitions_screen.dart';
// import '../screens/exhibitions/craftsmen_browse_screen.dart';
// import '../screens/exhibitions/community_exhibitions_screen.dart';
// import '../app_state.dart';
// import '../main.dart';
// import 'dart:convert';
// import '../services/api_service.dart';
// import '../services/auth_service.dart';

// class ExhibitionOwnerShell extends StatelessWidget {
//   final String ownerName;

//   const ExhibitionOwnerShell({
//     super.key,
//     required this.ownerName,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AppState>(
//       builder: (context, state, child) {
//         return _ExhibitionOwnerShellContent(
//           ownerName: ownerName,
//           isArabic: state.isArabic,
//           isDarkMode: state.isDarkMode,
//         );
//       },
//     );
//   }
// }

// class _ExhibitionOwnerShellContent extends StatefulWidget {
//   final String ownerName;
//   final bool isArabic;
//   final bool isDarkMode;

//   const _ExhibitionOwnerShellContent({
//     required this.ownerName,
//     required this.isArabic,
//     required this.isDarkMode,
//   });

//   @override
//   State<_ExhibitionOwnerShellContent> createState() =>
//       _ExhibitionOwnerShellContentState();
// }

// class _ExhibitionOwnerShellContentState
//     extends State<_ExhibitionOwnerShellContent> {
//   int _currentIndex = 0;

//   void _switchTab(int index) {
//     setState(() {
//       _currentIndex = index;
//     });
//   }

//   Color get bg =>
//       widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get surface =>
//       widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
//   Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
//   Color get accent => const Color(0xFFD4A017);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   @override
//   Widget build(BuildContext context) {
//     final appState = context.watch<AppState>();

//     // Dynamic name from AppState to keep Dashboard in sync across edits
//     final String currentOwnerName = (appState.userName?.isNotEmpty ?? false)
//         ? appState.userName!
//         : widget.ownerName;

//     return Directionality(
//       textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         backgroundColor: bg,
//         appBar: AppBar(
//           backgroundColor: surface,
//           elevation: 0,
//           automaticallyImplyLeading: false,
//           title: Text(
//             'CraftGo',
//             style: GoogleFonts.playfairDisplay(
//               color: accent,
//               fontWeight: FontWeight.bold,
//               fontSize: 24,
//             ),
//           ),
//           centerTitle: true,
//           actions: [
//             IconButton(
//               icon: Icon(Icons.language, color: text),
//               onPressed: () => appState.toggleLanguage(),
//             ),
//             IconButton(
//               icon: Icon(
//                   widget.isDarkMode
//                       ? Icons.light_mode_outlined
//                       : Icons.dark_mode_outlined,
//                   color: text),
//               onPressed: () => appState.toggleTheme(),
//             ),
//           ],
//         ),
//         body: IndexedStack(
//           index: _currentIndex,
//           children: [
//             ExhibitionOwnerDashboard(
//               ownerName: currentOwnerName, // Dynamically synced name
//             ),
//             const MyExhibitionsScreen(),
//             CraftsmenBrowseScreen(
//               exhibitions: appState.exhibitions,
//             ),
//             const CommunityExhibitionsScreen(),
//             _ExhibitionOwnerProfilePage(
//               initialOwnerName: currentOwnerName,
//             ),
//           ],
//         ),
//         bottomNavigationBar: BottomNavigationBar(
//           currentIndex: _currentIndex,
//           onTap: (index) => setState(() => _currentIndex = index),
//           backgroundColor: surface,
//           selectedItemColor: accent,
//           unselectedItemColor: dim,
//           type: BottomNavigationBarType.fixed,
//           selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
//           unselectedLabelStyle: GoogleFonts.cairo(),
//           items: [
//             BottomNavigationBarItem(
//               icon: const Icon(Icons.home_outlined),
//               activeIcon: const Icon(Icons.home),
//               label: t('الرئيسية', 'Home'),
//             ),
//             BottomNavigationBarItem(
//               icon: const Icon(Icons.museum_outlined),
//               activeIcon: const Icon(Icons.museum),
//               label: t('المعارض', 'Exhibitions'),
//             ),
//             BottomNavigationBarItem(
//               icon: const Icon(Icons.people_outline),
//               activeIcon: const Icon(Icons.people),
//               label: t('الحرفيون', 'Artisans'),
//             ),
//             BottomNavigationBarItem(
//               icon: const Icon(Icons.explore_outlined),
//               activeIcon: const Icon(Icons.explore),
//               label: t('المجتمع', 'Community'),
//             ),
//             BottomNavigationBarItem(
//               icon: const Icon(Icons.person_outline),
//               activeIcon: const Icon(Icons.person),
//               label: t('الملف الشخصي', 'Profile'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Profile Screen Tab ──────────────────────────────────────────────

// class _OwnerProfileTab extends StatefulWidget {
//   final VoidCallback onProfileUpdated;

//   const _OwnerProfileTab({required this.onProfileUpdated});

//   @override
//   State<_OwnerProfileTab> createState() => _OwnerProfileTabState();
// }

// class _OwnerProfileTabState extends State<_OwnerProfileTab> {
//   String _name = '';
//   String _email = '';
//   String _phone = '';
//   String _city = '';
//   String _profileImage = '';
//   bool _isLoading = true;
//   String _error = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile();
//   }

//   Future<void> _loadProfile() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });
//     try {
//       final user = await AuthService.getProfile();
//       if (!mounted) return;
//       if (user != null) {
//         setState(() {
//           _name = user['name'] ?? '';
//           _email = user['email'] ?? '';
//           _phone = user['phone'] ?? '';
//           _city = user['city'] ?? '';
//           _profileImage = user['profileImage'] ?? '';
//           _isLoading = false;
//         });
//         if (_name.isNotEmpty) {
//           context.read<AppState>().updateUserName(_name);
//         }
//       } else {
//         setState(() {
//           _error = 'Failed to load profile';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _error = e.toString();
//         _isLoading = false;
//       });
//     }
//   }

//   String t(String ar, String en, [AppState? state]) =>
//       (state?.isArabic ?? context.read<AppState>().isArabic) ? ar : en;

//   void _showEditProfileDialog(BuildContext context, AppState appState) {
//     final nameCtrl = TextEditingController(text: _name);
//     final emailCtrl = TextEditingController(text: _email);
//     final phoneCtrl = TextEditingController(text: _phone);
//     final cityCtrl = TextEditingController(text: _city);
//     final formKey = GlobalKey<FormState>();

//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white70 : Colors.black54;
//     final accent = const Color(0xFFD4A017);

//     showDialog(
//       context: context,
//       builder: (ctx) => Directionality(
//         textDirection:
//             appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
//         child: AlertDialog(
//           backgroundColor: surface,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: Row(
//             children: [
//               Icon(Icons.edit, color: accent, size: 22),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   t('تعديل الملف الشخصي', 'Edit Profile', appState),
//                   style: GoogleFonts.cairo(
//                       color: text, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: nameCtrl,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText: t('الاسم الكامل', 'Full Name', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.person, color: accent),
//                     ),
//                     validator: (val) => (val == null || val.trim().isEmpty)
//                         ? t('الاسم مطلوب', 'Name is required', appState)
//                         : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: emailCtrl,
//                     keyboardType: TextInputType.emailAddress,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText:
//                           t('البريد الإلكتروني', 'Email Address', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.email, color: accent),
//                     ),
//                     validator: (val) {
//                       if (val == null || val.trim().isEmpty) {
//                         return t('البريد الإلكتروني مطلوب',
//                             'Email is required', appState);
//                       }
//                       if (!val.contains('@') || !val.contains('.')) {
//                         return t('صيغة البريد الإلكتروني غير صحيحة',
//                             'Invalid email format', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: phoneCtrl,
//                     keyboardType: TextInputType.phone,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText: t('رقم الهاتف', 'Phone Number', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.phone, color: accent),
//                     ),
//                     validator: (val) => (val == null || val.trim().length < 8)
//                         ? t('رقم الهاتف غير صحيح', 'Invalid phone number',
//                             appState)
//                         : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: cityCtrl,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText: t('المدينة', 'City', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.location_city, color: accent),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: Text(t('إلغاء', 'Cancel', appState),
//                   style: const TextStyle(color: Colors.grey)),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 if (formKey.currentState?.validate() ?? false) {
//                   final payload = {
//                     'name': nameCtrl.text.trim(),
//                     'email': emailCtrl.text.trim(),
//                     'phone': phoneCtrl.text.trim(),
//                     'city': cityCtrl.text.trim(),
//                   };
//                   try {
//                     final response =
//                         await ApiService.put('/auth/profile', body: payload);
//                     if (!mounted) return;
//                     if (response.statusCode == 200) {
//                       final data = jsonDecode(response.body);
//                       final updatedUser = data['user'];
//                       setState(() {
//                         _name = updatedUser['name'] ?? _name;
//                         _email = updatedUser['email'] ?? _email;
//                         _phone = updatedUser['phone'] ?? _phone;
//                         _city = updatedUser['city'] ?? _city;
//                       });
//                       appState.updateUserName(_name);
//                       widget.onProfileUpdated();
//                       Navigator.pop(ctx);
//                       if (!mounted) return;
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(t('تم تحديث الملف الشخصي بنجاح',
//                               'Profile updated successfully', appState)),
//                           backgroundColor: Colors.green,
//                         ),
//                       );
//                     } else {
//                       throw Exception('Failed to update');
//                     }
//                   } catch (e) {
//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content:
//                             Text(t('فشل التحديث', 'Update failed', appState)),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 }
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: accent),
//               child: Text(
//                 t('حفظ', 'Save', appState),
//                 style: const TextStyle(
//                     color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ط¸آ¤آ€ط¸آ¤آ€ Change Password Dialog ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€ط¸آ¤آ€
//   void _showChangePasswordDialog(BuildContext context, AppState appState) {
//     final currentPassCtrl = TextEditingController();
//     final newPassCtrl = TextEditingController();
//     final confirmPassCtrl = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xF                child: Text(
//                   t('تغيير كلمة المرور', 'Change Password', appState),
//                   style: GoogleFonts.cairo(
//                       color: text, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: currentPassCtrl,
//                     obscureText: true,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText: t(
//                           'كلمة المرور الحالية', 'Current Password', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.lock_outline, color: accent),
//                     ),
//                     validator: (val) => (val == null || val.isEmpty)
//                         ? t('أدخل كلمة المرور الحالية',
//                             'Enter current password', appState)
//                         : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: newPassCtrl,
//                     obscureText: true,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText:
//                           t('كلمة المرور الجديدة', 'New Password', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon: Icon(Icons.lock_reset, color: accent),
//                     ),
//                     validator: (val) => (val == null || val.length < 6)
//                         ? t('كلمة المرور يجب أن تكون 6 أحرف على الأقل',
//                             'Password must be at least 6 chars', appState)
//                         : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: confirmPassCtrl,
//                     obscureText: true,
//                     style: TextStyle(color: text),
//                     decoration: InputDecoration(
//                       labelText: t('تأكيد كلمة المرور الجديدة',
//                           'Confirm New Password', appState),
//                       labelStyle: TextStyle(color: dim),
//                       prefixIcon:
//                           Icon(Icons.check_circle_outline, color: accent),
//                     ),
//                     validator: (val) {
//                       if (val != newPassCtrl.text) {
//                         return t('كلمتا المرور غير متطابقتين',
//                             'Passwords do not match', appState);
//                       }
//                       return null;
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: Text(t('إلغاء', 'Cancel', appState),
//                   style: const TextStyle(color: Colors.grey)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (formKey.currentState?.validate() ?? false) {
//                   Navigator.pop(ctx);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(t('تم تغيير كلمة المرور بنجاح',
//                           'Password changed successfully', appState)),
//                       backgroundColor: Colors.green,
//                     ),
//                   );
//                 }
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: accent),
//               child: Text(
//                 t('تأكيد', 'Confirm', appState),
//                 style: const TextStyle(
//                     color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Notification Preferences Dialog ──────────────────────────────
//   void _showNotificationPreferencesDialog(
//       BuildContext context, AppState appState) {
//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white70 : Colors.black54;
//     final accent = const Color(0xFFD4A017);

//     showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setDialogState) => Directionality(
//           textDirection:
//               appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
//           child: AlertDialog(
//             backgroundColor: surface,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             title: Row(
//               children: [
//                 Icon(Icons.notifications_active, color: accent, size: 22),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     t('تفضيلات الإشعارات', 'Notification Preferences',
//                         appState),
//                     style: GoogleFonts.cairo(
//                         color: text, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SwitchListTile(
//                   title: Text(
//                       t('إشعارات التطبيق', 'Push Notifications', appState),
//                       style: TextStyle(color: text)),
//                   subtitle: Text(
//                       t('تنبيهات فورية للطلبات الجديدة',
//                           'Instant alerts for new requests', appState),
//                       style: TextStyle(color: dim, fontSize: 12)),
//                   value: _pushNotifications,
//                   activeTrackColor: accent,
//                   onChanged: (val) {
//                     setState(() => _pushNotifications = val);
//                     setDialogState(() {});
//                   },
//                 ),
//                 SwitchListTile(
//                   title: Text(
//                       t('إشعارات البريد الإلكتروني', 'Email Notifications', appState),
//                       style: TextStyle(color: text)),
//                   subtitle: Text(
//                       t('ملخص أسبوعي للنشاط والتقارير',
//                           'Weekly digest of activity and reports', appState),
//                       style: TextStyle(color: dim, fontSize: 12)),
//                   value: _emailNotifications,
//                   activeTrackColor: accent,
//                   onChanged: (val) {
//                     setState(() => _emailNotifications = val);
//                     setDialogState(() {});
//                   },
//                 ),
//                 SwitchListTile(
//                   title: Text(t('تنبيهات الرسائل النصية', 'SMS Alerts', appState),
//                       style: TextStyle(color: text)),
//                   subtitle: Text(
//                       t('رسائل نصية للأحداث الهامة',
//                           'SMS messages for urgent events', appState),
//                       style: TextStyle(color: dim, fontSize: 12)),
//                   value: _smsNotifications,
//                   activeTrackColor: accent,
//                   onChanged: (val) {
//                     setState(() => _smsNotifications = val);
//                     setDialogState(() {});
//                   },
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: Text(t('إغلاق', 'Close', appState),
//                     style:
//                         TextStyle(color: accent, fontWeight: FontWeight.bold)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Privacy Policy Dialog ──────────────────────────────────────────
//   void _showPrivacyPolicyDialog(BuildContext context, AppState appState) {
//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white70 : Colors.black54;
//     final accent = const Color(0xFFD4A017);

//     showDialog(
//       context: context,
//       builder: (ctx) => Directionality(
//         textDirection:
//             appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
//         child: AlertDialog(
//           backgroundColor: surface,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: Row(
//             children: [
//               Icon(Icons.privacy_tip_outlined, color: accent, size: 22),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   t('سياسة الخصوصية', 'Privacy Policy', appState),
//                   style: GoogleFonts.cairo(
//                       color: text, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   t('سياسة خصوصية CraftGo', 'CraftGo Privacy Policy'),
//                   style: GoogleFonts.cairo(
//                       color: accent, fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   t(
//                     'نحن نلتزم بحماية بياناتك وسجلك التجاري. تُستخدم بيانات المعارض والتواصل حصرياً لتمكين الحرفيين والزوار من التفاعل بأمان مع معارضك.',
//                     'We are committed to protecting your data and commercial registration. Exhibition data and communication are used strictly to enable artisans and visitors to safely interact with your exhibitions.',
//                     appState,
//                   ),
//                   style: TextStyle(color: dim, height: 1.5),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   t('حماية البيانات والتراخيص', 'Data Protection & Licenses'),
//                   style: GoogleFonts.cairo(
//                       color: text, fontWeight: FontWeight.bold, fontSize: 14),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   t(
//                     'جميع التراخيص والسجلات مشفرة على خوادم آمنة وفقاً لمعايير الأمان المعتمدة.',
//                     'All licenses and records are encrypted on secure servers following standard security practices.',
//                     appState,
//                   ),
//                   style: TextStyle(color: dim, height: 1.5),
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             ElevatedButton(
//               onPressed: () => Navigator.pop(ctx),
//               style: ElevatedButton.styleFrom(backgroundColor: accent),
//               child: Text(
//                 t('أوافق', 'I Agree', appState),
//                 style: const TextStyle(
//                     color: Colors.black, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Logout Confirm Dialog ─────────────────────────────────────────
//   void _confirmLogout(BuildContext context, AppState appState) {
//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white70 : Colors.black54;

//     showDialog(
//       context: context,
//       builder: (ctx) => Directionality(
//         textDirection:
//             appState.isArabic ? TextDirection.rtl : TextDirection.ltr,
//         child: AlertDialog(
//           backgroundColor: surface,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: Text(
//             t('تأكيد تسجيل الخروج', 'Confirm Logout', appState),
//             style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
//           ),
//           content: Text(
//             t('هل أنت متأكد من أنك تريد تسجيل الخروج؟',
//                 'Are you sure you want to log out?', appState),
//             style: TextStyle(color: dim),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: Text(t('إلغاء', 'Cancel', appState),
//                   style: const TextStyle(color: Colors.grey)),
//             ),
//             TextButton(
//               onPressed: () async {
//                 Navigator.pop(ctx);
//                 await appState.logout();
//                 if (!context.mounted) return;
//                 Navigator.pushNamedAndRemoveUntil(
//                   context,
//                   '/onboarding',
//                   (route) => false,
//                 );
//               },
//               child: Text(t('تسجيل الخروج', 'Logout', appState),
//                   style: const TextStyle(
//                       color: Colors.redAccent, fontWeight: FontWeight.bold)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = context.watch<AppState>();
//     final isArabic = appState.isArabic;
//     final isDarkMode = appState.isDarkMode;
//     final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//     final text = isDarkMode ? Colors.white : Colors.black87;
//     final dim = isDarkMode ? Colors.white70 : Colors.black54;
//     final border = isDarkMode
//         ? Colors.white.withValues(alpha: 0.1)
//         : Colors.black.withValues(alpha: 0.1);
//     final accent = const Color(0xFFD4A017);

//     if (_isLoading) {
//       return Center(child: CircularProgressIndicator(color: accent));
//     }
//     if (_error.isNotEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, size: 48, color: Colors.red),
//             const SizedBox(height: 12),
//             Text(_error, style: TextStyle(color: text)),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _loadProfile,
//               child: Text(t('إعادة المحاولة', 'Retry', appState)),
//             ),
//           ],
//         ),
//       );
//     }

//     final exhibitionCount = appState.exhibitions.length;

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         children: [
//           const SizedBox(height: 10),

//           // Avatar & Header
//           CircleAvatar(
//             radius: 46,
//             backgroundColor: accent.withValues(alpha: 0.2),
//             backgroundImage:
//                 _profileImage.isNotEmpty ? NetworkImage(_profileImage) : null,
//             child: _profileImage.isEmpty
//                 ? Text(
//                     _name.isNotEmpty ? _name[0] : 'R',
//                     style: TextStyle(
//                         fontSize: 36,
//                         fontWeight: FontWeight.bold,
//                         color: accent),
//                   )
//                 : null,
//           ),
//           const SizedBox(height: 12),
//           Text(
//             _name,
//             style: GoogleFonts.cairo(
//                 color: text, fontSize: 22, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             _email,
//             style: GoogleFonts.cairo(color: dim, fontSize: 14),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             _phone.isNotEmpty
//                 ? _phone
//                 : t('غير محدد', 'Not specified', appState),
//             style: GoogleFonts.cairo(color: dim, fontSize: 13),
//           ),
//           const SizedBox(height: 10),

//           // Registration Badge
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//             decoration: BoxDecoration(
//               color: accent.withValues(alpha: 0.12),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: accent.withValues(alpha: 0.3)),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.verified, size: 16, color: accent),
//                 const SizedBox(width: 6),
//                 Flexible(
//                   child: Text(
//                     '${t('السجل التجاري:', 'Reg / License:', appState)} CR-9048123-JO',
//                     style: GoogleFonts.cairo(
//                         color: text, fontSize: 12, fontWeight: FontWeight.w600),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Edit Button
//           ElevatedButton.icon(
//             onPressed: () => _showEditProfileDialog(context, appState),
//             icon: const Icon(Icons.edit, size: 16, color: Colors.black),
//             label: Text(
//               t('تعديل الملف الشخصي', 'Edit Profile', appState),
//               style: GoogleFonts.cairo(
//                   color: Colors.black, fontWeight: FontWeight.bold),
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: accent,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20)),
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             ),
//           ),
//           const SizedBox(height: 28),

//           // Stats
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//             decoration: BoxDecoration(
//               color: surface,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: border),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Expanded(
//                   child: _buildStat(t('المعارض', 'Exhibitions', appState),
//                       '$exhibitionCount', text, dim),
//                 ),
//                 Container(width: 1, height: 36, color: border),
//                 Expanded(
//                   child: _buildStat(t('الحرفيون', 'Artisans', appState), '18', text, dim),
//                 ),
//                 Container(width: 1, height: 36, color: border),
//                 Expanded(
//                   child: _buildStat(t('الطلبات', 'Requests', appState), '15', text, dim),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 28),

//           // Settings Options
//           Container(
//             decoration: BoxDecoration(
//               color: surface,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: border),
//             ),
//             child: Column(
//               children: [
//                 _buildOptionTile(
//                   icon: Icons.lock_outline,
//                   title: t('تغيير كلمة المرور', 'Change Password', appState),
//                   onTap: () => _showChangePasswordDialog(context, appState),
//                   text: text,
//                   dim: dim,
//                   accent: accent,
//                   border: border,
//                   isArabic: isArabic,
//                 ),
//                 Divider(color: border, height: 1),
//                 _buildOptionTile(
//                   icon: Icons.notifications_outlined,
//                   title: t('تفضيلات الإشعارات', 'Notification Preferences',
//                       appState),
//                   onTap: () =>
//                       _showNotificationPreferencesDialog(context, appState),
//                   text: text,
//                   dim: dim,
//                   accent: accent,
//                   border: border,
//                   isArabic: isArabic,
//                 ),
//                 Divider(color: border, height: 1),
//                 _buildOptionTile(
//                   icon: Icons.privacy_tip_outlined,
//                   title: t('سياسة الخصوصية', 'Privacy Policy', appState),
//                   onTap: () => _showPrivacyPolicyDialog(context, appState),
//                   text: text,
//                   dim: dim,
//                   accent: accent,
//                   border: border,
//                   isArabic: isArabic,
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 24),

//           // Logout Button
//           OutlinedButton.icon(
//             onPressed: () => _confirmLogout(context, appState),
//             icon: const Icon(Icons.logout, color: Colors.redAccent),
//             label: Text(
//               t('تسجيل الخروج', 'Logout', appState),
//               style:
//                   GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Colors.redAccent,
//               side: const BorderSide(color: Colors.redAccent),
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               minimumSize: const Size(double.infinity, 50),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16)),
//             ),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }

//   Widget _buildStat(String label, String value, Color text, Color dim) {
//     return Column(
//       children: [
//         Text(value,
//             style: GoogleFonts.cairo(
//                 color: text, fontSize: 22, fontWeight: FontWeight.bold)),
//         Text(label, style: GoogleFonts.cairo(color: dim, fontSize: 13)),
//       ],
//     );
//   }

//   Widget _buildOptionTile({
//     required IconData icon,
//     required String title,
//     required VoidCallback onTap,
//     required Color text,
//     required Color dim,
//     required Color accent,
//     required Color border,
//     required bool isArabic,
//   }) {
//     return ListTile(
//       onTap: onTap,
//       leading: Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: accent.withValues(alpha: 0.1),
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Icon(icon, color: accent, size: 20),
//       ),
//       title: Text(
//         title,
//         style: GoogleFonts.cairo(
//             color: text, fontSize: 15, fontWeight: FontWeight.w600),
//       ),
//       trailing: Icon(
//         isArabic ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
//         color: dim,
//         size: 16,
//       ),
//     );
//   }
// }
