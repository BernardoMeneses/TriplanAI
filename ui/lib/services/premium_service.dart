import 'subscription_service.dart';

/// @deprecated Use [SubscriptionService] instead
/// Este serviço mantém-se para retrocompatibilidade
class PremiumService {
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Verificar status premium do utilizador
  /// @deprecated Use [SubscriptionService.getStatus()] instead
  Future<PremiumStatus> checkPremiumStatus() async {
    final status = await _subscriptionService.getStatus();
    return PremiumStatus(
      userId: '',
      isPremium: status.isPaid,
      plan: status.plan,
      premiumSince: status.subscriptionSince,
      premiumExpiresAt: status.subscriptionExpiresAt,
    );
  }
}

/// @deprecated Use [SubscriptionStatus] from subscription_service.dart
class PremiumStatus {
  final String userId;
  final bool isPremium;
  final SubscriptionPlan plan;
  final DateTime? premiumSince;
  final DateTime? premiumExpiresAt;

  PremiumStatus({
    required this.userId,
    required this.isPremium,
    this.plan = SubscriptionPlan.free,
    this.premiumSince,
    this.premiumExpiresAt,
  });

  bool get isExpired {
    if (!isPremium) return true;
    if (premiumExpiresAt == null) return false;
    return DateTime.now().isAfter(premiumExpiresAt!);
  }

  bool get isFree => plan == SubscriptionPlan.free;
  bool get isBasic => plan == SubscriptionPlan.basic;
  bool get isPremiumPlan => plan == SubscriptionPlan.premium;
}
