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
    );
  }
}

/// @deprecated Use [SubscriptionStatus] from subscription_service.dart
class PremiumStatus {
  final String userId;
  final bool isPremium;
  final SubscriptionPlan plan;

  PremiumStatus({
    required this.userId,
    required this.isPremium,
    this.plan = SubscriptionPlan.free,
  });

  bool get isFree => plan == SubscriptionPlan.free;
  bool get isBasic => plan == SubscriptionPlan.basic;
  bool get isPremiumPlan => plan == SubscriptionPlan.premium;
}
