import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class CloudinaryService {
  static const String cloudName = 'xg8rqryv';
  static const String uploadPreset = 'craftgo_preset';

// lib/services/cloudinary_service.dart

  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = imageFile.name;
      final extension = fileName.split('.').last.toLowerCase();

      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
        'upload_preset': uploadPreset,
      });

      final dio = Dio();
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
        // Removed explicit header to let Dio set boundary automatically
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  static Future<List<String>> uploadMultipleImages(List<XFile> images) async {
    List<String> urls = [];
    for (final image in images) {
      final url = await uploadImage(image);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  /// Upload an image (default) or any file (resourceType: 'raw' for PDFs, etc.)
  static Future<String?> uploadFile(
    XFile file, {
    String resourceType = 'image', // 'image' or 'raw'
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();

      String mimeType;
      if (resourceType == 'image') {
        switch (extension) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          default:
            mimeType = 'image/jpeg';
        }
      } else {
        // For raw files (PDF, DOC, etc.)
        mimeType = 'application/octet-stream';
        // You can refine mime type based on extension
        if (extension == 'pdf')
          mimeType = 'application/pdf';
        else if (extension == 'doc' || extension == 'docx')
          mimeType = 'application/msword';
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
        'upload_preset': uploadPreset,
      });

      // Use appropriate upload endpoint
      final uploadUrl = resourceType == 'raw'
          ? 'https://api.cloudinary.com/v1_1/$cloudName/raw/upload'
          : 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final dio = Dio();
      final response = await dio.post(
        uploadUrl,
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }
}
 // static Future<String?> uploadImage(XFile imageFile) async {
  //   try {
  //     final bytes = await imageFile.readAsBytes();
  //     final fileName = imageFile.name;
  //     final extension = fileName.split('.').last.toLowerCase();

  //     String mimeType;
  //     switch (extension) {
  //       case 'jpg':
  //       case 'jpeg':
  //         mimeType = 'image/jpeg';
  //         break;
  //       case 'png':
  //         mimeType = 'image/png';
  //         break;
  //       case 'gif':
  //         mimeType = 'image/gif';
  //         break;
  //       case 'webp':
  //         mimeType = 'image/webp';
  //         break;
  //       default:
  //         mimeType = 'image/jpeg';
  //     }

  //     final formData = FormData.fromMap({
  //       'file': MultipartFile.fromBytes(
  //         bytes,
  //         filename: fileName,
  //         contentType: MediaType.parse(mimeType),
  //       ),
  //       'upload_preset': uploadPreset,
  //     });

  //     final dio = Dio();
  //     final response = await dio.post(
  //       'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
  //       data: formData,
  //       options: Options(
  //         headers: {'Content-Type': 'multipart/form-data'},
  //       ),
  //     );

  //     if (response.statusCode == 200) {
  //       return response.data['secure_url'] as String;
  //     }
  //     return null;
  //   } catch (e) {
  //     print('Cloudinary upload error: $e');
  //     return null;
  //   }
  // }


// import 'package:flutter/foundation.dart';
// import 'package:dio/dio.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http_parser/http_parser.dart';

// class CloudinaryService {
//   static const String cloudName = 'xg8rqryv';
//   static const String uploadPreset = 'craftgo_preset';

//   static Future<String?> uploadImage(XFile imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();

//       if (bytes.isEmpty) {
//         debugPrint('❌ Cloudinary: image bytes are empty');
//         return null;
//       }

//       String fileName = imageFile.name.trim();

//       if (fileName.isEmpty) {
//         fileName = 'craftgo_${DateTime.now().millisecondsSinceEpoch}.jpg';
//       }

//       final extension = fileName.contains('.')
//           ? fileName.split('.').last.toLowerCase()
//           : 'jpg';

//       String mimeType;

//       switch (extension) {
//         case 'jpg':
//         case 'jpeg':
//           mimeType = 'image/jpeg';
//           break;

//         case 'png':
//           mimeType = 'image/png';
//           break;

//         case 'gif':
//           mimeType = 'image/gif';
//           break;

//         case 'webp':
//           mimeType = 'image/webp';
//           break;

//         default:
//           mimeType = 'image/jpeg';
//       }

//       debugPrint('☁️ Cloudinary upload starting...');
//       debugPrint('📷 File: $fileName');
//       debugPrint('📦 Size: ${bytes.length} bytes');
//       debugPrint('🧾 MIME: $mimeType');

//       final formData = FormData.fromMap({
//         'file': MultipartFile.fromBytes(
//           bytes,
//           filename: fileName,
//           contentType: MediaType.parse(mimeType),
//         ),
//         'upload_preset': uploadPreset,
//       });

//       final dio = Dio(
//         BaseOptions(
//           connectTimeout: const Duration(seconds: 30),
//           sendTimeout: const Duration(seconds: 60),
//           receiveTimeout: const Duration(seconds: 60),
//         ),
//       );

//       final response = await dio.post(
//         'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
//         data: formData,

//         // مهم:
//         // لا نضع Content-Type يدوياً.
//         // Dio سيضيف multipart boundary بشكل صحيح.
//         options: Options(
//           validateStatus: (status) =>
//           status != null && status >= 200 && status < 500,
//         ),
//       );

//       debugPrint(
//         '☁️ Cloudinary response status: ${response.statusCode}',
//       );

//       debugPrint(
//         '☁️ Cloudinary response: ${response.data}',
//       );

//       if (response.statusCode == 200 ||
//           response.statusCode == 201) {
//         final data = response.data;

//         if (data is Map) {
//           final secureUrl = data['secure_url']?.toString();

//           if (secureUrl != null && secureUrl.isNotEmpty) {
//             debugPrint(
//               '✅ Cloudinary upload successful: $secureUrl',
//             );

//             return secureUrl;
//           }
//         }

//         debugPrint(
//           '❌ Cloudinary: secure_url missing from response',
//         );

//         return null;
//       }

//       debugPrint(
//         '❌ Cloudinary upload failed '
//             '(${response.statusCode}): ${response.data}',
//       );

//       return null;
//     } on DioException catch (e) {
//       debugPrint('❌ Cloudinary DioException');

//       debugPrint(
//         'Status: ${e.response?.statusCode}',
//       );

//       debugPrint(
//         'Response: ${e.response?.data}',
//       );

//       debugPrint(
//         'Message: ${e.message}',
//       );

//       return null;
//     } catch (e, stackTrace) {
//       debugPrint(
//         '❌ Cloudinary upload error: $e',
//       );

//       debugPrint(
//         'StackTrace: $stackTrace',
//       );

//       return null;
//     }
//   }

//   static Future<List<String>> uploadMultipleImages(
//       List<XFile> images,
//       ) async {
//     final List<String> urls = [];

//     for (int i = 0; i < images.length; i++) {
//       debugPrint(
//         '📤 Uploading image ${i + 1}/${images.length}',
//       );

//       final url = await uploadImage(images[i]);

//       if (url != null && url.isNotEmpty) {
//         urls.add(url);
//       } else {
//         debugPrint(
//           '❌ Failed uploading image ${i + 1}',
//         );
//       }
//     }

//     return urls;
//   }

//   static Future<String?> uploadFile(
//     XFile file, {
//     String resourceType = 'auto',
//   }) async {
//     return uploadImage(file);
//   }
// }