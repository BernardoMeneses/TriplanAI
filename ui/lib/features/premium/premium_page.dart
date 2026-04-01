import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../services/adapty_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final AdaptyService _adaptyService = AdaptyService();
  bool _isLoading = false;
  String _selectedPlan = 'yearly'; // 'monthly' or 'yearly'
  List<AdaptyPaywallProduct> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _adaptyService.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      // Keep current products state if loading fails.
    }
  }

  /// Encontrar produto por período (mensal ou anual)
  AdaptyPaywallProduct? _getProductForPlan(String plan) {
    if (_products.isEmpty) return null;

    // Procurar por ID do produto que contenha 'monthly' ou 'yearly'
    for (final product in _products) {
      final id = product.vendorProductId.toLowerCase();
      if (plan == 'monthly' &&
          (id.contains('month') || id.contains('mensal'))) {
        return product;
      }
      if (plan == 'yearly' && (id.contains('year') || id.contains('anual'))) {
        return product;
      }
    }

    // Se não encontrar, retornar o primeiro
    return _products.isNotEmpty ? _products.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.premium.tr()),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.surfaceDark, AppColors.backgroundDark]
                    : [AppColors.surfaceLight, AppColors.backgroundLight],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Premium Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    size: 80,
                    color: Colors.amber[700],
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  AppConstants.upgradeToPremium.tr(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    AppConstants.activatePremiumSubtitle.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Features List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        context,
                        icon: Icons.explore,
                        title: AppConstants.unlimitedTrips.tr(),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        context,
                        icon: Icons.psychology,
                        title: AppConstants.aiSuggestions.tr(),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        context,
                        icon: Icons.priority_high,
                        title: AppConstants.prioritySupport.tr(),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        context,
                        icon: Icons.offline_bolt,
                        title: AppConstants.offlineMode.tr(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Pricing Plans
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Yearly Plan (Most Popular)
                      _buildPricingCard(
                        context,
                        planType: 'yearly',
                        title: AppConstants.yearly.tr(),
                        price: _getLocalizedPriceForPlan(
                          'yearly',
                          fallback: '€39.99',
                        ),
                        period: AppConstants.perYear.tr(),
                        savings: '${AppConstants.savePremium.tr()} 33%',
                        isMostPopular: true,
                      ),

                      const SizedBox(height: 16),

                      // Monthly Plan
                      _buildPricingCard(
                        context,
                        planType: 'monthly',
                        title: AppConstants.monthly.tr(),
                        price: _getLocalizedPriceForPlan(
                          'monthly',
                          fallback: '€5.99',
                        ),
                        period: AppConstants.perMonth.tr(),
                        isMostPopular: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Subscribe Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              AppConstants.subscribeContinue.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Restore Purchases Button
                TextButton(
                  onPressed: _isLoading ? null : _handleRestorePurchases,
                  child: Text(
                    AppConstants.restorePurchases.tr(),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[600], size: 24),
        ],
      ),
    );
  }

  Widget _buildPricingCard(
    BuildContext context, {
    required String planType,
    required String title,
    required String price,
    required String period,
    String? savings,
    required bool isMostPopular,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPlan == planType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = planType;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (isMostPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.mostPopular.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isSelected && !isMostPopular)
                  Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
            if (savings != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  savings,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    final product = _getProductForPlan(_selectedPlan);

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Produtos não disponíveis. Tente novamente.'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adaptyService.makePurchase(product);

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(AppConstants.purchaseSuccessful.tr())),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Voltar para a página anterior
          Navigator.pop(context, true);
        }
      } else if (result.cancelled) {
        // Utilizador cancelou - não mostrar erro
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.error ?? AppConstants.purchaseFailed.tr(),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(AppConstants.purchaseFailed.tr())),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLocalizedPriceForPlan(
    String planType, {
    required String fallback,
  }) {
    final product = _getProductForPlan(planType);
    return product?.price.localizedString ?? fallback;
  }

  Future<void> _handleRestorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _adaptyService.restorePurchases();

      if (result.success && result.hasActiveSubscription) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(AppConstants.purchasesRestored.tr())),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else if (result.success) {
        // Sem compras para restaurar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(AppConstants.noPurchasesToRestore.tr())),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.error ?? AppConstants.restoreFailed.tr(),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(AppConstants.restoreFailed.tr())),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
