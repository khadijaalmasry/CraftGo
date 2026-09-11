// lib/app_state.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/main_shell.dart';
import 'core/admin_shell.dart';
import 'core/craftsman_shell.dart';
import 'core/exhibition_owner_shell.dart';
import 'core/delivery_shell.dart';
import 'services/session_service.dart';
import 'services/craftsman_service.dart';
import 'package:flutter/services.dart';

class AppState extends ChangeNotifier {
  // ── User State ────────────────────────────────────────────────────────────
  String? _userId;
  String? _userName;
  String? _token;
  bool _isLoggedIn = false;
  bool _isGuest = false;
  bool _isVerified = false;

  // ── Multiple Roles & Active Role ────────────────────────────────────────
  List<String> _roles = [];
  String? _activeRole; // 'customer', 'artisan', 'exhibition_owner', 'admin'

  String? get userId => _userId;
  String? get userName => _userName;
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isVerified => _isVerified;
  List<String> get roles => _roles;
  String? get activeRole => _activeRole;

  // For backward compatibility
  String? get userRole => _activeRole;

  // ── Theme & Language ─────────────────────────────────────────────────────
  bool _isArabic = true;
  bool _isDarkMode = false;

  bool get isArabic => _isArabic;
  bool get isDarkMode => _isDarkMode;

  // ── Language Toggle ──────────────────────────────────────────────────────
  void toggleLanguage() {
    _isArabic = !_isArabic;
    notifyListeners();
  }

  void setLanguage(bool isArabic) {
    _isArabic = isArabic;
    notifyListeners();
  }

  // ── Theme Toggle ─────────────────────────────────────────────────────────
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTheme(bool isDarkMode) {
    _isDarkMode = isDarkMode;
    notifyListeners();
  }

  // ── Starred Artisans ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _starredArtisans = [];

  List<Map<String, dynamic>> get starredArtisans => _starredArtisans;

  Future<void> fetchFavoriteArtisans() async {
    if (!_isLoggedIn) return;
    try {
      final list = await CraftsmanService.getFavoriteArtisans();
      _starredArtisans = list;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorite artisans: $e');
    }
  }

  void toggleStarredArtisan(Map<String, dynamic> artisan) {
    final artisanId = artisan['id']?.toString() ?? '';
    if (artisanId.isEmpty) return;

    final index =
        _starredArtisans.indexWhere((a) => a['id']?.toString() == artisanId);
    final isRemoving = index != -1;

    if (isRemoving) {
      _starredArtisans.removeAt(index);
    } else {
      _starredArtisans.add(Map<String, dynamic>.from(artisan));
    }
    notifyListeners();

    if (_isLoggedIn) {
      if (isRemoving) {
        CraftsmanService.removeFavoriteArtisan(artisanId);
      } else {
        CraftsmanService.addFavoriteArtisan(artisanId);
      }
    }
  }

  bool isArtisanStarred(String artisanId) {
    return _starredArtisans.any((a) => a['id']?.toString() == artisanId);
  }

  // ── Global in-memory exhibitions list ────────────────────────────────────
  List<Map<String, dynamic>> _exhibitions = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get exhibitions => _exhibitions;
  bool get isLoading => _isLoading;

  AppState() {
    _loadInitialMockData();
    _applySystemThemeIfNeeded();
  }

