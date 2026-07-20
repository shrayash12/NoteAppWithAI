import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/subscription.dart';
import '../providers/notes_provider.dart';
import '../providers/usage_provider.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Paywall shown when a user hits their AI usage limit, or when they open
/// it from Settings to manage/upgrade their plan.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Offerings? _offerings;
  bool _loading = true;
  String? _purchasingPackageId;
  bool _restoring = false;
  String? _error;

  bool get _busy => _purchasingPackageId != null || _restoring;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offerings = await SubscriptionService.getOfferings();
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } on SubscriptionServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _buy(Package? package) async {
    if (package == null || _busy) return;
    setState(() => _purchasingPackageId = package.identifier);
    try {
      await SubscriptionService.purchase(package);
      if (!mounted) return;
      await context.read<UsageProvider>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You\'re on Pro now. Enjoy!')),
      );
      Navigator.pop(context);
    } on SubscriptionServiceException catch (e) {
      if (!mounted) return;
      if (!e.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _purchasingPackageId = null);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _restoring = true);
    try {
      await SubscriptionService.restore();
      if (!mounted) return;
      await context.read<UsageProvider>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored.')),
      );
    } on SubscriptionServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradient = AppTheme.accentGradient(colorIndex);
    final plan = context.watch<UsageProvider>().plan;
    final current = _offerings?.current;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Upgrade to Pro'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Get more AI, monthly or yearly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'More Summaries, Writing Enhancements, and Translations every period.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PlanCard(
                        title: 'Free',
                        price: '₹0',
                        period: '',
                        bullets: const [
                          'Unlimited manual notes',
                          '10 AI Summaries / month',
                          '10 AI Writing Enhancements / month',
                          '10 AI Translations / month',
                        ],
                        gradient: [Colors.grey.shade500, Colors.grey.shade400],
                        isCurrent: plan == Plan.free,
                        trailing: null,
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        title: 'Pro Monthly',
                        price: current?.monthly?.storeProduct.priceString ?? '₹120',
                        period: '/month',
                        bullets: const [
                          '300 AI Summaries / month',
                          '300 AI Writing Enhancements / month',
                          '300 AI Translations / month',
                        ],
                        gradient: gradient,
                        isCurrent: plan == Plan.proMonthly,
                        trailing: current?.monthly != null
                            ? _BuyButton(
                                gradient: gradient,
                                enabled: !_busy && plan != Plan.proMonthly,
                                loading: _purchasingPackageId == current?.monthly?.identifier,
                                onTap: () => _buy(current?.monthly),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        title: 'Pro Yearly',
                        price: current?.annual?.storeProduct.priceString ?? '₹999',
                        period: '/year',
                        badge: 'Best value',
                        bullets: const [
                          '6,000 AI Summaries / year',
                          '6,000 AI Writing Enhancements / year',
                          '6,000 AI Translations / year',
                        ],
                        gradient: gradient,
                        isCurrent: plan == Plan.proYearly,
                        trailing: current?.annual != null
                            ? _BuyButton(
                                gradient: gradient,
                                enabled: !_busy && plan != Plan.proYearly,
                                loading: _purchasingPackageId == current?.annual?.identifier,
                                onTap: () => _buy(current?.annual),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: AppTheme.getTextSecondaryColor(context)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final List<String> bullets;
  final List<Color> gradient;
  final bool isCurrent;
  final Widget? trailing;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.bullets,
    required this.gradient,
    required this.isCurrent,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? gradient[0] : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isCurrent)
                Text(
                  'Current plan',
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondaryColor(context)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              if (period.isNotEmpty)
                Text(
                  period,
                  style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: gradient[0]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(fontSize: 13, color: AppTheme.getTextPrimaryColor(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final List<Color> gradient;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _BuyButton({
    required this.gradient,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Subscribe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
