import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';

class CraftGoPaymentResult {
  final double total;
  final double adminCommission;
  final double artisanAmount;

  const CraftGoPaymentResult({
    required this.total,
    required this.adminCommission,
    required this.artisanAmount,
  });
}

class PaymentService {
  static Future<CraftGoPaymentResult> payHireOrder({
    required String hireRequestId,
    required bool darkMode,
  }) async {
    if (kIsWeb) {
      return _payHireOrderOnWeb(hireRequestId);
    }

    final intentResponse = await ApiService.post(
      '/payments/hire/$hireRequestId/intent',
    );
    final intentBody = _decode(intentResponse.body);
    if (intentResponse.statusCode != 201) {
      throw Exception(intentBody['error'] ?? 'Could not start payment');
    }

    final publishableKey = intentBody['publishableKey']?.toString() ?? '';
    final clientSecret =
        intentBody['paymentIntentClientSecret']?.toString() ?? '';
    if (publishableKey.isEmpty || clientSecret.isEmpty) {
      throw Exception('Stripe payment configuration is incomplete');
    }

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'CraftGo',
        style: darkMode ? ThemeMode.dark : ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Color(0xFFD4A017)),
          shapes: PaymentSheetShape(borderRadius: 16),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    final confirmResponse = await ApiService.post(
      '/payments/hire/$hireRequestId/confirm',
    );
    final confirmBody = _decode(confirmResponse.body);
    if (confirmResponse.statusCode != 200) {
      throw Exception(confirmBody['error'] ?? 'Could not confirm payment');
    }

