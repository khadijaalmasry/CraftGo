import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api_service.dart';
import 'session_service.dart';

class AuthService {
  /// الباك-إند قد يرجع 'role' (string مفرد) أو 'roles' (array)
  /// هذا الـ helper يتعامل مع الحالتين
  static List<String> _parseRoles(Map<String, dynamic> user) {
    final raw = user['roles'] ?? user['role'];
    if (raw == null) return [];
    if (raw is List) return List<String>.from(raw);
    return [raw.toString()];
  }

  // Send OTP to email
  static Future<bool> sendOtp(String email) async {
    try {
      final response =
      await ApiService.post('/auth/send-otp', body: {'email': email});
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  // Verify OTP
  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await ApiService.post('/auth/verify-otp',
          body: {'email': email, 'otp': otp});
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  // Signup – now accepts List<String> roles
  static Future<Map<String, dynamic>?> signup({
    required String name,
    required String email,
    required String password,
    required List<String> roles,
    String city = '',
    String phone = '',
    String category = '',
    int experienceYears = 0,
    String bio = '',
    String? priceRange,
    List<String>? specializations,
    bool trustedHands = false,
    Map<String, dynamic>? idVerificationDetails,
    List<String>? portfolioImageUrls,
    String? driverLicenseUrl,
    String? vehicleType,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'roles': roles,
        'city': city,
        'phone': phone,
        'category': category,
        'experienceYears': experienceYears,
        'bio': bio,
        'priceRange': priceRange,
        'specializations': specializations ?? [],
        'trustedHands': trustedHands,
        if (idVerificationDetails != null)
          'idVerificationDetails': idVerificationDetails,
        if (portfolioImageUrls != null)
          'portfolioImageUrls': portfolioImageUrls,
        if (driverLicenseUrl != null)
          'driverLicenseUrl': driverLicenseUrl,
        if (vehicleType != null)
          'vehicleType': vehicleType,
      };

      debugPrint('========== SIGNUP REQUEST ==========');
      debugPrint('Email: $email');
      debugPrint('Roles: $roles');
      debugPrint('Category: $category');
      debugPrint('Trusted Hands: $trustedHands');
      debugPrint('Portfolio images: ${portfolioImageUrls?.length ?? 0}');
      debugPrint('Request body: ${jsonEncode(requestBody)}');

      final response = await ApiService.post(
        '/auth/signup',
        body: requestBody,
      );

      debugPrint('========== SIGNUP RESPONSE ==========');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('=====================================');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = Map<String, dynamic>.from(data['user'] as Map);
        final parsedRoles = _parseRoles(user);

        await SessionService.saveSession(
          userId: user['id']?.toString() ?? '',
          name: user['name']?.toString() ?? '',
          email: user['email']?.toString() ?? '',
          roles: parsedRoles,
          token: data['token']?.toString() ?? '',
          isVerified: user['isVerified'] == true,
        );

        user['roles'] = parsedRoles;
        return user;
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('========== SIGNUP ERROR ==========');
      debugPrint(e.toString());
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==================================');
      return null;
    }
  }


// Login – now expects roles array in response
  static Future<Map<String, dynamic>?> login(
      String email, String password) async {
    try {
      final response = await ApiService.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];
        final parsedRoles = _parseRoles(user);
        await SessionService.saveSession(
          userId: user['id']?.toString() ?? '',
          name: user['name'] ?? '',
          email: user['email'] ?? '',
          roles: parsedRoles,
          token: data['token'] ?? '',
          isVerified: user['isVerified'] == true,
        );
        user['roles'] = parsedRoles;
        return user;
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      return null;
    }
  }

  // Get current user profile
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await ApiService.get('/auth/me');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    await SessionService.clearSession();
  }
}
