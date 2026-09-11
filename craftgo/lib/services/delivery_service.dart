import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class DeliveryService {
  // ───────────────────────────────────────────────────────────────────────────
  // DASHBOARD
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/dashboard/:driverId
  /// Returns: { isOnline, rating, stats, vehicle, hasActiveOrder, activeOrder }
  static Future<Map<String, dynamic>?> getDashboard(String driverId) async {
    try {
      final response = await ApiService.get('/delivery/dashboard/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get dashboard error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ORDERS
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/orders/available
  static Future<List<dynamic>> getAvailableOrders() async {
    try {
      final response = await ApiService.get('/delivery/orders/available');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get available orders error: $e');
      return [];
    }
  }

  /// GET /api/delivery/orders/driver/:driverId?status=xxx
  static Future<List<dynamic>> getDriverOrders(
    String driverId, {
    String? status,
  }) async {
    try {
      final query = status != null ? '?status=$status' : '';
      final response =
          await ApiService.get('/delivery/orders/driver/$driverId$query');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get driver orders error: $e');
      return [];
    }
  }

  /// GET /api/delivery/orders/:id
  static Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final response = await ApiService.get('/delivery/orders/$orderId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get order by ID error: $e');
      return null;
    }
  }

  /// POST /api/delivery/orders/:id/accept
  static Future<Map<String, dynamic>?> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    try {
      final response = await ApiService.post(
        '/delivery/orders/$orderId/accept',
        body: {'driverId': driverId},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Accept order error: $e');
      return null;
    }
  }

  /// PATCH /api/delivery/orders/:id/status
  static Future<Map<String, dynamic>?> updateOrderStatus({
    required String orderId,
    required String status,
    double? rating,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> body = {'status': status};
      if (rating != null) body['rating'] = rating;
      if (notes != null) body['notes'] = notes;
      final response = await ApiService.patch(
        '/delivery/orders/$orderId/status',
        body: body,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Update order status error: $e');
      return null;
    }
  }

  /// POST /api/delivery/orders/:id/verify-pin
  static Future<Map<String, dynamic>?> verifyDeliveryPinOrQR({
    required String orderId,
    String? pin,
    String? qrData,
  }) async {
    try {
      final response = await ApiService.post(
        '/delivery/orders/$orderId/verify-pin',
        body: {
          if (pin != null) 'pin': pin,
          if (qrData != null) 'qrData': qrData,
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Verify delivery PIN error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/notifications/:driverId
  static Future<List<dynamic>?> getNotifications(String driverId) async {
    try {
      final response =
          await ApiService.get('/delivery/notifications/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      print('Get notifications error: $e');
      return null;
    }
  }

  /// PATCH /api/delivery/notifications/:notificationId/read
  static Future<Map<String, dynamic>?> markNotificationRead(
    String notificationId,
  ) async {
    try {
      final response = await ApiService.patch(
        '/delivery/notifications/$notificationId/read',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Mark notification read error: $e');
      return null;
    }
  }

  /// PATCH /api/delivery/notifications/read-all/:driverId
  static Future<Map<String, dynamic>?> markAllNotificationsRead(
    String driverId,
  ) async {
    try {
      final response = await ApiService.patch(
        '/delivery/notifications/read-all/$driverId',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Mark all notifications read error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EARNINGS
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/earnings/:driverId
  static Future<Map<String, dynamic>?> getEarnings(String driverId) async {
    try {
      final response = await ApiService.get('/delivery/earnings/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get earnings error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VEHICLE
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/vehicle/:driverId
  static Future<Map<String, dynamic>?> getVehicle(String driverId) async {
    try {
      final response = await ApiService.get('/delivery/vehicle/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get vehicle error: $e');
      return null;
    }
  }

  /// PUT /api/delivery/vehicle/:driverId
  static Future<Map<String, dynamic>?> updateVehicle({
    required String driverId,
    String? make,
    String? model,
    String? year,
    String? color,
    String? colorEn,
    String? licensePlate,
    String? type,
    String? typeEn,
    String? capacity,
    String? capacityEn,
    String? photoUrl,
  }) async {
    try {
      final body = {
        if (make != null) 'make': make,
        if (model != null) 'model': model,
        if (year != null) 'year': year,
        if (color != null) 'color': color,
        if (colorEn != null) 'colorEn': colorEn,
        if (licensePlate != null) 'licensePlate': licensePlate,
        if (type != null) 'type': type,
        if (typeEn != null) 'typeEn': typeEn,
        if (capacity != null) 'capacity': capacity,
        if (capacityEn != null) 'capacityEn': capacityEn,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
      final response = await ApiService.put(
        '/delivery/vehicle/$driverId',
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Extract inner vehicle object if present
        if (data.containsKey('vehicle') &&
            data['vehicle'] is Map<String, dynamic>) {
          return data['vehicle'] as Map<String, dynamic>;
        }
        return data;
      }
      return null;
    } catch (e) {
      print('Update vehicle error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AVAILABILITY
  // ───────────────────────────────────────────────────────────────────────────

  /// PATCH /api/delivery/status/:driverId
  static Future<Map<String, dynamic>?> toggleAvailability({
    required String driverId,
    required bool isOnline,
  }) async {
    try {
      final response = await ApiService.patch(
        '/delivery/status/$driverId',
        body: {'isOnline': isOnline},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Toggle availability error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PROFILE
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/delivery/profile/:driverId
  static Future<Map<String, dynamic>?> getProfile(String driverId) async {
    try {
      final response = await ApiService.get('/delivery/profile/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get profile error: $e');
      return null;
    }
  }

  /// PUT /api/delivery/profile/:driverId
  static Future<Map<String, dynamic>?> updateProfile({
    required String driverId,
    String? name,
    String? city,
    String? profileImage,
  }) async {
    try {
      final body = {
        if (name != null) 'name': name,
        if (city != null) 'city': city,
        if (profileImage != null) 'profileImage': profileImage,
      };
      final response = await ApiService.put(
        '/delivery/profile/$driverId',
        body: body,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  /// POST /api/delivery/onboard/:driverId
  /// Creates a Stripe Express account (if needed) and returns an onboarding URL
  static Future<Map<String, dynamic>?> createOnboardLink(
      String driverId) async {
    try {
      final response = await ApiService.post('/delivery/onboard/$driverId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Create onboard link error: $e');
      return null;
    }
  }

  /// Report delivery issue or mark as undelivered (e.g. broken item, incorrect order)
  /// Report delivery issue or cancel order
  static Future<Map<String, dynamic>?> reportDeliveryIssue({
    required String orderId,
    required String status, // 'undelivered', 'returned', or 'cancelled'
    required String
        issueType, // 'customer_unreachable', 'incorrect_address', etc.
    String? notes,
    String? photoUrl,
  }) async {
    try {
      final response = await ApiService.patch(
        '/delivery/orders/$orderId/status',
        body: {
          'status': status,
          'issueType': issueType,
          'issueNotes': notes,
          'cancelReason': notes ?? issueType,
          'cancelledBy': 'driver',
          if (photoUrl != null) 'issuePhotoUrl': photoUrl,
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Report issue error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DRIVER SOS EMERGENCY
  // ───────────────────────────────────────────────────────────────────────────

  /// POST /api/delivery/sos
  static Future<Map<String, dynamic>?> triggerSOS({
    required String driverId,
    required String location,
    String? orderId,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post(
        '/delivery/sos',
        body: {
          'driverId': driverId,
          'location': location,
          if (orderId != null) 'orderId': orderId,
          if (notes != null) 'notes': notes,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Trigger SOS error: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ADMIN DELIVERY OPERATIONS
  // ───────────────────────────────────────────────────────────────────────────

  /// GET /api/admin/delivery/stats
  static Future<Map<String, dynamic>?> getAdminDeliveryStats() async {
    try {
      final response = await ApiService.get('/admin/delivery/stats');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get admin delivery stats error: $e');
      return null;
    }
  }

  /// GET /api/admin/delivery/orders
  static Future<List<dynamic>> getAdminDeliveryOrders({
    String? status,
    String? search,
    String? dateRange,
  }) async {
    try {
      final params = <String>[];
      if (status != null && status.isNotEmpty) params.add('status=$status');
      if (search != null && search.isNotEmpty) params.add('search=$search');
      if (dateRange != null && dateRange.isNotEmpty) {
        params.add('dateRange=$dateRange');
      }
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final response = await ApiService.get('/admin/delivery/orders$query');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get admin delivery orders error: $e');
      return [];
    }
  }

  /// PATCH /api/admin/delivery/orders/:id/assign
  static Future<Map<String, dynamic>?> assignDriverToOrder({
    required String orderId,
    required String driverId,
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/orders/$orderId/assign',
        body: {'driverId': driverId},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Assign driver error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/orders/:id/cancel
  static Future<Map<String, dynamic>?> cancelAdminOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/orders/$orderId/cancel',
        body: {'reason': reason},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Cancel admin order error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/orders/:id/status
  static Future<Map<String, dynamic>?> updateAdminOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/orders/$orderId/status',
        body: {'status': status},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Update admin order status error: $e');
      return null;
    }
  }

  /// GET /api/admin/delivery/drivers
  static Future<List<dynamic>> getAdminDeliveryDrivers({
    String? status,
    String? search,
  }) async {
    try {
      final params = <String>[];
      if (status != null && status.isNotEmpty) params.add('status=$status');
      if (search != null && search.isNotEmpty) params.add('search=$search');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final response = await ApiService.get('/admin/delivery/drivers$query');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get admin delivery drivers error: $e');
      return [];
    }
  }

  /// GET /api/admin/delivery/drivers/:id
  static Future<Map<String, dynamic>?> getAdminDriverDetails(
    String driverId,
  ) async {
    try {
      final response =
          await ApiService.get('/admin/delivery/drivers/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get admin driver details error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/drivers/:id/verify
  static Future<Map<String, dynamic>?> verifyDriverAdmin({
    required String driverId,
    required String status, // 'verified' or 'rejected'
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/drivers/$driverId/verify',
        body: {'status': status},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Verify driver error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/drivers/:id/suspend
  static Future<Map<String, dynamic>?> suspendDriverAdmin({
    required String driverId,
    required bool isSuspended,
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/drivers/$driverId/suspend',
        body: {'isSuspended': isSuspended},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Suspend driver error: $e');
      return null;
    }
  }

  /// GET /api/admin/delivery/issues
  static Future<Map<String, dynamic>?> getAdminDeliveryIssues({
    String? type,
    String? status,
  }) async {
    try {
      final params = <String>[];
      if (type != null && type.isNotEmpty) params.add('type=$type');
      if (status != null && status.isNotEmpty) params.add('status=$status');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final response = await ApiService.get('/admin/delivery/issues$query');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get admin delivery issues error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/issues/:id/resolve
  static Future<Map<String, dynamic>?> resolveIssueAdmin({
    required String issueId,
    String? notes,
  }) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/issues/$issueId/resolve',
        body: {'notes': notes},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Resolve issue error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/delivery/issues/:id/dismiss
  static Future<Map<String, dynamic>?> dismissIssueAdmin(
    String issueId,
  ) async {
    try {
      final response = await ApiService.patch(
        '/admin/delivery/issues/$issueId/dismiss',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Dismiss issue error: $e');
      return null;
    }
  }

  /// GET /api/delivery/drivers
  static Future<List<dynamic>> getAvailableDrivers() async {
    try {
      final response = await ApiService.get('/delivery/drivers');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // API returns { success: true, drivers: [...] }
        if (body is Map && body['drivers'] != null) {
          return body['drivers'] as List<dynamic>;
        }
        return body as List<dynamic>? ?? [];
      }
      return [];
    } catch (e) {
      print('Get available drivers error: $e');
      return [];
    }
  }

  /// POST /api/delivery/orders/:id/cancel-by-artisan
  static Future<bool> cancelDeliveryOrder(String deliveryOrderId, {String? reason}) async {
    try {
      final response = await ApiService.post(
        '/delivery/orders/$deliveryOrderId/cancel-by-artisan',
        body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Cancel delivery order error: $e');
      return false;
    }
  }

  /// PATCH /api/delivery/orders/:id/clear-by-artisan
  static Future<bool> clearDeliveryOrder(String deliveryOrderId) async {
    try {
      final response = await ApiService.patch(
        '/delivery/orders/$deliveryOrderId/clear-by-artisan',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Clear delivery order error: $e');
      return false;
    }
  }

  /// POST /api/delivery/orders/:id/review
  static Future<bool> reviewDeliveryOrder({
    required String orderId,
    required int rating,
    String? comment,
    String? role,
  }) async {
    try {
      final response = await ApiService.post(
        '/delivery/orders/$orderId/review',
        body: {
          'rating': rating,
          if (comment != null) 'comment': comment,
          if (role != null) 'role': role,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Review delivery order error: $e');
      return false;
    }
  }

  /// POST /api/delivery/orders/:id/report
  static Future<bool> reportDeliveryDriver({
    required String orderId,
    required String reason,
    String? notes,
    String? reporterRole,
  }) async {
    try {
      final response = await ApiService.post(
        '/delivery/orders/$orderId/report',
        body: {
          'reason': reason,
          if (notes != null) 'notes': notes,
          if (reporterRole != null) 'reporterRole': reporterRole,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Report delivery driver error: $e');
      return false;
    }
  }

  /// GET /api/delivery/drivers/:driverId/reviews
  static Future<List<dynamic>> getDriverReviews(String driverId) async {
    try {
      final response = await ApiService.get('/delivery/drivers/$driverId/reviews');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['reviews'] as List<dynamic>? ?? [];
      }
      return [];
    } catch (e) {
      print('Get driver reviews error: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI DIALOG HELPERS (REVIEW & REPORT DRIVER)
  // ───────────────────────────────────────────────────────────────────────────
  static void showDeliveryReviewModal(BuildContext context, String deliveryOrderId, bool isAr, {String? role}) {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isAr ? 'تقييم خدمة التوصيل 🚚' : 'Rate Delivery Service 🚚'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'كيف كانت تجربتك مع مندوب التوصيل؟' : 'How was your delivery experience?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setModalState(() => rating = i + 1);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: isAr ? 'ملاحظات حول التوصيل (اختياري)...' : 'Delivery feedback (optional)...',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A017)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setModalState(() => isSubmitting = true);
                      final ok = await reviewDeliveryOrder(
                        orderId: deliveryOrderId,
                        rating: rating,
                        comment: commentController.text.trim(),
                        role: role,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green,
                            content: Text(
                              isAr ? 'شكراً! تم تسجيل تقييمك للتوصيل ⭐' : 'Thank you! Delivery rating submitted ⭐',
                            ),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(isAr ? 'إرسال التقييم' : 'Submit Review', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showReportDriverModal(BuildContext context, String deliveryOrderId, bool isAr, {String? role}) {
    String selectedReason = isAr ? 'تأخير غير مبرر في التوصيل' : 'Unjustified delivery delay';
    final notesController = TextEditingController();
    bool isSubmitting = false;

    final reasons = isAr
        ? ['تأخير غير مبرر في التوصيل', 'سلوك غير لائق من المندوب', 'تلف أو كسر للشحنة', 'سبب آخر']
        : ['Unjustified delivery delay', 'Inappropriate driver behavior', 'Damaged or broken package', 'Other reason'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isAr ? 'الإبلاغ عن مندوب التوصيل ⚠️' : 'Report Delivery Driver ⚠️'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'اختر سبب البلاغ للإدارة:' : 'Select reason for admin report:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedReason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: isAr ? 'تفاصيل الإبلاغ للإدارة...' : 'Details for admin report...',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setModalState(() => isSubmitting = true);
                      final ok = await reportDeliveryDriver(
                        orderId: deliveryOrderId,
                        reason: selectedReason,
                        notes: notesController.text.trim(),
                        reporterRole: role,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green,
                            content: Text(
                              isAr ? 'تم إرسال البلاغ للإدارة بنجاح 🚨' : 'Report submitted to admin successfully 🚨',
                            ),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isAr ? 'إرسال البلاغ' : 'Submit Report', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
