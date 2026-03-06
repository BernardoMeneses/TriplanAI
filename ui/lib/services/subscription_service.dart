import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Tipos de plano de subscrição
enum SubscriptionPlan {
  free,
  basic,
  premium,
}

/// Limites de cada plano
class PlanLimits {
  final int maxTrips; // -1 = ilimitado
  final int maxActivitiesPerDay; // -1 = ilimitado
  final int aiGenerationsPerMonth; // -1 = ilimitado
  final bool canExportPdf;
  final bool canBackupCloud; // Pode fazer backup manual para cloud
  final bool canAutoBackup; // Backup automático ativado
  final bool canShareTrips;

  const PlanLimits({
    required this.maxTrips,
    required this.maxActivitiesPerDay,
    required this.aiGenerationsPerMonth,
    required this.canExportPdf,
    required this.canBackupCloud,
    required this.canAutoBackup,
    required this.canShareTrips,
  });

  bool get isUnlimitedTrips => maxTrips == -1;
  bool get isUnlimitedActivities => maxActivitiesPerDay == -1;
  bool get isUnlimitedAI => aiGenerationsPerMonth == -1;
}

/// Limites pré-definidos para cada plano
class PlanLimitsConfig {
  static const PlanLimits free = PlanLimits(
    maxTrips: 2,
    maxActivitiesPerDay: 5,
    aiGenerationsPerMonth: 3,
    canExportPdf: false,
    canBackupCloud: false,
    canAutoBackup: false, // Backup manual apenas
    canShareTrips: false,
  );

  static const PlanLimits basic = PlanLimits(
    maxTrips: 10,
    maxActivitiesPerDay: 10,
    aiGenerationsPerMonth: 20,
    canExportPdf: true,
    canBackupCloud: true, // Pode fazer backup manual para cloud
    canAutoBackup: false, // Backup manual apenas
    canShareTrips: true,
  );

  static const PlanLimits premium = PlanLimits(
    maxTrips: -1,
    maxActivitiesPerDay: -1,
    aiGenerationsPerMonth: -1,
    canExportPdf: true,
    canBackupCloud: true,
    canAutoBackup: true, // Backup automático
    canShareTrips: true,
  );

  static PlanLimits forPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return free;
      case SubscriptionPlan.basic:
        return basic;
      case SubscriptionPlan.premium:
        return premium;
    }
  }
}

/// Status da subscrição do utilizador
class SubscriptionStatus {
  final SubscriptionPlan plan;
  final PlanLimits limits;
  final int aiGenerationsUsed;
  final int aiGenerationsRemaining;

  SubscriptionStatus({
    required this.plan,
    required this.limits,
    this.aiGenerationsUsed = 0,
  }) : aiGenerationsRemaining = limits.isUnlimitedAI 
      ? -1 
      : (limits.aiGenerationsPerMonth - aiGenerationsUsed).clamp(0, limits.aiGenerationsPerMonth);

  bool get isPaid => plan != SubscriptionPlan.free;
  bool get isPremium => plan == SubscriptionPlan.premium;
  bool get isBasic => plan == SubscriptionPlan.basic;
  bool get isFree => plan == SubscriptionPlan.free;

  /// Verifica se pode criar mais viagens
  bool canCreateTrip(int currentTripCount) {
    if (limits.isUnlimitedTrips) return true;
    return currentTripCount < limits.maxTrips;
  }

  /// Verifica se pode usar IA para gerar viagens
  bool get canUseAI {
    if (limits.isUnlimitedAI) return true;
    return aiGenerationsRemaining > 0;
  }
}

/// Serviço de gestão de subscrições
class SubscriptionService {
  final ApiService _apiService = ApiService();

  // Cache local do status
  SubscriptionStatus? _cachedStatus;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Obtém status da subscrição (com cache)
  Future<SubscriptionStatus> getStatus({bool forceRefresh = false}) async {
    // Usar cache se disponível e não expirado
    if (!forceRefresh && 
        _cachedStatus != null && 
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedStatus!;
    }

    try {
      final response = await _apiService.get('/premium/status');
      
      final planStr = response['plan'] as String? ?? 'free';
      final plan = SubscriptionPlan.values.firstWhere(
        (p) => p.name == planStr,
        orElse: () => SubscriptionPlan.free,
      );

      _cachedStatus = SubscriptionStatus(
        plan: plan,
        limits: PlanLimitsConfig.forPlan(plan),
        aiGenerationsUsed: response['ai_generations_used'] ?? 0,
      );
      
      _lastFetch = DateTime.now();
      
      if (kDebugMode) {
        print('💳 SubscriptionService: Plano ${plan.name}');
      }
      
      return _cachedStatus!;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SubscriptionService: Erro ao obter status: $e');
      }
      
      // Retornar cache se disponível, senão free
      return _cachedStatus ?? SubscriptionStatus(
        plan: SubscriptionPlan.free,
        limits: PlanLimitsConfig.free,
      );
    }
  }

  /// Limpa o cache (chamar após compra)
  void clearCache() {
    _cachedStatus = null;
    _lastFetch = null;
  }

  /// Verifica se uma feature está disponível
  Future<bool> hasFeature(String feature) async {
    final status = await getStatus();
    
    switch (feature) {
      case 'export_pdf':
        return status.limits.canExportPdf;
      case 'cloud_backup':
        return status.limits.canBackupCloud;
      case 'auto_backup':
        return status.limits.canAutoBackup;
      case 'share_trips':
        return status.limits.canShareTrips;
      case 'ai_generation':
        return status.canUseAI;
      default:
        return false;
    }
  }

  /// Obtém nome legível do plano
  static String getPlanDisplayName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.basic:
        return 'Basic';
      case SubscriptionPlan.premium:
        return 'Premium';
    }
  }

  /// Obtém descrição do plano
  static String getPlanDescription(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Funcionalidades básicas, backup manual';
      case SubscriptionPlan.basic:
        return 'Mais viagens, PDF e backup automático';
      case SubscriptionPlan.premium:
        return 'Tudo ilimitado';
    }
  }
}