    final transaction = Map<String, dynamic>.from(
      confirmBody['transaction'] as Map? ?? const {},
    );
    return CraftGoPaymentResult(
      total: _number(transaction['grossAmount']),
      adminCommission: _number(transaction['adminCommission']),
      artisanAmount: _number(transaction['artisanAmount']),
    );
  }

  /// Pay a delivery order (escrow-protected). Returns the same result shape
  /// as other payments: total, platform commission, and recipient amount.
  static Future<CraftGoPaymentResult> payDelivery({
    required String deliveryOrderId,
    required bool darkMode,
  }) async {
    final intentResponse = await ApiService.post(
      '/payments/delivery/$deliveryOrderId/intent',
    );
    final intentBody = _decode(intentResponse.body);
    if (intentResponse.statusCode != 201 && intentResponse.statusCode != 200) {
      throw Exception(
          intentBody['error'] ?? 'Could not start delivery payment');
    }

    final publishableKey = intentBody['publishableKey']?.toString() ?? '';
    final clientSecret =
        intentBody['paymentIntentClientSecret']?.toString() ?? '';
    if (publishableKey.isEmpty || clientSecret.isEmpty) {
      throw Exception('Stripe payment configuration is incomplete');
    }

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'CraftGo',
        style: darkMode ? ThemeMode.dark : ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Color(0xFFD4A017)),
          shapes: PaymentSheetShape(borderRadius: 16),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    final confirmResponse = await ApiService.post(
      '/payments/delivery/$deliveryOrderId/confirm',
    );
    final confirmBody = _decode(confirmResponse.body);
    if (confirmResponse.statusCode != 200) {
      throw Exception(
          confirmBody['error'] ?? 'Could not confirm delivery payment');
    }

    final transaction = Map<String, dynamic>.from(
      confirmBody['transaction'] as Map? ?? const {},
    );
    return CraftGoPaymentResult(
      total: _number(transaction['grossAmount']),
      adminCommission: _number(
          transaction['platformCommission'] ?? transaction['adminCommission']),
      artisanAmount:
          _number(transaction['driverAmount'] ?? transaction['artisanAmount']),
    );
  }

  static Future<CraftGoPaymentResult> _payHireOrderOnWeb(
      String hireRequestId) async {
    final response = await ApiService.post(
      '/payments/hire/$hireRequestId/checkout',
    );
    final body = _decode(response.body);
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Could not start Stripe Checkout');
    }

    final checkoutUrl = body['checkoutUrl']?.toString() ?? '';
    if (checkoutUrl.isEmpty) throw Exception('Stripe Checkout URL is missing');
    final opened = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw Exception('Could not open Stripe Checkout');

    // The Checkout success page verifies Stripe on the backend. Keep watching
    // the shared ledger so the original CraftGo tab updates automatically.
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final statusResponse = await ApiService.get(
        '/payments/hire/$hireRequestId',
      );
      if (statusResponse.statusCode != 200) continue;
      final transaction = _decode(statusResponse.body);
      if (transaction['paymentStatus'] == 'succeeded') {
        return CraftGoPaymentResult(
          total: _number(transaction['grossAmount']),
          adminCommission: _number(transaction['adminCommission']),
          artisanAmount: _number(transaction['artisanAmount']),
        );
      }
      if (transaction['paymentStatus'] == 'failed') {
        throw Exception(transaction['failureMessage'] ?? 'Payment failed');
      }
    }
    throw Exception(
        'Payment confirmation timed out. Refresh the order to check its status.');
  }

  static Future<String> payExhibitionBooth({
    required String exhibitionId,
    required double boothPrice,
    required dynamic boothId,
    required bool darkMode,
  }) async {
    final response = await ApiService.post(
      '/payments/exhibitions/$exhibitionId/checkout',
      body: {
        'boothPrice': boothPrice,
        'boothId': boothId,
      },
    );
    final body = _decode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Could not initialize booth payment');
    }

    final checkoutUrl = body['checkoutUrl']?.toString() ?? '';
    final sessionId = body['sessionId']?.toString() ?? '';
    if (checkoutUrl.isEmpty || sessionId.isEmpty) {
      throw Exception('Stripe Checkout URL is missing');
    }
    final opened = await launchUrl(Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open Stripe Checkout');

    for (var attempt = 0; attempt < 180; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final statusResponse = await ApiService.get(
          '/payments/exhibitions/$exhibitionId/checkout/$sessionId');
      if (statusResponse.statusCode != 200) continue;
      final status = _decode(statusResponse.body);
      if (status['paid'] == true) return sessionId;
      if (status['cancelled'] == true) throw Exception('Checkout cancelled');
    }
    throw Exception('Payment confirmation timed out');
  }

  static Future<Map<String, dynamic>?> getOwnerEarnings() async {
    try {
      final res = await ApiService.get('/payments/exhibitions/owner/earnings');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getOwnerEarnings error: $e');
    }
    return null;
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {
      return {};
    }
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static Future<CraftGoPaymentResult> _payCustomOrderOnWeb(
      String requestId) async {
    final response = await ApiService.post(
      '/payments/custom/$requestId/checkout',
    );
    final body = _decode(response.body);
    if (response.statusCode != 201) {
      throw Exception(body['error'] ?? 'Could not start Stripe Checkout');
    }

    final checkoutUrl = body['checkoutUrl']?.toString() ?? '';
    if (checkoutUrl.isEmpty) throw Exception('Stripe Checkout URL is missing');
    final opened = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw Exception('Could not open Stripe Checkout');

    final txn = Map<String, dynamic>.from(body['transaction'] as Map? ?? {});
    return CraftGoPaymentResult(
      total: _number(txn['total']),
      adminCommission: _number(txn['adminCommission']),
      artisanAmount: _number(txn['artisanAmount']),
    );
  }

  static Future<CraftGoPaymentResult> payCustomOrder({
    required String requestId,
    required bool darkMode,
  }) async {
    if (kIsWeb) {
      return _payCustomOrderOnWeb(requestId);
    }

    final intentResponse = await ApiService.post(
      '/payments/custom/$requestId/intent',
    );
    final intentBody = _decode(intentResponse.body);
    if (intentResponse.statusCode != 201) {
      final errorMsg = intentBody['error'] ??
          intentBody['details'] ??
          'Could not start payment';
      throw Exception('Payment initialization failed: $errorMsg');
    }

    final publishableKey = intentBody['publishableKey']?.toString() ?? '';
    final clientSecret =
        intentBody['paymentIntentClientSecret']?.toString() ?? '';
    if (publishableKey.isEmpty || clientSecret.isEmpty) {
      throw Exception('Stripe payment configuration is incomplete');
    }

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'CraftGo',
        style: darkMode ? ThemeMode.dark : ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Color(0xFFD4A017)),
          shapes: PaymentSheetShape(borderRadius: 16),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    final confirmResponse = await ApiService.post(
      '/payments/custom/$requestId/confirm',
    );
    final confirmBody = _decode(confirmResponse.body);
    if (confirmResponse.statusCode != 200) {
      final errorMsg = confirmBody['error'] ??
          confirmBody['details'] ??
          'Could not confirm payment';
      throw Exception('Payment confirmation failed: $errorMsg');
    }

    final transaction = Map<String, dynamic>.from(
      confirmBody['transaction'] as Map? ?? const {},
    );
    return CraftGoPaymentResult(
      total: _number(transaction['total']),
      adminCommission: _number(transaction['adminCommission']),
      artisanAmount: _number(transaction['artisanAmount']),
    );
  }

  static Future<bool> openPayoutOnboarding() async {
    try {
      final response = await ApiService.post('/payments/payout/onboard');
      final body = _decode(response.body);
      final url = body['onboardingUrl']?.toString();
      if (url != null && url.isNotEmpty) {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
      return false;
    } catch (e) {
      debugPrint('openPayoutOnboarding error: $e');
      return false;
    }
  }

  /// Opens a Stripe Checkout URL in an external browser. Used for ready-made
  /// product payments (web checkout redirect flow).
  static Future<void> launchStripeWebCheckout({
    required String checkoutUrl,
    required bool darkMode,
  }) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) {
      throw Exception('Invalid Stripe Checkout URL');
    }
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) {
      throw Exception('Could not open Stripe Checkout page');
    }
  }
}
