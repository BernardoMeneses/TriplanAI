import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
import '../../common/app_colors.dart';
import '../../services/subscription_service.dart';
import '../../services/adapty_service.dart';

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AdaptyService _adaptyService = AdaptyService();
  SubscriptionPlan _selectedPlan = SubscriptionPlan.basic;
  SubscriptionStatus? _currentStatus;
  List<AdaptyPaywallProduct> _basicProducts = [];
  List<AdaptyPaywallProduct> _premiumProducts = [];
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final status = await _subscriptionService.getStatus();
    
    // Carregar produtos de ambos os placements
    final basicProducts = await _adaptyService.getProducts(
      placementId: AdaptyService.basicPlacementId,
    );
    final premiumProducts = await _adaptyService.getProducts(
      placementId: AdaptyService.premiumPlacementId,
    );
    
    if (kDebugMode) {
      print('📦 Basic products loaded: ${basicProducts.length}');
      for (final p in basicProducts) {
        print('   - ${p.vendorProductId}');
      }
      print('📦 Premium products loaded: ${premiumProducts.length}');
      for (final p in premiumProducts) {
        print('   - ${p.vendorProductId}');
      }
    }
    
    setState(() {
      _currentStatus = status;
      _basicProducts = basicProducts;
      _premiumProducts = premiumProducts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('subscription.choose_plan'.tr()),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Plan Badge
                  if (_currentStatus != null)
                    _buildCurrentPlanBadge(context),
                  
                  const SizedBox(height: 24),

                  // Plan Cards
                  _buildPlanCard(
                    context,
                    plan: SubscriptionPlan.free,
                    price: '€0',
                    period: 'subscription.forever'.tr(),
                    features: [
                      _PlanFeature('2 ${'subscription.trips'.tr()}', true),
                      _PlanFeature('5 ${'subscription.activities_per_day'.tr()}', true),
                      _PlanFeature('3 ${'subscription.ai_month'.tr()}', true),
                      _PlanFeature('subscription.export_pdf'.tr(), false),
                      _PlanFeature('subscription.cloud_backup'.tr(), false),
                      _PlanFeature('subscription.share_trips'.tr(), false),
                    ],
                    color: Colors.grey,
                  ),
                  
                  const SizedBox(height: 16),

                  _buildPlanCard(
                    context,
                    plan: SubscriptionPlan.basic,
                    price: '€2.99',
                    period: 'subscription.per_month'.tr(),
                    features: [
                      _PlanFeature('10 ${'subscription.trips'.tr()}', true),
                      _PlanFeature('10 ${'subscription.activities_per_day'.tr()}', true),
                      _PlanFeature('20 ${'subscription.ai_month'.tr()}', true),
                      _PlanFeature('subscription.export_pdf'.tr(), true),
                      _PlanFeature('subscription.manual_backup'.tr(), true, iconColor: Colors.amber),
                      _PlanFeature('subscription.share_trips'.tr(), true),
                    ],
                    color: Colors.blue,
                    isPopular: true,
                  ),
                  
                  const SizedBox(height: 16),

                  _buildPlanCard(
                    context,
                    plan: SubscriptionPlan.premium,
                    price: '€5.99',
                    period: 'subscription.per_month'.tr(),
                    features: [
                      _PlanFeature('subscription.unlimited_trips'.tr(), true),
                      _PlanFeature('subscription.unlimited_activities'.tr(), true),
                      _PlanFeature('subscription.unlimited_ai'.tr(), true),
                      _PlanFeature('subscription.export_pdf'.tr(), true),
                      _PlanFeature('subscription.auto_backup'.tr(), true),
                      _PlanFeature('subscription.share_trips'.tr(), true),
                    ],
                    color: Colors.amber[700]!,
                  ),

                  const SizedBox(height: 32),

                  // Subscribe Button
                  if (_currentStatus?.plan != _selectedPlan)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isPurchasing ? null : _handleSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isPurchasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selectedPlan == SubscriptionPlan.free
                                    ? 'subscription.downgrade'.tr()
                                    : 'subscription.subscribe'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Restore Purchases
                  TextButton(
                    onPressed: _handleRestorePurchases,
                    child: Text(
                      'subscription.restore_purchases'.tr(),
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms and conditions
                  Text(
                    'subscription.terms_note'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planName = SubscriptionService.getPlanDisplayName(_currentStatus!.plan);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${'subscription.current_plan'.tr()}: $planName',
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required SubscriptionPlan plan,
    required String price,
    required String period,
    required List<_PlanFeature> features,
    required Color color,
    bool isPopular = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPlan == plan;
    final isCurrent = _currentStatus?.plan == plan;
    final planName = SubscriptionService.getPlanDisplayName(plan);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Plan name and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            planName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'subscription.popular'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'subscription.current'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Radio button
                Radio<SubscriptionPlan>(
                  value: plan,
                  groupValue: _selectedPlan,
                  onChanged: (value) {
                    setState(() {
                      _selectedPlan = value!;
                    });
                  },
                  activeColor: color,
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            Divider(color: isDark ? AppColors.grey100 : AppColors.grey300),
            
            const SizedBox(height: 12),

            // Features
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    feature.included ? Icons.check_circle : Icons.cancel,
                    color: feature.included
                        ? (feature.iconColor ?? Colors.green)
                        : Colors.red.withOpacity(0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: feature.included
                            ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        decoration: feature.included ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isPurchasing = true);
    
    try {
      // Encontrar produto correspondente ao plano selecionado
      final product = _getProductForPlan(_selectedPlan);
      
      if (product == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('subscription.product_not_found'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Fazer compra via Adapty
      final result = await _adaptyService.makePurchase(product);
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('premium.purchase_successful'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          // Recarregar status e voltar
          await _loadData();
          if (mounted) Navigator.of(context).pop(true);
        } else if (!result.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'premium.purchase_failed'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }
  
  AdaptyPaywallProduct? _getProductForPlan(SubscriptionPlan plan) {
    // Selecionar lista de produtos correta baseado no plano
    final products = plan == SubscriptionPlan.basic 
        ? _basicProducts 
        : _premiumProducts;
    
    if (products.isEmpty) return null;
    
    // Procurar produto mensal primeiro
    for (final product in products) {
      final id = product.vendorProductId.toLowerCase();
      if (id.contains('monthly') || !id.contains('year')) {
        return product;
      }
    }
    
    // Se não encontrar mensal, retornar o primeiro produto disponível
    return products.first;
  }

  Future<void> _handleRestorePurchases() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('subscription.restoring'.tr()),
        backgroundColor: AppColors.primary,
      ),
    );
    
    final result = await _adaptyService.restorePurchases();
    
    if (mounted) {
      if (result.success && result.hasActiveSubscription) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('premium.purchases_restored'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
        if (mounted) Navigator.of(context).pop(true);
      } else if (result.success && !result.hasActiveSubscription) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('premium.no_purchases_to_restore'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'premium.restore_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PlanFeature {
  final String text;
  final bool included;
  final Color? iconColor;

  _PlanFeature(this.text, this.included, {this.iconColor});
}
