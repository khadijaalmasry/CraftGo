import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api_service.dart';

class AdminService {
  static Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await ApiService.get('/admin/stats');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Fetch admin stats error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCraftsmanReport(String craftsmanId, {String period = 'all'}) async {
    try {
      final response = await ApiService.get('/admin/reports/craftsman/$craftsmanId?period=$period');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Fetch craftsman report error: $e');
      return null;
    }
  }
}