  Future<void> _applySystemThemeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSavedTheme = prefs.containsKey('settings_is_dark_mode');
    if (!hasSavedTheme) {
      // Get system brightness
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;
      setTheme(isDark);
      // Save so we don't override user choice later
      await SessionService.saveSettings(
        isArabic: _isArabic,
        isDarkMode: isDark,
      );
    }
  }

  void _loadInitialMockData() {
    Future.delayed(const Duration(milliseconds: 200), () {
      _exhibitions = [
        {
          'id': '1',
          'name': 'أسبوع الحرف اليدوية بعمّان',
          'nameEn': 'Amman Handmade Week',
          'status': 'Active',
          'type': 'Public',
          'location': 'عمّان',
          'locationEn': 'Amman',
          'startDate': '2026-07-01',
          'endDate': '2026-07-15',
          'selectedDates': [
            {'date': '2026-07-01', 'start': '10:00', 'end': '18:00'},
            {'date': '2026-07-02', 'start': '10:00', 'end': '18:00'},
            {'date': '2026-07-03', 'start': '10:00', 'end': '18:00'},
          ],
          'interested': 150,
          'gradient': [const Color(0xFF1976D2), const Color(0xFF009688)],
          'description': 'معرض أسبوعي للحرف اليدوية',
          'maxCapacity': 20,
          'boothRows': 2,
          'boothColumns': 3,
          'boothPrice': 25.0,
          'participants': [],
        },
        {
          'id': '2',
          'name': 'سوق رمضان الحرفي',
          'nameEn': 'Ramadan Craft Market',
          'status': 'Upcoming',
          'type': 'Public',
          'location': 'إربد',
          'locationEn': 'Irbid',
          'startDate': '2026-03-20',
          'endDate': '2026-03-30',
          'selectedDates': [
            {'date': '2026-03-20', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-21', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-22', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-23', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-24', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-25', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-26', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-27', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-28', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-29', 'start': '16:00', 'end': '23:00'},
            {'date': '2026-03-30', 'start': '16:00', 'end': '23:00'},
          ],
          'interested': 80,
          'gradient': [const Color(0xFFE64A19), const Color(0xFFD32F2F)],
          'description': 'سوق حرفي رمضاني مميز',
          'maxCapacity': 15,
          'boothRows': 2,
          'boothColumns': 4,
          'boothPrice': 20.0,
          'participants': [],
        },
        {
          'id': '3',
          'name': 'معرض الفنون الشعبية',
          'nameEn': 'Folk Arts Fair',
          'status': 'Past',
          'type': 'Public',
          'location': 'الزرقاء',
          'locationEn': 'Zarqa',
          'startDate': '2026-08-10',
          'endDate': '2026-08-20',
          'selectedDates': [
            {'date': '2026-08-10', 'start': '10:00', 'end': '18:00'},
          ],
          'interested': 40,
          'gradient': [const Color(0xFF7B1FA2), const Color(0xFF3F51B5)],
          'description': 'معرض متسلس للفنون الشعبية والتراثية',
          'maxCapacity': 12,
          'boothRows': 2,
          'boothColumns': 3,
          'boothPrice': 15.0,
          'participants': [],
        },
        {
          'id': '4',
          'name': 'يرموك للحرف التراثية',
          'nameEn': 'Yarmouk Heritage Crafts',
          'status': 'Upcoming',
          'type': 'Private',
          'location': 'إربد',
          'locationEn': 'Irbid',
          'startDate': '2026-09-01',
          'endDate': '2026-09-07',
          'selectedDates': [
            {'date': '2026-09-01', 'start': '09:00', 'end': '17:00'},
          ],
          'interested': 25,
          'gradient': [const Color(0xFF388E3C), const Color(0xFF00796B)],
          'description': 'معرض خاص بالحرف التراثية في إربد',
          'maxCapacity': 10,
          'boothRows': 2,
          'boothColumns': 2,
          'boothPrice': 30.0,
          'participants': [],
        },
        {
          'id': '5',
          'name': 'بازار الشتاء',
          'nameEn': 'Winter Bazaar',
          'status': 'Past',
          'type': 'Public',
          'location': 'عمّان',
          'locationEn': 'Amman',
          'startDate': '2025-12-15',
          'endDate': '2025-12-20',
          'interested': 210,
          'gradient': [const Color(0xFF455A64), const Color(0xFF1976D2)],
          'description': 'بازار الشتاء للحرف اليدوية والمأكولات الشعبية',
          'maxCapacity': 16,
          'boothRows': 2,
          'boothColumns': 4,
          'boothPrice': 35.0,
          'participants': [],
        },
      ];
      _isLoading = false;
      notifyListeners();
    });
  }

  void addOrUpdateExhibition(Map<String, dynamic> exhibition) {
    final index = _exhibitions.indexWhere((e) => e['id'] == exhibition['id']);
    if (index != -1) {
      _exhibitions[index] = exhibition;
    } else {
      _exhibitions.insert(0, exhibition);
    }
    notifyListeners();
  }

  void deleteExhibition(Map<String, dynamic> exhibition) {
    _exhibitions.removeWhere((e) => e['id'] == exhibition['id']);
    notifyListeners();
  }

// lib/app_state.dart
  Future<void> loadSession() async {
    final session = await SessionService.getSession();
    final token = session['token'] as String?;
    if (token != null && token.isNotEmpty) {
      _userId = session['userId'] as String?;
      _userName = session['name'] as String?;
      _token = token;
      _roles = session['roles'] as List<String>? ?? [];
      _isVerified = session['isVerified'] as bool? ?? false;
      _isLoggedIn = true;
      _isGuest = false;

      // Restore active role from session
      final savedRole = await SessionService.getActiveRole();
      if (savedRole != null && _roles.contains(savedRole)) {
        _activeRole = savedRole;
      } else if (_roles.length == 1) {
        _activeRole = _roles.first;
      } else {
        // Multiple roles but no saved active role – default to first
        _activeRole = _roles.first;
      }

      notifyListeners();
      print(
          'Session loaded. Roles: $_roles, Active: $_activeRole, Token: $_token');
      fetchFavoriteArtisans();
    }
  }
  // Future<void> loadSession() async {
  //   final session = await SessionService.getSession();
  //   final token = session['token'] as String?;
  //   if (token != null && token.isNotEmpty) {
  //     _userId = session['userId'] as String?;
  //     _userName = session['name'] as String?;
  //     _token = token;
  //     _roles = session['roles'] as List<String>? ?? [];
  //     _isVerified = session['isVerified'] as bool? ?? false;
  //     _isLoggedIn = true;
  //     _isGuest = false;
  //     if (_roles.length == 1) {
  //       _activeRole = _roles.first;
  //     }
  //     notifyListeners();
  //     print('Session loaded. Roles: $_roles, Token: $_token');
  //     fetchFavoriteArtisans();
  //   }
  // }

  // ── Auth Methods ─────────────────────────────────────────────────────────
  void setAuth({
    required String userId,
    required String userName,
    required String token,
    List<String> roles = const [],
    bool isVerified = false,
    String? activeRole, // new optional parameter
  }) {
    _userId = userId;
    _userName = userName;
    _token = token;
    _roles = roles;
    _isVerified = isVerified;
    _isLoggedIn = true;
    _isGuest = false;

    // Set active role
    if (activeRole != null && roles.contains(activeRole)) {
      _activeRole = activeRole;
    } else {
      _activeRole = roles.isNotEmpty ? roles.first : null;
    }

    // Save active role to session
    if (_activeRole != null) {
      SessionService.saveActiveRole(_activeRole!);
    }

    print('Auth set. Roles: $roles, Active: $_activeRole, Token: $token');
    notifyListeners();
    fetchFavoriteArtisans();
  }

  void setGuest() {
    _userId = 'guest-${DateTime.now().millisecondsSinceEpoch}';
    _userName = 'Guest';
    _roles = ['customer'];
    _activeRole = 'customer';
    _token = null;
    _isLoggedIn = false;
    _isGuest = true;
    _starredArtisans.clear();
    notifyListeners();
  }

  Future<void> logout() async {
    _userId = null;
    _userName = null;
    _token = null;
    _roles = [];
    _activeRole = null;
    _isLoggedIn = false;
    _isGuest = false;
    _starredArtisans.clear();
    await SessionService.clearSession();
    notifyListeners();
  }

  // ── Role Management ──────────────────────────────────────────────────────
  void setActiveRole(String role) {
    if (_roles.contains(role)) {
      _activeRole = role;
      notifyListeners();
    }
  }

  bool hasRole(String role) => _roles.contains(role);

  // ── Update User Info ─────────────────────────────────────────────────────
  void updateUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  // ── Convenience Getters ──────────────────────────────────────────────────
  bool get isCustomer => _activeRole == 'customer' || _isGuest;
  bool get isArtisan => _activeRole == 'artisan';
  bool get isAdmin => _activeRole == 'admin';
  bool get isExhibitionOwner => _activeRole == 'exhibition_owner';

  // ── Helper to get the appropriate shell widget ─────────────────────────
  Widget getShellForActiveRole() {
    if (_isGuest) {
      return MainShell(
        isGuest: true,
        userName: 'Guest',
      );
    }

    switch (_activeRole) {
      case 'customer':
        return MainShell(
          isGuest: false,
          userName: _userName ?? 'User',
        );
      case 'delivery':
        return const DeliveryShell();
      case 'artisan':
        return CraftsmanShell(
          isArabic: _isArabic,
          isDarkMode: _isDarkMode,
          onToggleLanguage: toggleLanguage,
          onToggleTheme: toggleTheme,
          craftsmanName: _userName ?? 'Artisan',
          craftsmanCategoryAr: 'حرف يدوية',
          craftsmanCategoryEn: 'Handicrafts',
          craftsmanCity: 'عمان',
          craftsmanBio: 'حرفي مبدع',
          craftsmanExperience: '5 سنوات',
          isVerified: _isVerified,
        );
      case 'exhibition_owner':
        return ExhibitionOwnerShell(
          ownerName: _userName ?? 'Owner',
        );
      case 'admin':
        return AdminShell();
      default:
        return MainShell(
          isGuest: false,
          userName: _userName ?? 'User',
        );
    }
  }
}
