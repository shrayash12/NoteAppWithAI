import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/subscription.dart';

class SubscriptionServiceException implements Exception {
  final String message;
  final bool cancelled;
  SubscriptionServiceException(this.message, {this.cancelled = false});
  @override
  String toString() => message;
}

/// Wraps RevenueCat for purchases/restore and calls the `getUsageStatus`
/// Cloud Function for the server-computed, tamper-proof usage state.
class SubscriptionService {
  SubscriptionService._();

  // TODO: replace with your real RevenueCat public SDK keys, from
  // https://app.revenuecat.com -> Project settings -> API keys.
  // These are safe to ship in the client (public keys), unlike the Gemini key.
  static const _iosApiKey = 'appl_REPLACE_ME';
  static const _androidApiKey = 'goog_REPLACE_ME';

  static bool _configured = false;

  /// Call once at app startup. No-ops (and leaves purchasing unavailable)
  /// until real API keys are set above.
  static Future<void> configure() async {
    if (_configured || kIsWeb) return;
    final placeholder = _iosApiKey.contains('REPLACE_ME') || _androidApiKey.contains('REPLACE_ME');
    if (placeholder) return;
    try {
      final apiKey = Platform.isIOS || Platform.isMacOS ? _iosApiKey : _androidApiKey;
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _configured = true;
    } catch (_) {
      // Purchasing unavailable; AI features still work off Firestore-tracked
      // free-tier quota until this is configured.
    }
  }

  static bool get isConfigured => _configured;

  static Future<void> login(String firebaseUid) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(firebaseUid);
    } catch (_) {}
  }

  static Future<void> logout() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  static Future<Offerings> getOfferings() async {
    if (!_configured) {
      throw SubscriptionServiceException(
        'Plans aren\'t available yet. Please try again later.',
      );
    }
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      throw SubscriptionServiceException('Could not load plans: $e');
    }
  }

  static Future<void> purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw SubscriptionServiceException('Purchase cancelled.', cancelled: true);
      }
      throw SubscriptionServiceException(e.message ?? 'Purchase failed.');
    }
  }

  static Future<void> restore() async {
    if (!_configured) {
      throw SubscriptionServiceException('Not available yet.');
    }
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      throw SubscriptionServiceException('Restore failed: $e');
    }
  }

  static Future<UsageStatus> getUsageStatus() async {
    final callable = FirebaseFunctions.instance.httpsCallable('getUsageStatus');
    final response = await callable.call<Map<String, dynamic>>();
    return UsageStatus.fromMap(Map<String, dynamic>.from(response.data as Map));
  }
}
