// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class ApiService {
//   // Use 10.0.2.2 for Android emulator, or your machine's IP for physical device.
//   // Using localhost/127.0.0.1 for Web/Windows.
//   static const String baseUrl = 'http://localhost:5000/api';

//   static Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('auth_token');
//   }

//   static Future<void> saveToken(String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('auth_token', token);
//   }

//   static Future<void> saveUserRole(String role) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user_role', role);
//   }

//   static Future<String?> getUserRole() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('user_role');
//   }

//   static Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('auth_token');
//     await prefs.remove('user_role');
//   }

//   static Future<Map<String, dynamic>?> login(String email, String password) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'email': email, 'password': password}),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         await saveToken(data['token']);
//         await saveUserRole(data['user']['role']);
//         return data['user'];
//       }
//       return null;
//     } catch (e) {
//       print('Login error: $e');
//       return null;
//     }
//   }

//   static Future<Map<String, dynamic>?> signup(String name, String email, String password, String role) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/signup'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'name': name,
//           'email': email,
//           'password': password,
//           'role': role,
//         }),
//       );

//       if (response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//         await saveToken(data['token']);
//         await saveUserRole(data['user']['role']);
//         return data['user'];
//       }
//       return null;
//     } catch (e) {
//       print('Signup error: $e');
//       return null;
//     }
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // ─── BASE URL ──────────────────────────────────────────────────────────
  // For a physical Android device, use your computer's local IP.
  // For emulator, use 10.0.2.2. For web/desktop, use localhost.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.171.233.18:5000/api';
    } else {
      return 'http://localhost:5000/api';
    }
  }

  // ─── HEADERS ──────────────────────────────────────────────────────────
  static Future<Map<String, String>> _getHeaders() async {
    final token = await SessionService.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── HTTP METHODS ────────────────────────────────────────────────────
  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }

  static Future<http.Response> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> patch(String endpoint,
      {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    return await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }
}
