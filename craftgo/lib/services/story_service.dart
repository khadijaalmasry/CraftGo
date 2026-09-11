import 'dart:convert';
import 'api_service.dart';

class StoryService {
  static String? lastError;

  // ── Feed ───────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getFeed() async {
    lastError = null;
    try {
      final response = await ApiService.get('/stories');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is List ? decoded : <dynamic>[];
      }
      lastError = 'GET /stories failed: ${response.statusCode} ${response.body}';
      return [];
    } catch (e) {
      lastError = 'GET /stories error: $e';
      return [];
    }
  }

  static Future<List<dynamic>> getByArtisan(String artisanId) async {
    lastError = null;
    try {
      final response = await ApiService.get('/stories/artisan/$artisanId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is List ? decoded : <dynamic>[];
      }
      lastError =
      'GET /stories/artisan/$artisanId failed: ${response.statusCode} ${response.body}';
      return [];
    } catch (e) {
      lastError = 'GET artisan stories error: $e';
      return [];
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> createStory({
    required String textAr,
    String textEn = '',
    String? imageUrl,
    String? artisanId,
  }) async {
    lastError = null;
    try {
      final body = <String, dynamic>{
        'textAr': textAr,
        'textEn': textEn.trim().isEmpty ? textAr : textEn,
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'imageUrl': imageUrl.trim(),
        if (artisanId != null && artisanId.trim().isNotEmpty)
          'artisanId': artisanId.trim(),
      };

      final response = await ApiService.post('/stories', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final story = decoded['story'];
          if (story is Map) return Map<String, dynamic>.from(story);
          return decoded;
        }
      }

      lastError =
      'Create story failed: ${response.statusCode} ${response.body}';
      return null;
    } catch (e) {
      lastError = 'Create story error: $e';
      return null;
    }
  }

  // ── Like / Unlike ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> toggleLike(String storyId) async {
    lastError = null;
    try {
      final response = await ApiService.post('/stories/$storyId/like');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
      lastError =
      'Toggle like failed: ${response.statusCode} ${response.body}';
      return null;
    } catch (e) {
      lastError = 'Toggle like error: $e';
      return null;
    }
  }

  // ── Comments ───────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getComments(String storyId) async {
    lastError = null;
    try {
      final response = await ApiService.get('/stories/$storyId/comments');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
      lastError =
      'Get comments failed: ${response.statusCode} ${response.body}';
      return [];
    } catch (e) {
      lastError = 'Get comments error: $e';
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addComment(
      String storyId,
      String text,
      ) async {
    lastError = null;
    try {
      final response = await ApiService.post(
        '/stories/$storyId/comments',
        body: {'text': text.trim()},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final comment = decoded['comment'];
          if (comment is Map) return Map<String, dynamic>.from(comment);
          return decoded;
        }
      }

      lastError =
      'Add comment failed: ${response.statusCode} ${response.body}';
      return null;
    } catch (e) {
      lastError = 'Add comment error: $e';
      return null;
    }
  }

  static Future<bool> deleteComment(
      String storyId,
      String commentId,
      ) async {
    lastError = null;
    try {
      final response =
      await ApiService.delete('/stories/$storyId/comments/$commentId');
      if (response.statusCode == 200) return true;
      lastError =
      'Delete comment failed: ${response.statusCode} ${response.body}';
      return false;
    } catch (e) {
      lastError = 'Delete comment error: $e';
      return false;
    }
  }

  // ── Delete Story ───────────────────────────────────────────────────────────
  static Future<bool> deleteStory(String storyId) async {
    lastError = null;
    try {
      final response = await ApiService.delete('/stories/$storyId');
      if (response.statusCode == 200) return true;
      lastError =
      'Delete story failed: ${response.statusCode} ${response.body}';
      return false;
    } catch (e) {
      lastError = 'Delete story error: $e';
      return false;
    }
  }
}
