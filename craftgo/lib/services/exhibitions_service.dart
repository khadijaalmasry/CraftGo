import 'dart:convert';
import 'api_service.dart';
import 'package:flutter/foundation.dart';

class ExhibitionsService {
  /// GET /api/exhibitions
  /// Fetch all exhibitions for public exploration
  static Future<List<dynamic>> getAllExhibitions() async {
    try {
      final response = await ApiService.get('/exhibitions');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Fetch all exhibitions error: $e');
      return [];
    }
  }

  /// GET /api/exhibitions/owner/:ownerId
  /// Fetch exhibitions created by a specific exhibition owner
  static Future<List<dynamic>> getOwnerExhibitions(String ownerId) async {
    try {
      final response = await ApiService.get('/exhibitions/owner/$ownerId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Fetch owner exhibitions error: $e');
      return [];
    }
  }

  /// GET /api/exhibitions/craftsman/:craftsmanId
  /// Fetch exhibition registrations for a craftsman
  static Future<List<dynamic>> getCraftsmanRegistrations(
      String craftsmanId) async {
    try {
      final response =
          await ApiService.get('/exhibitions/craftsman/$craftsmanId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Fetch craftsman registrations error: $e');
      return [];
    }
  }

  /// GET /api/exhibitions/:exhibitionId
  /// Fetch details of a single exhibition
  static Future<Map<String, dynamic>?> getExhibitionById(
      String exhibitionId) async {
    try {
      final response = await ApiService.get('/exhibitions/$exhibitionId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Fetch exhibition by ID error: $e');
      return null;
    }
  }

  // ── Exhibition Interest (Customer Favorites) ──────────────────────────

  /// POST /api/interactions/exhibition
  /// Toggle interest (favorite) status for an exhibition
  static Future<bool> toggleInterest(String exhibitionId) async {
    try {
      final response = await ApiService.post(
        '/interactions/exhibition',
        body: {'exhibitionId': exhibitionId},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // The backend returns { success: true, interested: true/false }
        return data['interested'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Toggle interest error: $e');
      return false;
    }
  }

  /// GET /api/interactions/exhibitions
  /// Get all exhibitions the user is interested in
  static Future<List<Map<String, dynamic>>> getInterestedExhibitions() async {
    try {
      final response = await ApiService.get('/interactions/exhibitions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exhibitions = data['exhibitions'] as List? ?? [];
        return exhibitions
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get interested exhibitions error: $e');
      return [];
    }
  }

  /// Check if a user is interested in a specific exhibition
  static Future<bool> isInterested(String exhibitionId) async {
    try {
      final list = await getInterestedExhibitions();
      return list.any((e) => e['id']?.toString() == exhibitionId);
    } catch (e) {
      debugPrint('Check interest error: $e');
      return false;
    }
  }

  // ── Existing methods ──────────────────────────────────────────────────────

  /// POST /api/exhibitions
  /// Create a new exhibition
  static Future<Map<String, dynamic>?> createExhibition(
      Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post('/exhibitions', body: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        return resBody['exhibition'] ?? resBody;
      }
      return null;
    } catch (e) {
      print('Create exhibition error: $e');
      return null;
    }
  }

  /// PUT /api/exhibitions/:exhibitionId
  /// Update exhibition details
  static Future<Map<String, dynamic>?> updateExhibition(
      String exhibitionId, Map<String, dynamic> data) async {
    try {
      final response =
          await ApiService.put('/exhibitions/$exhibitionId', body: data);
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        return resBody['exhibition'] ?? resBody;
      }
      return null;
    } catch (e) {
      print('Update exhibition error: $e');
      return null;
    }
  }

  /// DELETE /api/exhibitions/:exhibitionId
  /// Delete an exhibition
  static Future<bool> deleteExhibition(String exhibitionId) async {
    try {
      final response = await ApiService.delete('/exhibitions/$exhibitionId');
      return response.statusCode == 200;
    } catch (e) {
      print('Delete exhibition error: $e');
      return false;
    }
  }

  /// PUT /api/exhibitions/:exhibitionId/capacity
  /// Update overall capacity and per-category capacities
  static Future<Map<String, dynamic>?> updateCapacity(
    String exhibitionId, {
    int? capacity,
    Map<String, dynamic>? categoryCapacities,
  }) async {
    try {
      final response = await ApiService.put(
        '/exhibitions/$exhibitionId/capacity',
        body: {
          if (capacity != null) 'capacity': capacity,
          if (categoryCapacities != null)
            'categoryCapacities': categoryCapacities,
        },
      );
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        return resBody['exhibition'] ?? resBody;
      }
      return null;
    } catch (e) {
      print('Update capacity error: $e');
      return null;
    }
  }

