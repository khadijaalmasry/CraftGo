import 'dart:convert';
import 'api_service.dart';

class DisputeService {
  // ── Submit a dispute (Customer or Craftsman) ─────────────────────────────────
  // At least one of [orderId, customOrderRequestId, hireRequestId] is required.
  static Future<Map<String, dynamic>> submitDispute({
    String? orderId,
    String? customOrderRequestId,
    String? hireRequestId,
    String? deliveryOrderId,
    required String issueCategory,
    required String description,
    String? photoUrl,
    String requestedAction = 'none',
  }) async {
    final body = {
      if (orderId != null) 'orderId': orderId,
      if (customOrderRequestId != null)
        'customOrderRequestId': customOrderRequestId,
      if (hireRequestId != null) 'hireRequestId': hireRequestId,
      if (deliveryOrderId != null) 'deliveryOrderId': deliveryOrderId,
      'issueCategory': issueCategory,
      'description': description,
      'requestedAction': requestedAction,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };

    final res =
        await ApiService.post('/disputes', body: body); // ✅ named parameter
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) return data;
    throw Exception(data['error'] ?? 'Failed to submit dispute');
  }

  // ── Get current user's own disputes ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMyDisputes() async {
    final res = await ApiService.get('/disputes/my');
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final list = data['disputes'] as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Failed to load your disputes');
  }

  // ── Admin: Get all disputes (optionally filtered by status) ──────────────────
  static Future<Map<String, dynamic>> getAdminDisputes({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final res = await ApiService.get('/admin/disputes$query');
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body) as Map);
    }
    throw Exception('Failed to load disputes');
  }

  // ── Admin: Get single dispute detail ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getDisputeById(String disputeId) async {
    final res = await ApiService.get('/admin/disputes/$disputeId');
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(res.body) as Map);
    }
    throw Exception('Failed to load dispute');
  }

  // ── Admin: Resolve a dispute ─────────────────────────────────────────────────
  // resolutionType: 'customer_refund' | 'artisan_release' | 'driver_penalty' | 'no_action'
  static Future<Map<String, dynamic>> resolveDispute({
    required String disputeId,
    required String resolutionType,
    String? adminNotes,
  }) async {
    final res = await ApiService.patch(
      '/admin/disputes/$disputeId/resolve',
      body: {
        // ✅ named parameter
        'resolutionType': resolutionType,
        if (adminNotes != null && adminNotes.isNotEmpty)
          'adminNotes': adminNotes,
      },
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed to resolve dispute');
  }

  // ── Issue category labels ─────────────────────────────────────────────────────
  static String issueCategoryLabel(String category, {bool arabic = false}) {
    final labels = <String, List<String>>{
      'damaged_in_transit': ['تلف أثناء التوصيل', 'Damaged in Transit'],
      'wrong_item': ['منتج خاطئ', 'Wrong Item'],
      'quality_issue': ['جودة رديئة', 'Quality Issue'],
      'customer_unresponsive': ['العميل لا يرد', 'Customer Unresponsive'],
      'delivery_fault': ['خطأ التوصيل', 'Delivery Fault'],
      'other': ['أخرى', 'Other'],
    };
    final pair = labels[category] ?? ['أخرى', 'Other'];
    return arabic ? pair[0] : pair[1];
  }

  static String adminStatusLabel(String status, {bool arabic = false}) {
    final labels = <String, List<String>>{
      'pending': ['قيد الانتظار', 'Pending'],
      'under_review': ['قيد المراجعة', 'Under Review'],
      'resolved_refunded': ['تم استرداد المبلغ', 'Refunded'],
      'resolved_released': ['تم إطلاق الأموال', 'Released'],
      'dismissed': ['مرفوض', 'Dismissed'],
    };
    final pair = labels[status] ?? ['غير معروف', 'Unknown'];
    return arabic ? pair[0] : pair[1];
  }
}
