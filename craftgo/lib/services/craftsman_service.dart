import 'package:flutter/foundation.dart';
// lib/services/craftsman_service.dart
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // add this
import 'api_service.dart';
import 'cloudinary_service.dart';

class CraftsmanService {
  // â”€â”€â”€ Profile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await ApiService.get('/craftsman/profile/$userId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      final response =
      await ApiService.put('/craftsman/profile/$userId', body: data);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return null;
    }
  }

  // â”€â”€â”€ Upload Profile Image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<String?> uploadProfileImage(XFile imageFile) async {
    return await CloudinaryService.uploadImage(imageFile);
  }

  static Future<bool> updateProfileImage(String userId, String imageUrl) async {
    try {
      final response = await ApiService.put('/craftsman/profile/$userId',
          body: {'profileImage': imageUrl});
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      return false;
    }
  }

  static Future<bool> updateBannerImage(
      String userId, String imageUrl) async {
    try {
      final response = await ApiService.put(
        '/craftsman/profile/$userId',
        body: {'bannerImage': imageUrl},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating banner image: $e');
      return false;
    }
  }

  // â”€â”€â”€ Portfolio â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<List<Map<String, dynamic>>> getPortfolio(String userId) async {
    try {
      final response = await ApiService.get('/craftsman/portfolio/$userId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching portfolio: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addPortfolioItem(
      Map<String, dynamic> data) async {
    try {
      final response =
      await ApiService.post('/craftsman/portfolio', body: data);
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error adding portfolio item: $e');
      return null;
    }
  }

  static Future<bool> deletePortfolioItem(String itemId) async {
    try {
      final response = await ApiService.delete('/craftsman/portfolio/$itemId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting portfolio item: $e');
      return false;
    }
  }

  // â”€â”€â”€ Add Portfolio with Image (upload first, then save) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>?> addPortfolioItemWithImage(
      Map<String, dynamic> data, XFile? imageFile) async {
    try {
      String? imageUrl = data['imageUrl'];

      if (imageFile != null) {
        imageUrl = await CloudinaryService.uploadImage(imageFile);
        if (imageUrl == null) {
          return null;
        }
      }

      final finalData = Map<String, dynamic>.from(data);
      if (imageUrl != null) {
        finalData['imageUrl'] = imageUrl;
      }

      return await addPortfolioItem(finalData);
    } catch (e) {
      debugPrint('Error adding portfolio item with image: $e');
      return null;
    }
  }

  // â”€â”€â”€ Reviews â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<Map<String, dynamic>?> getReviews(String userId,
      {int page = 1, int limit = 5}) async {
    try {
      final response = await ApiService.get(
          '/craftsman/reviews/$userId?page=$page&limit=$limit');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return null;
    }
  }
  // ─── Favorites Persistence ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFavoriteArtisans() async {
    try {
      final response = await ApiService.get('/craftsman/favorites');
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching favorite artisans: $e');
      return [];
    }
  }

  static Future<bool> addFavoriteArtisan(String artisanId) async {
    try {
      final response = await ApiService.post(
        '/craftsman/favorite',
        body: {'artisanId': artisanId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding favorite artisan: $e');
      return false;
    }
  }

  static Future<bool> removeFavoriteArtisan(String artisanId) async {
    try {
      final response = await ApiService.delete('/craftsman/favorite/$artisanId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing favorite artisan: $e');
      return false;
    }
  }
}

