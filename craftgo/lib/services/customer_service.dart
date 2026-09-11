import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'api_service.dart';
import 'session_service.dart';

class CustomerService {
  /// Fetch public products with optional filters.
  /// Returns a [ProductsResult] containing the list and computed favorite/cart sets.
  static Future<ProductsResult> fetchProductsWithState({
    String? category,
    String? sort,
    String? search,
    List<String>? materials,
    List<String>? crafts,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? deliveryTime,
    bool? ecoFriendly,
  }) async {
    try {
      final params = <String, String>{};

      if (category != null && category.trim().isNotEmpty) {
        params['category'] = category.trim();
      }
      if (sort != null && sort.trim().isNotEmpty) {
        params['sort'] = sort.trim();
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (materials != null && materials.isNotEmpty) {
        params['materials'] = materials.join(',');
      }
      if (crafts != null && crafts.isNotEmpty) {
        params['crafts'] = crafts.join(',');
      }
      if (minPrice != null) {
        params['minPrice'] = minPrice.toStringAsFixed(0);
      }
      if (maxPrice != null) {
        params['maxPrice'] = maxPrice.toStringAsFixed(0);
      }
      if (minRating != null && minRating > 0) {
        params['minRating'] = minRating.toString();
      }
      if (deliveryTime != null && deliveryTime.trim().isNotEmpty) {
        params['deliveryTime'] = deliveryTime.trim();
      }
      if (ecoFriendly == true) {
        params['ecoFriendly'] = 'true';
      }

      final query = Uri(queryParameters: params).query;
      final endpoint = query.isEmpty ? '/products' : '/products?$query';
      final response = await ApiService.get(endpoint);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> products = [];
        if (data is List) {
          products = data;
        } else if (data is Map<String, dynamic>) {
          final items = data['data'] ?? data['products'] ?? data['items'];
          if (items is List) products = items;
        }

        // Extract isFavorite and isInCart sets from returned products
        final favoriteIds = <String>{};
        final cartIds = <String>{};
        for (final p in products) {
          if (p is Map<String, dynamic>) {
            final id = (p['id'] ?? p['_id'] ?? '').toString();
            if (id.isNotEmpty) {
              if (p['isFavorite'] == true) favoriteIds.add(id);
              if (p['isInCart'] == true) cartIds.add(id);
            }
          }
        }

        return ProductsResult(
          products: products,
          favoriteIds: favoriteIds,
          cartIds: cartIds,
        );
      } else {
        debugPrint(
            'Products request failed: ${response.statusCode} ${response.body}');
        throw Exception('Server error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      rethrow;
    }
  }

  /// Simple list fetch (backward compat – used in search results etc.)
  static Future<List<dynamic>> fetchProducts({
    String? category,
    String? sort,
    String? search,
    List<String>? materials,
    List<String>? crafts,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? deliveryTime,
    bool? ecoFriendly,
  }) async {
    try {
      final result = await fetchProductsWithState(
        category: category,
        sort: sort,
        search: search,
        materials: materials,
        crafts: crafts,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minRating: minRating,
        deliveryTime: deliveryTime,
        ecoFriendly: ecoFriendly,
      );
      return result.products;
    } catch (_) {
      return [];
    }
  }

  /// Fetch all top artisans (craftsmen)
  static Future<List<dynamic>> fetchTopArtisans() async {
    try {
      final response = await ApiService.get('/craftsman');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final items = data['data'] ??
              data['craftsmen'] ??
              data['artisans'] ??
              data['users'];
          if (items is List) return items;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching craftsmen: $e');
      return [];
    }
  }

  /// Add a product to the authenticated customer's cart.
  static Future<bool> addToCart(String productId) async {
    if (productId.trim().isEmpty) return false;

    try {
      final response = await ApiService.post(
        '/interactions',
        body: {
          'productId': productId.trim(),
          'interactionType': 'cart',
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding product to cart: $e');
      return false;
    }
  }

  /// Update cart item quantity
  static Future<bool> updateCartQuantity(
      String interactionId, int quantity) async {
    try {
      final response = await ApiService.patch(
        '/interactions/$interactionId',
        body: {'quantity': quantity},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      return false;
    }
  }

  /// Clear user cart
  static Future<bool> clearCart() async {
    try {
      final response = await ApiService.delete('/interactions/cart/clear');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      return false;
    }
  }

  /// Checkout items
  static Future<Map<String, dynamic>?> checkout(
      List<Map<String, dynamic>> items,
      String deliveryAddress,
      String paymentMethod) async {
    try {
      final response = await ApiService.post(
        '/orders',
        body: {
          'items': items,
          'deliveryAddress': deliveryAddress,
          'paymentMethod': paymentMethod,
        },
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error during checkout: $e');
      return null;
    }
  }

  /// Add or remove a product from the authenticated customer's favorites.
  static Future<bool> setProductFavorite({
    required String productId,
    required bool isFavorite,
  }) async {
    if (productId.trim().isEmpty) return false;

    try {
      final response = await ApiService.post(
        '/interactions',
        body: {
          'productId': productId.trim(),
          'interactionType': isFavorite ? 'like' : 'unlike',
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating favorite: $e');
      return false;
    }
  }

  /// Submit Gift Quiz Answers
  static Future<Map<String, dynamic>?> submitGiftQuiz(
      Map<String, dynamic> answers) async {
    try {
      final response = await ApiService.post('/ai/gift-quiz', body: {
        'answers': answers,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error submitting gift quiz: $e');
      return null;
    }
  }

  /// Upload image for Visual Search
  static Future<Map<String, dynamic>?> visualSearch(File imageFile) async {
    try {
      return visualSearchBytes(
        await imageFile.readAsBytes(),
        filename: imageFile.path.split(RegExp(r'[/\\]')).last,
      );
    } catch (e) {
      debugPrint('Error in visualSearch: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> visualSearchBytes(
    Uint8List bytes, {
    String filename = 'image.jpg',
  }) async {
    return _uploadImage('/upload/visual-search', bytes, filename: filename);
  }

  static Future<Uint8List?> generateSketchMockup(
    Uint8List bytes, {
    required String prompt,
  }) async {
    final data = await _uploadImage('/upload/generate-sketch-mockup', bytes,
        filename: 'sketch.png', extraFields: {'prompt': prompt});
    final encoded = data?['imageBase64'];
    if (encoded is String && encoded.isNotEmpty) {
      return base64Decode(encoded);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _uploadImage(
    String endpoint,
    Uint8List bytes, {
    required String filename,
    Map<String, String>? extraFields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}$endpoint'),
    );
    final extension = filename.toLowerCase().split('.').last;
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'webp'
            ? 'webp'
            : 'jpeg';
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
      contentType: MediaType('image', subtype),
    ));
    if (extraFields != null) request.fields.addAll(extraFields);

    final token = await SessionService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    debugPrint(
        'Image upload failed: ${response.statusCode} - ${response.body}');
    return null;
  }
}

/// Result class for products fetch containing the list + state sets.
class ProductsResult {
  final List<dynamic> products;
  final Set<String> favoriteIds;
  final Set<String> cartIds;

  const ProductsResult({
    required this.products,
    required this.favoriteIds,
    required this.cartIds,
  });
}
