import 'dart:convert';
import 'api_service.dart';

class ProductsService {
  static Map<String, dynamic>? _mapResponse(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  // Get all products (public)
  static Future<List<dynamic>> getAllProducts() async {
    try {
      final response = await ApiService.get('/products');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get products for a specific craftsman
  static Future<List<dynamic>> getProductsByCraftsman(
      String craftsmanId) async {
    try {
      final response = await ApiService.get('/products/craftsman/$craftsmanId');
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // Create a new product
  static Future<Map<String, dynamic>?> createProduct({
    required String craftsmanId,
    required String titleAr,
    required String titleEn,
    required String description,
    required String materials,
    required String dimensions,
    required String colors,
    required double price,
    required String category,
    required bool isPublic,
    String? imageUrl,
    List<String> images = const <String>[],
  }) async {
    try {
      final response = await ApiService.post('/products', body: {
        'craftsmanId': craftsmanId,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'description': description,
        'materials': materials,
        'dimensions': dimensions,
        'colors': colors,
        'price': price,
        'category': category,
        'isPublic': isPublic,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'images': images,
      });

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final product = decoded['product'];

        if (product is Map) {
          return Map<String, dynamic>.from(product);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Update a product
  static Future<Map<String, dynamic>?> updateProduct(
    String productId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response =
          await ApiService.put('/products/$productId', body: fields);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final product = decoded['product'];

        if (product is Map) {
          return Map<String, dynamic>.from(product);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete a product
  static Future<bool> deleteProduct(String productId) async {
    try {
      final response = await ApiService.delete('/products/$productId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Place a product order (standard)
  static Future<Map<String, dynamic>?> placeOrder({
    required String productId,
    required String interactionId,
    required int quantity,
    required String deliveryAddress,
    required String paymentMethod,
  }) async {
    try {
      final response = await ApiService.post('/orders', body: {
        'items': [
          {
            'productId': productId,
            'interactionId': interactionId,
            'quantity': quantity
          }
        ],
        'deliveryAddress': deliveryAddress,
        'paymentMethod': paymentMethod
      });
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get craftsman orders (standard product orders) — uses /orders/artisan with token auth
  static Future<List<dynamic>> getCraftsmanOrders(String craftsmanId) async {
    try {
      // /orders/artisan uses the JWT token to identify the artisan automatically
      final response = await ApiService.get('/orders/artisan');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['orders'] != null) {
          return List<dynamic>.from(body['orders']);
        } else if (body is List) {
          return body;
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Update order status
  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await ApiService.patch('/orders/$orderId/status',
          body: {'status': status});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Create one or more unpaid orders. Prices are always recalculated by backend.
  static Future<Map<String, dynamic>?> createCheckoutOrders({
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
    String? customerPhone,
  }) async {
    final response = await ApiService.post('/orders', body: {
      'items': items,
      'deliveryAddress': deliveryAddress,
      if (customerPhone != null && customerPhone.isNotEmpty)
        'customerPhone': customerPhone,
      'paymentMethod': 'Stripe Test / Escrow',
    });
    if (response.statusCode != 201) {
      throw Exception(
          _mapResponse(response.body)?['error'] ?? 'Could not create order');
    }
    return _mapResponse(response.body);
  }

  static Future<Map<String, dynamic>> startProductCheckout(
      List<String> orderIds) async {
    final response =
        await ApiService.post('/payments/products/checkout', body: {
      'orderIds': orderIds,
    });
    final body = _mapResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode != 201 || body['checkoutUrl'] == null) {
      throw Exception(body['error'] ?? 'Could not start checkout');
    }
    return body;
  }

  static Future<Map<String, dynamic>> createOffer({
    required String productId,
    required int quantity,
    required double offeredPrice,
    String message = '',
  }) async {
    final response = await ApiService.post('/product-offers', body: {
      'productId': productId,
      'quantity': quantity,
      'offeredPrice': offeredPrice,
      'message': message,
    });
    final body = _mapResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Could not send offer');
    }
    return body;
  }

  static Future<List<dynamic>> getMyCustomerOffers() async {
    final response = await ApiService.get('/product-offers/customer');
    if (response.statusCode != 200) return [];
    final body = _mapResponse(response.body);
    if (body == null) return [];
    return List<dynamic>.from(body['offers'] ?? []);
  }

  static Future<List<dynamic>> getMyArtisanOffers() async {
    final response = await ApiService.get('/product-offers/artisan');
    if (response.statusCode != 200) return [];
    final body = _mapResponse(response.body);
    if (body == null) return [];
    return List<dynamic>.from(body['offers'] ?? []);
  }

  static Future<Map<String, dynamic>> respondToOffer(
    String offerId, {
    required String action,
    double? counterPrice,
  }) async {
    final response =
        await ApiService.patch('/product-offers/$offerId/respond', body: {
      'action': action,
      if (counterPrice != null) 'counterPrice': counterPrice,
    });
    final body = _mapResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Could not update offer');
    }
    return body;
  }

  static Future<Map<String, dynamic>> customerOfferResponse(
    String offerId, {
    required String action,
  }) async {
    final response = await ApiService.patch(
        '/product-offers/$offerId/customer-response',
        body: {
          'action': action,
        });
    final body = _mapResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'Could not update offer');
    }
    return body;
  }

  static Future<Map<String, dynamic>> createOrderFromOffer(
    String offerId, {
    required String deliveryAddress,
  }) async {
    final response =
        await ApiService.post('/product-offers/$offerId/order', body: {
      'deliveryAddress': deliveryAddress,
    });
    final body = _mapResponse(response.body) ?? <String, dynamic>{};
    if (response.statusCode != 201 || body['order'] == null) {
      throw Exception(body['error'] ?? 'Could not create order from offer');
    }
    return body;
  }

  // Get delivery orders for an artisan (craftsman)
  static Future<List<dynamic>> getArtisanDeliveries(String artisanId) async {
    try {
      final response =
          await ApiService.get('/delivery/orders/artisan/$artisanId');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['orders'] is List) {
          return List<dynamic>.from(decoded['orders']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Assign a driver to a delivery order (artisan/admin)
  static Future<bool> assignDriverToDelivery(
      String deliveryOrderId, String driverId) async {
    try {
      final response = await ApiService.post(
          '/delivery/orders/$deliveryOrderId/assign-driver',
          body: {
            'driverId': driverId,
          });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Fetch available drivers for assignment
  static Future<List<dynamic>> getAvailableDrivers() async {
    try {
      final response = await ApiService.get('/delivery/drivers');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['drivers'] is List) {
          return List<dynamic>.from(decoded['drivers']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createDeliveryOrder({
    required String orderId,
    required String pickupAddress,
    required String pickupPhone,
    required DateTime dueDate,
    String? driverId,
  }) async {
    try {
      final response = await ApiService.post('/delivery/orders', body: {
        'orderId': orderId,
        'pickupAddress': pickupAddress,
        'pickupPhone': pickupPhone,
        'dueDate': dueDate.toIso8601String(),
        if (driverId != null) 'driverId': driverId,
      });
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Create delivery order error: $e');
      return null;
    }
  }
}
