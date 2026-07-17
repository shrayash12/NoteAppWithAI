import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

/// Holds the server-computed AI usage/plan state for the current user.
class UsageProvider extends ChangeNotifier {
  UsageStatus? _status;
  bool _isLoading = false;

  UsageStatus? get status => _status;
  bool get isLoading => _isLoading;
  Plan get plan => _status?.plan ?? Plan.free;

  FeatureUsage? usageFor(AIFeature feature) => _status?.forFeature(feature);

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _status = await SubscriptionService.getUsageStatus();
    } catch (_) {
      // Keep the previous status on a transient failure.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _status = null;
    notifyListeners();
  }
}
