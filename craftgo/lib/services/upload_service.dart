import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_service.dart';
import 'session_service.dart';

import 'package:image_picker/image_picker.dart';

/// Handles image uploads to the backend.
class UploadService {
  /// Uploads one image and returns its public URL.
  static Future<String?> uploadImage(
      XFile imageFile, {
        String field = 'image',
      }) async {
    try {
      final token = await SessionService.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/upload/image'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final extension = imageFile.name.split('.').last.toLowerCase();

      MediaType mediaType;
      if (extension == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (extension == 'webp') {
        mediaType = MediaType('image', 'webp');
      } else if (extension == 'gif') {
        mediaType = MediaType('image', 'gif');
      } else if (extension == 'pdf') {
        mediaType = MediaType('application', 'pdf');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }

      final bytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: imageFile.name,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final decoded = jsonDecode(responseBody);

        if (decoded is Map<String, dynamic>) {
          return decoded['url']?.toString();
        }

        return null;
      }

      debugPrint('Upload failed: ${streamedResponse.statusCode} - $responseBody');
      throw Exception('Upload failed: ${streamedResponse.statusCode} - $responseBody');
    } catch (e) {
      debugPrint('Upload error: $e');
      throw Exception(e.toString());
    }
  }

  /// Uploads several images one by one and returns successful URLs.
  static Future<List<String>> uploadImages(List<XFile> files) async {
    final uploadedUrls = <String>[];

    for (final file in files) {
      final url = await uploadImage(file);

      if (url != null && url.isNotEmpty) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  /// Result model for ID verification
  static ({String url, Map<String, dynamic> verificationData})? _lastVerification;

  /// Uploads an ID image to the backend for AI quality verification.
  /// Returns a record with [url] and [verificationData].
  /// Throws an [Exception] with a human-readable error message if verification fails.
  static Future<({String url, Map<String, dynamic> verificationData})>
      uploadAndVerifyIdImage(XFile imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/upload/verify-id'),
    );

    final token = await SessionService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final ext = imageFile.name.split('.').last.toLowerCase();
    final mediaType = ext == 'png'
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    final bytes = await imageFile.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: imageFile.name,
        contentType: mediaType,
      ),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      return (
        url: decoded['url']?.toString() ?? '',
        verificationData: decoded['verificationData'] as Map<String, dynamic>? ?? {},
      );
    }

    // Server returned an error — extract message for the user
    final serverMessage = decoded['message']?.toString() ??
        'Image quality verification failed. Please retake.';
    final verificationData =
        decoded['verificationData'] as Map<String, dynamic>? ?? {};

    throw IDVerificationException(serverMessage, verificationData);
  }
}

/// Thrown when the AI rejects the uploaded ID image quality.
class IDVerificationException implements Exception {
  final String message;
  final Map<String, dynamic> verificationData;
  IDVerificationException(this.message, this.verificationData);

  @override
  String toString() => message;
}
