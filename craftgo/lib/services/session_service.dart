import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all session persistence: user data, roles, and login state.
class SessionService {
  static const _keyUserId = 'session_user_id';
  static const _keyUserName = 'session_user_name';
  static const _keyUserEmail = 'session_user_email';
  static const _keyUserCity = 'session_user_city';
  static const _keyToken = 'auth_token';
  static const _keyRoles = 'session_user_roles';
  static const _keyIsVerified =
      'session_is_verified'; // artisan approval status
  static const _keyHasSeenApproval = 'has_seen_approval_dialog';
  static const _keyIsArabic = 'settings_is_arabic';
  static const _keyIsDarkMode = 'settings_is_dark_mode';
  static const _keyActiveRole = 'session_active_role';

  static String _approvalSeenKey(String userId) {
    final normalizedId = userId.trim();
    return normalizedId.isNotEmpty
        ? '${_keyHasSeenApproval}_$normalizedId'
        : _keyHasSeenApproval;
  }

  // ── Save full session after login/signup ──────────────────────────────────
  static Future<void> saveSession({
    required String userId,
    required String name,
    required String email,
    required List<String> roles,
    String city = '',
    String token = '',
    bool isVerified = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserCity, city);
    if (token.isNotEmpty) await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRoles, jsonEncode(roles));
    await prefs.setBool(_keyIsVerified, isVerified);
  }

  // ── Read session ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rolesJson = prefs.getString(_keyRoles) ?? '[]';
    final roles = List<String>.from(jsonDecode(rolesJson));
    final token = prefs.getString(_keyToken);

    return {
      'userId': prefs.getString(_keyUserId),
      'name': prefs.getString(_keyUserName),
      'email': prefs.getString(_keyUserEmail),
      'city': prefs.getString(_keyUserCity),
      'token': token,
      'roles': roles,
      'isVerified': prefs.getBool(_keyIsVerified) ?? false,
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }

  static Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final userId = prefs.getString(_keyUserId);
    final rolesJson = prefs.getString(_keyRoles);

    if (token == null || token.trim().isEmpty) return false;
    if (userId == null || userId.trim().isEmpty) return false;
    if (rolesJson == null || rolesJson.trim().isEmpty) return false;

    try {
      final roles = List<String>.from(jsonDecode(rolesJson));
      return roles.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> getRoles() async {
    final session = await getSession();
    return session['roles'] ?? [];
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    return token;
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  // ── Clear session on logout ───────────────────────────────────────────────
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserCity);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRoles);
    await prefs.remove(_keyIsVerified);
    await prefs.remove(_keyActiveRole);
    // Note: _keyHasSeenApproval is intentionally NOT removed here,
    // so the approval welcome dialog only shows once ever.
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  static Future<void> saveSettings(
      {required bool isArabic, required bool isDarkMode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsArabic, isArabic);
    await prefs.setBool(_keyIsDarkMode, isDarkMode);
  }

  static Future<Map<String, bool>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isArabic': prefs.getBool(_keyIsArabic) ?? true, // Default true
      'isDarkMode': prefs.getBool(_keyIsDarkMode) ?? false, // Default true
    };
  }

  // ── Approval Notification ──────────────────────────────────────────────
  //
  // This is a per-user duplicate guard. The CraftsmanShell decides WHEN the
  // dialog is allowed to appear (only on non-approved -> approved transition).
  static Future<bool> hasSeenApprovalDialog({String userId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_approvalSeenKey(userId)) ?? false;
  }

  static Future<void> setHasSeenApprovalDialog({String userId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_approvalSeenKey(userId), true);
  }

  static Future<void> saveActiveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveRole, role);
  }

  static Future<String?> getActiveRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActiveRole);
  }
}
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

// class SessionService {
//   static const _keyUserId = 'session_user_id';
//   static const _keyUserName = 'session_user_name';
//   static const _keyUserEmail = 'session_user_email';
//   static const _keyUserCity = 'session_user_city';
//   static const _keyToken = 'auth_token';
//   static const _keyRoles = 'session_user_roles'; // new

//   static Future<void> saveSession({
//     required String userId,
//     required String name,
//     required String email,
//     required List<String> roles,
//     String city = '',
//     String token = '',
//   }) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_keyUserId, userId);
//     await prefs.setString(_keyUserName, name);
//     await prefs.setString(_keyUserEmail, email);
//     await prefs.setString(_keyUserCity, city);
//     if (token.isNotEmpty) await prefs.setString(_keyToken, token);
//     // Store roles as JSON array string
//     await prefs.setString(_keyRoles, jsonEncode(roles));
//   }

//   static Future<Map<String, dynamic>> getSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     final rolesJson = prefs.getString(_keyRoles) ?? '[]';
//     final roles = List<String>.from(jsonDecode(rolesJson));
//     return {
//       'userId': prefs.getString(_keyUserId),
//       'name': prefs.getString(_keyUserName),
//       'email': prefs.getString(_keyUserEmail),
//       'city': prefs.getString(_keyUserCity),
//       'token': prefs.getString(_keyToken),
//       'roles': roles,
//     };
//   }

//   static Future<bool> isLoggedIn() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString(_keyToken);
//     return token != null && token.isNotEmpty;
//   }

//   static Future<List<String>> getRoles() async {
//     final session = await getSession();
//     return session['roles'] ?? [];
//   }

//   static Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_keyToken);
//   }

//   static Future<String?> getName() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_keyUserName);
//   }

//   static Future<void> clearSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_keyUserId);
//     await prefs.remove(_keyUserName);
//     await prefs.remove(_keyUserEmail);
//     await prefs.remove(_keyUserCity);
//     await prefs.remove(_keyToken);
//     await prefs.remove(_keyRoles);
//   }
// }
