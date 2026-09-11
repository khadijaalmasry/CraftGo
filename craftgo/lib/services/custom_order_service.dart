import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class CustomOrderService {
  static dynamic _toJsonSafe(dynamic value) {
    if (value is Color) {
      final hex = value.toARGB32().toRadixString(16).padLeft(8, '0');
      return '#${hex.substring(2).toUpperCase()}';
    }

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _toJsonSafe(val)),
      );
    }

    if (value is List) {
      return value.map(_toJsonSafe).toList();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    return value;
  }

  // ── TEMPLATES ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> createTemplate({
    required String titleAr,
    required String titleEn,
    required String categoryAr,
    required String categoryEn,
    required String descriptionAr,
    required String descriptionEn,
    required double basePrice,
    required int estimatedDays,
    required List<Map<String, dynamic>> fields,
  }) async {
    try {
      final response = await ApiService.post('/custom-orders/templates', body: {
        'titleAr': titleAr,
        'titleEn': titleEn,
        'categoryAr': categoryAr,
        'categoryEn': categoryEn,
        'descriptionAr': descriptionAr,
        'descriptionEn': descriptionEn,
        'basePrice': basePrice,
        'estimatedDays': estimatedDays,
        'fields': fields,
      });
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['template'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getTemplatesByArtisan(String artisanId) async {
    try {
      final response =
          await ApiService.get('/custom-orders/templates/artisan/$artisanId');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTemplateById(
      String templateId) async {
    try {
      final response =
          await ApiService.get('/custom-orders/templates/$templateId');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateTemplate(
      String templateId, Map<String, dynamic> fields) async {
    try {
      final response = await ApiService.put(
          '/custom-orders/templates/$templateId',
          body: fields);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTemplate(String templateId) async {
    try {
      final response =
          await ApiService.delete('/custom-orders/templates/$templateId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── REQUESTS ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> submitRequest({
    required String templateId,
    required Map<String, dynamic> filledFields,
  }) async {
    try {
      final response = await ApiService.post(
        '/custom-orders/requests',
        body: {
          'templateId': templateId,
          'filledFields': _toJsonSafe(filledFields),
        },
      );

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final request = decoded['request'];

          if (request is Map<String, dynamic>) {
            return request;
          }

          // Support APIs that return the created request directly.
          return decoded;
        }

        throw Exception(
          'Invalid create-request response: ${response.body}',
        );
      }

      throw Exception(
        'POST /custom-orders/requests failed '
        '(${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> getRequestsByArtisan(String artisanId) async {
    try {
      final response =
          await ApiService.get('/custom-orders/requests/artisan/$artisanId');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getRequestsByCustomer(String customerId) async {
    try {
      final response =
          await ApiService.get('/custom-orders/requests/customer/$customerId');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> artisanRespond({
    required String requestId,
    required List<Map<String, dynamic>> breakdown,
    required List<String> tasks,
    required String deliveryDate,
    required String notesAr,
    required String notesEn,
  }) async {
    try {
      final response = await ApiService.post(
          '/custom-orders/requests/$requestId/respond',
          body: {
            'breakdown': breakdown,
            'tasks': tasks,
            'deliveryDate': deliveryDate,
            'notesAr': notesAr,
            'notesEn': notesEn,
          });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateRequestStatus(
      String requestId, String status) async {
    try {
      final response = await ApiService.patch(
          '/custom-orders/requests/$requestId/status',
          body: {'status': status});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateRequestProgress({
    required String requestId,
    required String progressStage,
    required int progressPercent,
  }) async {
    try {
      final response = await ApiService.patch(
        '/custom-orders/requests/$requestId/progress',
        body: {
          'progressStage': progressStage,
          'progressPercent': progressPercent,
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      debugPrint(
        'Update custom order progress failed '
        '(${response.statusCode}): ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('Update custom order progress error: $e');
      return false;
    }
  }

  static Future<bool> signContract(String requestId) async {
    try {
      final response =
          await ApiService.post('/custom-orders/requests/$requestId/sign');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

// Add to CustomOrderService
  static Future<bool> updateDeliveryInfo({
    required String requestId,
    required String deliveryAddress,
    required String customerPhone,
  }) async {
    try {
      final response = await ApiService.patch(
        '/custom-orders/requests/$requestId/delivery',
        body: {
          'deliveryAddress': deliveryAddress,
          'customerPhone': customerPhone,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateDeliveryInfo error: $e');
      return false;
    }
  }
}