  /// PUT /api/exhibitions/:exhibitionId/booth-layout
  /// Update booth layout
  static Future<bool> updateBoothLayout(
      String exhibitionId, List<dynamic> boothLayout) async {
    try {
      final response = await ApiService.put(
        '/exhibitions/$exhibitionId/booth-layout',
        body: {'boothLayout': boothLayout},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update booth layout error: $e');
      return false;
    }
  }

  /// POST /api/exhibitions/:exhibitionId/register
  /// Register craftsman for exhibition
  static Future<Map<String, dynamic>?> registerForExhibition({
    required String exhibitionId,
    required String craftsmanId,
    String? craftCategory,
    String? boothId,
    double? boothPrice,
    bool hasPaid = false,
    String? paymentReference,
    bool isInvited = false,
    bool isReserve = false,
  }) async {
    try {
      final response = await ApiService.post(
        '/exhibitions/$exhibitionId/register',
        body: {
          'craftsmanId': craftsmanId,
          if (craftCategory != null) 'craftCategory': craftCategory,
          if (boothId != null) 'boothId': boothId,
          if (boothPrice != null) 'boothPrice': boothPrice,
          'hasPaid': hasPaid,
          if (paymentReference != null) 'paymentReference': paymentReference,
          'isInvited': isInvited,
          'isReserve': isReserve,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Register for exhibition error: $e');
      return null;
    }
  }

  /// PATCH /api/exhibitions/:exhibitionId/registrations/:registrationId/status
  /// Approve or reject craftsman registration
  static Future<bool> updateRegistrationStatus(
    String exhibitionId,
    String registrationId,
    String status, {
    String? boothId,
    String? reason,
  }) async {
    try {
      final response = await ApiService.patch(
        '/exhibitions/$exhibitionId/registrations/$registrationId/status',
        body: {
          'status': status,
          if (boothId != null) 'boothId': boothId,
          if (reason != null) 'reason': reason,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update registration status error: $e');
      return false;
    }
  }

  /// POST /api/exhibitions/:exhibitionId/registrations/:registrationId/absence
  /// Report absence for a craftsman
  static Future<bool> reportAbsence({
    required String exhibitionId,
    required String registrationId,
    String? reason,
    String? apologyText,
  }) async {
    try {
      final response = await ApiService.post(
        '/exhibitions/$exhibitionId/registrations/$registrationId/absence',
        body: {
          if (reason != null) 'reason': reason,
          if (apologyText != null) 'apologyText': apologyText,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Report absence error: $e');
      return false;
    }
  }

  /// GET /api/artisan/all
  /// Returns all craftsmen with ArtisanProfile
  static Future<List<dynamic>> getAllCraftsmen() async {
    try {
      final response = await ApiService.get('/artisan/all');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      print('Get all craftsmen error: $e');
      return [];
    }
  }

  /// GET /api/artisan/profile/:id
  /// Returns a single craftsman's profile
  static Future<Map<String, dynamic>?> getCraftsmanProfile(
      String craftsmanId) async {
    try {
      final response = await ApiService.get('/artisan/profile/$craftsmanId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get craftsman profile error: $e');
      return null;
    }
  }

  /// GET /api/exhibitions/:exhibitionId/attendance
  /// Fetch attendance records for all dates of an exhibition
  static Future<List<dynamic>> getAttendance(String exhibitionId) async {
    try {
      final response =
          await ApiService.get('/exhibitions/$exhibitionId/attendance');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get attendance error: $e');
      return [];
    }
  }

  /// POST /api/exhibitions/:exhibitionId/attendance
  /// Update attendance for a specific craftsman on a specific date
  static Future<bool> updateAttendance({
    required String exhibitionId,
    required String craftsmanId,
    required String date, // format: 'YYYY-MM-DD'
    required bool isPresent,
    String? absenceReason,
    String? boothId,
  }) async {
    try {
      final response = await ApiService.post(
        '/exhibitions/$exhibitionId/attendance',
        body: {
          'craftsmanId': craftsmanId,
          'date': date,
          'isPresent': isPresent,
          if (absenceReason != null) 'absenceReason': absenceReason,
          if (boothId != null) 'boothId': boothId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update attendance error: $e');
      return false;
    }
  }

  /// POST /api/exhibitions/:exhibitionId/attendance/promote
  /// Promote a standby craftsman for a specific day, assigning a booth
  static Future<bool> promoteStandby({
    required String exhibitionId,
    required String standbyCraftsmanId,
    required String boothId,
    required String date, // format: 'YYYY-MM-DD'
  }) async {
    try {
      final response = await ApiService.post(
        '/exhibitions/$exhibitionId/attendance/promote',
        body: {
          'standbyCraftsmanId': standbyCraftsmanId,
          'boothId': boothId,
          'date': date,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Promote standby error: $e');
      return false;
    }
  }

// ── Admin methods ──────────────────────────────────────────────────

  /// GET /api/admin/exhibitions
  /// Fetch all exhibitions with optional filters (admin only)
  static Future<List<dynamic>> getAdminExhibitions({
    String? status,
    String? city,
    String? search,
    bool? featured,
    bool? pending,
  }) async {
    try {
      final query = <String, String>{};
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (city != null && city.isNotEmpty) query['city'] = city;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (featured != null) query['featured'] = featured.toString();
      if (pending != null) query['pending'] = pending.toString();

      final uri = Uri(path: '/admin/exhibitions', queryParameters: query);
      final response = await ApiService.get(uri.toString());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get admin exhibitions error: $e');
      return [];
    }
  }

  /// GET /api/admin/exhibitions/analytics
  /// Get platform-wide analytics (admin only)
  static Future<Map<String, dynamic>?> getAdminAnalytics() async {
    try {
      final response = await ApiService.get('/admin/exhibitions/analytics');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get admin analytics error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/exhibitions/:id/feature
  /// Toggle featured status
  static Future<Map<String, dynamic>?> toggleFeatured(
    String exhibitionId,
    bool featured,
  ) async {
    try {
      final response = await ApiService.patch(
        '/admin/exhibitions/$exhibitionId/feature',
        body: {'featured': featured},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Toggle featured error: $e');
      return null;
    }
  }

  /// PATCH /api/admin/exhibitions/:id/status
  /// Admin override status (active, suspended, upcoming, past)
  static Future<Map<String, dynamic>?> adminOverrideStatus(
    String exhibitionId,
    String status,
  ) async {
    try {
      final response = await ApiService.patch(
        '/admin/exhibitions/$exhibitionId/status',
        body: {'status': status},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Admin override status error: $e');
      return null;
    }
  }

  /// POST /api/admin/exhibitions/:id/approve
  /// Approve a pending exhibition
  static Future<Map<String, dynamic>?> approveExhibition(
    String exhibitionId,
  ) async {
    try {
      final response = await ApiService.post(
        '/admin/exhibitions/$exhibitionId/approve',
        body: {}, // empty body
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Approve exhibition error: $e');
      return null;
    }
  }

  /// POST /api/admin/exhibitions/:id/reject
  /// Reject a pending exhibition with reason
  static Future<Map<String, dynamic>?> rejectExhibition(
    String exhibitionId,
    String reason,
  ) async {
    try {
      final response = await ApiService.post(
        '/admin/exhibitions/$exhibitionId/reject',
        body: {'reason': reason},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Reject exhibition error: $e');
      return null;
    }
  }
}
