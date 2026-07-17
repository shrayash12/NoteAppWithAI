enum Plan { free, proMonthly, proYearly }

extension PlanX on Plan {
  static Plan fromId(String id) {
    switch (id) {
      case 'pro_monthly':
        return Plan.proMonthly;
      case 'pro_yearly':
        return Plan.proYearly;
      default:
        return Plan.free;
    }
  }

  String get displayName {
    switch (this) {
      case Plan.free:
        return 'Free';
      case Plan.proMonthly:
        return 'Pro Monthly';
      case Plan.proYearly:
        return 'Pro Yearly';
    }
  }

  bool get isPro => this != Plan.free;
}

enum AIFeature { enhance, summarize, translate }

extension AIFeatureX on AIFeature {
  static AIFeature fromId(String id) {
    switch (id) {
      case 'enhance':
        return AIFeature.enhance;
      case 'translate':
        return AIFeature.translate;
      default:
        return AIFeature.summarize;
    }
  }

  String get id {
    switch (this) {
      case AIFeature.enhance:
        return 'enhance';
      case AIFeature.summarize:
        return 'summarize';
      case AIFeature.translate:
        return 'translate';
    }
  }

  String get label {
    switch (this) {
      case AIFeature.enhance:
        return 'Writing Enhancements';
      case AIFeature.summarize:
        return 'Summaries';
      case AIFeature.translate:
        return 'Translations';
    }
  }
}

class FeatureUsage {
  final int used;
  final int limit;
  final int remaining;

  const FeatureUsage({required this.used, required this.limit, required this.remaining});

  bool get isExhausted => remaining <= 0;

  factory FeatureUsage.fromMap(Map<String, dynamic> map) {
    return FeatureUsage(
      used: (map['used'] as num?)?.toInt() ?? 0,
      limit: (map['limit'] as num?)?.toInt() ?? 0,
      remaining: (map['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class UsageStatus {
  final Plan plan;
  final DateTime periodEnd;
  final Map<AIFeature, FeatureUsage> features;

  const UsageStatus({required this.plan, required this.periodEnd, required this.features});

  FeatureUsage forFeature(AIFeature feature) =>
      features[feature] ?? const FeatureUsage(used: 0, limit: 0, remaining: 0);

  factory UsageStatus.fromMap(Map<String, dynamic> map) {
    final rawFeatures = (map['features'] as Map?)?.cast<String, dynamic>() ?? {};
    return UsageStatus(
      plan: PlanX.fromId(map['plan'] as String? ?? 'free'),
      periodEnd: DateTime.tryParse(map['periodEnd'] as String? ?? '') ?? DateTime.now(),
      features: {
        for (final entry in rawFeatures.entries)
          AIFeatureX.fromId(entry.key): FeatureUsage.fromMap(
            (entry.value as Map).cast<String, dynamic>(),
          ),
      },
    );
  }
}
