import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';
import 'api_service.dart';

/// Serviço para integração com Adapty (pagamentos in-app)
class AdaptyService {
  // Placement IDs do Adapty
  static const String basicPlacementId = 'BasicPlanPlacement';
  static const String premiumPlacementId = 'PremiumPlanPlacement';
  
  // Singleton
  static final AdaptyService _instance = AdaptyService._internal();
  factory AdaptyService() => _instance;
  AdaptyService._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();
  final ApiService _apiService = ApiService();
  
  bool _isInitialized = false;
  AdaptyPaywall? _cachedPaywall;
  List<AdaptyPaywallProduct>? _cachedProducts;

  /// Inicializar Adapty SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Configurar Adapty com a chave API
      // NOTA: Substitua pela sua chave API pública do Adapty
      await Adapty().activate(
        configuration: AdaptyConfiguration(
          apiKey: 'public_live_vVQAgUB7.ls2q7CnqdK1tT1QZqedq', // TODO: Colocar chave real aqui
        )..withLogLevel(AdaptyLogLevel.verbose),
      );
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ AdaptyService: SDK inicializado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao inicializar: $e');
      }
    }
  }

  /// Identificar utilizador (chamar após login)
  Future<void> identifyUser(String? userId, String? email) async {
    if (!_isInitialized || userId == null) return;
    
    try {
      await Adapty().identify(userId);
      
      // Atualizar atributos do perfil
      if (email != null) {
        final builder = AdaptyProfileParametersBuilder()
          ..setEmail(email);
        await Adapty().updateProfile(builder.build());
      }
      
      if (kDebugMode) {
        print('✅ AdaptyService: Utilizador identificado: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao identificar utilizador: $e');
      }
    }
  }

  /// Logout do Adapty
  Future<void> logout() async {
    if (!_isInitialized) return;
    
    try {
      await Adapty().logout();
      _cachedPaywall = null;
      _cachedProducts = null;
      
      if (kDebugMode) {
        print('✅ AdaptyService: Logout realizado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao fazer logout: $e');
      }
    }
  }

  /// Obter paywall com produtos
  Future<AdaptyPaywall?> getPaywall({String placementId = premiumPlacementId}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      if (kDebugMode) {
        print('🔍 AdaptyService: A obter paywall para placement: $placementId');
      }
      
      final paywall = await Adapty().getPaywall(placementId: placementId);
      
      if (kDebugMode) {
        print('✅ AdaptyService: Paywall obtida: ${paywall.name} (${paywall.placementId})');
      }
      
      return paywall;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao obter paywall ($placementId): $e');
      }
      return null;
    }
  }

  /// Obter produtos da paywall
  Future<List<AdaptyPaywallProduct>> getProducts({String placementId = premiumPlacementId}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Sempre obter paywall nova para garantir que é do placement correto
      final paywall = await getPaywall(placementId: placementId);
      if (paywall == null) {
        if (kDebugMode) {
          print('❌ AdaptyService: Paywall null para $placementId');
        }
        return [];
      }
      
      final products = await Adapty().getPaywallProducts(paywall: paywall);
      
      if (kDebugMode) {
        print('✅ AdaptyService: ${products.length} produtos obtidos para $placementId');
        for (final p in products) {
          print('   - ${p.vendorProductId}: ${p.price.localizedString}');
        }
      }
      
      return products;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao obter produtos ($placementId): $e');
      }
      return [];
    }
  }

  /// Fazer compra de um produto
  Future<PurchaseResult> makePurchase(AdaptyPaywallProduct product) async {
    if (!_isInitialized) {
      return PurchaseResult(
        success: false,
        error: 'Adapty não inicializado',
      );
    }
    
    try {
      // Fazer a compra
      await Adapty().makePurchase(product: product);
      
      // Obter o profile atualizado após a compra
      final profile = await Adapty().getProfile();
      
      // Verificar se compra foi bem sucedida
      final isPremiumActive = profile.accessLevels['premium']?.isActive == true;
      final isBasicActive = profile.accessLevels['basic']?.isActive == true;
      
      if (isPremiumActive || isBasicActive) {
        // Limpar cache do subscription service
        _subscriptionService.clearCache();
        
        // Notificar backend (opcional - o webhook também fará isto)
        await _syncWithBackend(profile);
        
        if (kDebugMode) {
          print('✅ AdaptyService: Compra realizada com sucesso!');
        }
        
        return PurchaseResult(
          success: true,
          isPremium: isPremiumActive,
          isBasic: isBasicActive,
        );
      }
      
      return PurchaseResult(
        success: false,
        error: 'Compra não foi ativada',
      );
    } on AdaptyError catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro Adapty na compra: ${e.message}');
      }
      
      // Verificar se foi cancelado pelo utilizador
      if (e.code == AdaptyErrorCode.paymentCancelled) {
        return PurchaseResult(
          success: false,
          cancelled: true,
        );
      }
      
      return PurchaseResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro na compra: $e');
      }
      return PurchaseResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Restaurar compras anteriores
  Future<RestoreResult> restorePurchases() async {
    if (!_isInitialized) {
      return RestoreResult(
        success: false,
        error: 'Adapty não inicializado',
      );
    }
    
    try {
      final profile = await Adapty().restorePurchases();
      
      final isPremiumActive = profile.accessLevels['premium']?.isActive == true;
      final isBasicActive = profile.accessLevels['basic']?.isActive == true;
      
      if (isPremiumActive || isBasicActive) {
        // Limpar cache
        _subscriptionService.clearCache();
        
        // Sincronizar com backend
        await _syncWithBackend(profile);
        
        if (kDebugMode) {
          print('✅ AdaptyService: Compras restauradas!');
        }
        
        return RestoreResult(
          success: true,
          hasActiveSubscription: true,
          isPremium: isPremiumActive,
          isBasic: isBasicActive,
        );
      }
      
      return RestoreResult(
        success: true,
        hasActiveSubscription: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdaptyService: Erro ao restaurar: $e');
      }
      return RestoreResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Verificar se utilizador tem subscrição ativa no Adapty
  Future<bool> hasActiveSubscription() async {
    if (!_isInitialized) return false;
    
    try {
      final profile = await Adapty().getProfile();
      return profile.accessLevels['premium']?.isActive == true ||
             profile.accessLevels['basic']?.isActive == true;
    } catch (e) {
      return false;
    }
  }

  /// Sincronizar estado com backend
  Future<void> _syncWithBackend(AdaptyProfile profile) async {
    try {
      final isPremium = profile.accessLevels['premium']?.isActive == true;
      final isBasic = profile.accessLevels['basic']?.isActive == true;
      
      String plan = 'free';
      DateTime? expiresAt;
      
      if (isPremium) {
        plan = 'premium';
        expiresAt = profile.accessLevels['premium']?.expiresAt;
      } else if (isBasic) {
        plan = 'basic';
        expiresAt = profile.accessLevels['basic']?.expiresAt;
      }
      
      // Chamar endpoint para sincronizar (backup caso webhook falhe)
      await _apiService.post('/premium/sync', body: {
        'plan': plan,
        'expires_at': expiresAt?.toIso8601String(),
        'adapty_profile_id': profile.profileId,
      });
    } catch (e) {
      // Não é crítico - o webhook fará a sincronização
      if (kDebugMode) {
        print('⚠️ AdaptyService: Falha ao sincronizar com backend: $e');
      }
    }
  }
}

/// Resultado de uma compra
class PurchaseResult {
  final bool success;
  final bool cancelled;
  final bool isPremium;
  final bool isBasic;
  final String? error;

  PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.isPremium = false,
    this.isBasic = false,
    this.error,
  });
}

/// Resultado de restauração de compras
class RestoreResult {
  final bool success;
  final bool hasActiveSubscription;
  final bool isPremium;
  final bool isBasic;
  final String? error;

  RestoreResult({
    required this.success,
    this.hasActiveSubscription = false,
    this.isPremium = false,
    this.isBasic = false,
    this.error,
  });
}
