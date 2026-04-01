import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common/app_colors.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../services/subscription_service.dart';
import '../../services/adapty_service.dart';

class SubscriptionPlansPage extends StatefulWidget {
  final SubscriptionPlan? initialPlan;
  const SubscriptionPlansPage({super.key, this.initialPlan});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage>
    with SingleTickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final AdaptyService _adaptyService = AdaptyService();
  SubscriptionPlan _selectedPlan = SubscriptionPlan.basic;
  SubscriptionStatus? _currentStatus;
  List<AdaptyPaywallProduct> _basicProducts = [];
  List<AdaptyPaywallProduct> _premiumProducts = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isCancelling = false;
  String? _loadError;

  // Animation + scrolling helpers for the initial plan transition
  final ScrollController _listController = ScrollController();
  late final AnimationController _moveController;
  Animation<double>? _moveAnimation;
  bool _showMovingHighlight = false;
  double _highlightPos = 0.0;
  Color _highlightColor = Colors.transparent;
  static const double _cardWidth = 330.0;
  static const double _cardGap = 14.0;

  @override
  void initState() {
    super.initState();
    // Initialize animator and scroll controller
    _moveController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 900),
          )
          ..addListener(() {
            setState(() {
              _highlightPos = _moveAnimation?.value ?? _highlightPos;
            });
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _showMovingHighlight = false;
                _selectedPlan = widget.initialPlan ?? _selectedPlan;
              });
              _scrollToIndex(_planToIndex(_selectedPlan));
            }
          });

    _listController.addListener(() {
      setState(() {});
    });

    // Load data and then possibly run the initial highlight animation
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

    final error = _adaptyService.lastError;
    setState(() {
      _currentStatus = status;
      _basicProducts = basicProducts;
      _premiumProducts = premiumProducts;
      _isLoading = false;
      _loadError = (basicProducts.isEmpty && premiumProducts.isEmpty)
          ? error
          : null;
      // reflect the current plan as the initially selected one
      _selectedPlan = _currentStatus?.plan ?? _selectedPlan;
    });

    if (widget.initialPlan != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runInitialHighlight();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('subscription.choose_plan'.tr()),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (kDebugMode && _loadError != null)
                  Material(
                    color: Colors.orange.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bug_report,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ DEBUG — Adapty: $_loadError',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Current Plan Badge
                        if (_currentStatus != null)
                          _buildCurrentPlanBadge(context),

                        const SizedBox(height: 24),

                        // Horizontal plan selector with animated highlight overlay
                        SizedBox(
                          height: 430,
                          child: Stack(
                            children: [
                              ListView(
                                controller: _listController,
                                scrollDirection: Axis.horizontal,
                                children: [
                                  SizedBox(
                                    width: _cardWidth,
                                    child: _buildPlanCard(
                                      context,
                                      plan: SubscriptionPlan.free,
                                      price: '€0',
                                      period: 'subscription.forever'.tr(),
                                      features: [
                                        _PlanFeature(
                                          '2 ${'subscription.trips'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          '5 ${'subscription.activities_per_day'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          '3 ${'subscription.ai_month'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.export_pdf'.tr(),
                                          false,
                                        ),
                                        _PlanFeature(
                                          'subscription.cloud_backup'.tr(),
                                          false,
                                        ),
                                        _PlanFeature(
                                          'subscription.share_trips'.tr(),
                                          false,
                                        ),
                                      ],
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(width: _cardGap),
                                  SizedBox(
                                    width: _cardWidth,
                                    child: _buildPlanCard(
                                      context,
                                      plan: SubscriptionPlan.basic,
                                      price: _getLocalizedPriceForPlan(
                                        SubscriptionPlan.basic,
                                        fallback: '€2.99',
                                      ),
                                      period: _getLocalizedPeriodForPlan(
                                        SubscriptionPlan.basic,
                                      ),
                                      features: [
                                        _PlanFeature(
                                          '10 ${'subscription.trips'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          '10 ${'subscription.activities_per_day'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          '20 ${'subscription.ai_month'.tr()}',
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.export_pdf'.tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.manual_backup'.tr(),
                                          true,
                                          iconColor: Colors.amber,
                                        ),
                                        _PlanFeature(
                                          'subscription.share_trips'.tr(),
                                          true,
                                        ),
                                      ],
                                      color: Colors.blue,
                                      isPopular: true,
                                    ),
                                  ),
                                  SizedBox(width: _cardGap),
                                  SizedBox(
                                    width: _cardWidth,
                                    child: _buildPlanCard(
                                      context,
                                      plan: SubscriptionPlan.premium,
                                      price: _getLocalizedPriceForPlan(
                                        SubscriptionPlan.premium,
                                        fallback: '€5.99',
                                      ),
                                      period: _getLocalizedPeriodForPlan(
                                        SubscriptionPlan.premium,
                                      ),
                                      features: [
                                        _PlanFeature(
                                          'subscription.unlimited_trips'.tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.unlimited_activities'
                                              .tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.unlimited_ai'.tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.export_pdf'.tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.auto_backup'.tr(),
                                          true,
                                        ),
                                        _PlanFeature(
                                          'subscription.share_trips'.tr(),
                                          true,
                                        ),
                                      ],
                                      color: Colors.amber[700]!,
                                    ),
                                  ),
                                ],
                              ),

                              // Moving highlight overlay (starts at current plan, slides to target)
                              if (_showMovingHighlight)
                                Positioned(
                                  left:
                                      (_highlightPos -
                                              (_listController.hasClients
                                                  ? _listController.offset
                                                  : 0.0))
                                          .clamp(
                                            0.0,
                                            MediaQuery.of(context).size.width -
                                                _cardWidth,
                                          ),
                                  top: 0,
                                  child: IgnorePointer(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      width: _cardWidth,
                                      height: 430,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _highlightColor,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Subscribe Button
                        if (_currentStatus?.plan != _selectedPlan)
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isPurchasing
                                  ? null
                                  : _handleSubscribe,
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
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),

                        if (_currentStatus?.isPaid == true) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isCancelling
                                ? null
                                : _showManageOrCancelDialog,
                            icon: _isCancelling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cancel_outlined),
                            label: Text(
                              'subscription.manage_cancel_button'.tr(),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Terms and conditions
                        Text(
                          'subscription.terms_note'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentPlanBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planName = SubscriptionService.getPlanDisplayName(
      _currentStatus!.plan,
    );

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
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
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
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Divider(color: isDark ? AppColors.grey100 : AppColors.grey300),

            const SizedBox(height: 12),

            // Features
            ...features.map(
              (feature) => Padding(
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
                              ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight)
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          decoration: feature.included
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    if (_selectedPlan == SubscriptionPlan.free) {
      await _downgradeToFree();
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      // Encontrar produto correspondente ao plano selecionado
      final product = _getProductForPlan(_selectedPlan);

      if (product == null) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'subscription.product_not_found'.tr(),
          );
        }
        return;
      }

      // Fazer compra via Adapty
      final result = await _adaptyService.makePurchase(product);

      if (mounted) {
        if (result.success) {
          SnackBarHelper.showSuccess(
            context,
            'premium.purchase_successful'.tr(),
          );
          // Recarregar status e voltar
          await _loadData();
          if (mounted) Navigator.of(context).pop(true);
        } else if (!result.cancelled) {
          SnackBarHelper.showError(
            context,
            result.error ?? 'premium.purchase_failed'.tr(),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  AdaptyPaywallProduct? _getProductForPlan(SubscriptionPlan plan) {
    if (plan == SubscriptionPlan.free) return null;

    // Selecionar lista de produtos correta baseado no plano
    final products = plan == SubscriptionPlan.basic
        ? _basicProducts
        : _premiumProducts;

    if (products.isEmpty) return null;

    // Procurar produto mensal primeiro
    for (final product in products) {
      final id = product.vendorProductId.toLowerCase();
      if (id.contains('month') || id.contains('mensal')) {
        return product;
      }
    }

    // Depois tentar anual
    for (final product in products) {
      final id = product.vendorProductId.toLowerCase();
      if (id.contains('year') ||
          id.contains('annual') ||
          id.contains('anual')) {
        return product;
      }
    }

    // Se não encontrar mensal, retornar o primeiro produto disponível
    return products.first;
  }

  String _getLocalizedPriceForPlan(
    SubscriptionPlan plan, {
    required String fallback,
  }) {
    final product = _getProductForPlan(plan);
    return product?.price.localizedString ?? fallback;
  }

  String _getLocalizedPeriodForPlan(SubscriptionPlan plan) {
    final product = _getProductForPlan(plan);
    if (product == null) return 'subscription.per_month'.tr();

    final id = product.vendorProductId.toLowerCase();
    if (id.contains('year') || id.contains('annual') || id.contains('anual')) {
      return 'subscription.per_year'.tr();
    }
    return 'subscription.per_year'.tr();
  }

  Future<void> _showManageOrCancelDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.manage_accounts,
                        color: Colors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'subscription.manage_cancel_title'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'subscription.manage_cancel_description'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'subscription.manage_cancel_store_notice'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('common.close'.tr()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _openStoreSubscriptions();
                        },
                        child: Text('subscription.open_store'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _downgradeToFree();
                    },
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: Text('subscription.back_to_free'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStoreSubscriptions() async {
    final uri = (defaultTargetPlatform == TargetPlatform.iOS)
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=com.triplanai.app',
          );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      SnackBarHelper.showError(context, 'subscription.open_store_failed'.tr());
    }
  }

  Future<void> _downgradeToFree() async {
    setState(() => _isCancelling = true);

    try {
      final success = await _subscriptionService.deactivatePlan();
      if (!mounted) return;

      if (success) {
        await _loadData();
        if (!mounted) return;
        SnackBarHelper.showSuccess(
          context,
          'subscription.back_to_free_success'.tr(),
        );
      } else {
        SnackBarHelper.showError(
          context,
          'subscription.back_to_free_failed'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    SnackBarHelper.showInfo(context, 'subscription.restoring'.tr());

    final result = await _adaptyService.restorePurchases();

    if (mounted) {
      if (result.success && result.hasActiveSubscription) {
        SnackBarHelper.showSuccess(context, 'premium.purchases_restored'.tr());
        await _loadData();
        if (mounted) Navigator.of(context).pop(true);
      } else if (result.success && !result.hasActiveSubscription) {
        SnackBarHelper.showWarning(
          context,
          'premium.no_purchases_to_restore'.tr(),
        );
      } else {
        SnackBarHelper.showError(
          context,
          result.error ?? 'premium.restore_failed'.tr(),
        );
      }
    }
  }

  int _planToIndex(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 0;
      case SubscriptionPlan.basic:
        return 1;
      case SubscriptionPlan.premium:
        return 2;
    }
  }

  Color _colorForPlan(SubscriptionPlan plan) {
    if (plan == SubscriptionPlan.premium) return Colors.amber[700]!;
    if (plan == SubscriptionPlan.basic) return Colors.blue;
    return Colors.grey;
  }

  Future<void> _scrollToIndex(int index) async {
    if (!_listController.hasClients) return;
    final viewport = _listController.position.viewportDimension;
    final centerOffset = (viewport - _cardWidth) / 2.0;
    final rawTarget = index * (_cardWidth + _cardGap);
    final target = rawTarget - centerOffset;
    final pos = target.clamp(0.0, _listController.position.maxScrollExtent);
    try {
      await _listController.animateTo(
        pos,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    } catch (_) {}
  }

  void _runInitialHighlight() {
    if (widget.initialPlan == null) return;
    final startPlan = _currentStatus?.plan ?? SubscriptionPlan.free;
    final targetPlan = widget.initialPlan!;
    final startIndex = _planToIndex(startPlan);
    final targetIndex = _planToIndex(targetPlan);
    if (startIndex == targetIndex) return;

    final startLeft = startIndex * (_cardWidth + _cardGap);
    final endLeft = targetIndex * (_cardWidth + _cardGap);

    // Ensure start card is visible
    _scrollToIndex(startIndex).then((_) async {
      await Future.delayed(const Duration(milliseconds: 120));
      setState(() {
        _highlightPos = startLeft;
        _highlightColor = _colorForPlan(targetPlan);
        _showMovingHighlight = true;
      });

      _moveAnimation = Tween<double>(begin: startLeft, end: endLeft).animate(
        CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
      );
      _moveController.reset();
      _moveController.forward();
      // Slightly scroll toward end while animating
      _scrollToIndex(targetIndex);
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _moveController.dispose();
    super.dispose();
  }
}

class _PlanFeature {
  final String text;
  final bool included;
  final Color? iconColor;

  _PlanFeature(this.text, this.included, {this.iconColor});
}
