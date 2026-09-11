import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'session_service.dart';

class NotificationService {
  static Future<List<dynamic>> getNotifications() async {
    final token = await SessionService.getToken();

    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load notifications');
  }

  static Future<bool> markAsRead(String id) async {
    final token = await SessionService.getToken();

    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/notifications/$id/read'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  static Future<bool> markAllAsRead() async {
    final token = await SessionService.getToken();

    final response = await http.patch(
      Uri.parse('${ApiService.baseUrl}/notifications/read-all'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteNotification(String id) async {
    final token = await SessionService.getToken();

    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/notifications/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  static Future<bool> deleteAllNotifications() async {
    final token = await SessionService.getToken();

    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  static Future<void> scheduleExhibitionReminder({
    required String exhibitionId,
    required String exhibitionName,
    required DateTime reminderDate,
  }) async {
    // Store in local storage or use a scheduling library
    // For now, we'll log it and store it in shared_preferences
    final token = await SessionService.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/notifications/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'exhibitionId': exhibitionId,
          'exhibitionName': exhibitionName,
          'scheduledAt': reminderDate.toIso8601String(),
          'type': 'exhibition_reminder',
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Failed to schedule reminder: ${response.body}');
      }
    } catch (e) {
      debugPrint('Schedule reminder error: $e');
    }
  }
}
