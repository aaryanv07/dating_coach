import 'package:convo_coach/core/theme/app_colors.dart';
import 'dart:io';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';
import 'package:convo_coach/features/subscription/application/store_subscription_controller.dart';
import 'package:convo_coach/features/subscription/application/store_subscription_providers.dart';
import 'package:convo_coach/features/subscription/domain/store_subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  StoreSubscriptionController? _storeController;

  StoreSubscriptionState get _storeState =>
      _storeController?.state ??
      const StoreSubscriptionState(phase: StoreSubscriptionPhase.disabled);

  @override
  void initState() {
    super.initState();
    if (AppConfig.runtime.storeBillingEnabled) {
      final platform = Platform.isIOS
          ? StoreBillingPlatform.apple
          : StoreBillingPlatform.google;
      final productIds = Map<String, BillingPeriod>.fromEntries(
        platform == StoreBillingPlatform.apple
            ? const [
                MapEntry(
                  AppConfig.appleMonthlyProductId,
                  BillingPeriod.monthly,
                ),
                MapEntry(AppConfig.appleYearlyProductId, BillingPeriod.yearly),
              ]
            : const [
                MapEntry(
                  AppConfig.googleMonthlyProductId,
                  BillingPeriod.monthly,
                ),
                MapEntry(AppConfig.googleYearlyProductId, BillingPeriod.yearly),
              ],
      );
      _storeController = StoreSubscriptionController(
        platform: platform,
        productIds: productIds,
        store: ref.read(storeBillingGatewayProvider),
        backend: ref.read(storeSubscriptionBackendProvider),
      )..addListener(_onStoreStateChanged);
      _storeController!.initialize();
    }
  }

  void _onStoreStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _storeController
      ?..removeListener(_onStoreStateChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan and usage')),
      body: ResponsiveContent(
        child: ListView(
          key: const Key('subscription-preview-list'),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Text(
              'Choose coaching that fits your pace.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppConfig.runtime.storeBillingEnabled
                  ? 'Your store shows the final localized price before you confirm. Plus activates only after server verification.'
                  : 'This preview explains the approved plans. Purchases and quota enforcement are not enabled in this build.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: context.appColors.info,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConfig.runtime.storeBillingEnabled
                              ? 'Payment stays with Apple or Google'
                              : 'No payment information is collected',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppConfig.runtime.storeBillingEnabled
                              ? 'ELLIS never receives card details. Store-signed evidence is verified by the backend before Plus is activated.'
                              : 'A future release will verify purchases on the server. This preview cannot activate or renew a subscription.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _PlanCard(plan: SubscriptionCatalog.welcome),
            const SizedBox(height: AppSpacing.md),
            _PlanCard(plan: SubscriptionCatalog.free),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Paid plan preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BillingPeriod>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BillingPeriod.monthly,
                    label: Text('Monthly'),
                  ),
                  ButtonSegment(
                    value: BillingPeriod.yearly,
                    label: Text('Yearly'),
                  ),
                ],
                selected: {_billingPeriod},
                onSelectionChanged: (selection) {
                  setState(() => _billingPeriod = selection.first);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlanCard(
              plan: SubscriptionCatalog.plus,
              billingPeriod: _billingPeriod,
              emphasized: true,
              localizedPrice:
                  _storeState.offers[_billingPeriod]?.localizedPrice,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _purchaseLabel,
              onPressed: _storeState.canPurchase
                  ? () => _storeController?.purchase(_billingPeriod)
                  : _storeState.phase == StoreSubscriptionPhase.error
                  ? _storeController?.initialize
                  : null,
              icon: AppConfig.runtime.storeBillingEnabled
                  ? Icons.workspace_premium_outlined
                  : Icons.lock_clock_outlined,
            ),
            if (AppConfig.runtime.storeBillingEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed:
                    _storeState.phase == StoreSubscriptionPhase.loading ||
                        _storeState.phase == StoreSubscriptionPhase.purchasing
                    ? null
                    : _storeController?.restore,
                child: const Text('Restore purchases'),
              ),
            ],
            if (_storeState.message case final message?) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Safety guidance, privacy controls, viewing existing results, data export and deletion will never require Plus.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String get _purchaseLabel {
    if (!AppConfig.runtime.storeBillingEnabled) {
      return 'Purchases unavailable in this build';
    }
    return switch (_storeState.phase) {
      StoreSubscriptionPhase.loading => 'Loading store plans…',
      StoreSubscriptionPhase.purchasing => 'Purchase in progress…',
      StoreSubscriptionPhase.restoring => 'Restoring purchases…',
      StoreSubscriptionPhase.active => 'Plus active',
      StoreSubscriptionPhase.error => 'Retry store connection',
      StoreSubscriptionPhase.disabled => 'Purchases unavailable',
      StoreSubscriptionPhase.ready =>
        'Choose ${_billingPeriod == BillingPeriod.monthly ? 'monthly' : 'yearly'} Plus',
    };
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    this.billingPeriod = BillingPeriod.monthly,
    this.emphasized = false,
    this.localizedPrice,
  });

  final SubscriptionPlan plan;
  final BillingPeriod billingPeriod;
  final bool emphasized;
  final String? localizedPrice;

  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

  String get _priceLabel {
    if (localizedPrice case final price?) return price;
    if (plan.monthlyPriceInr == 0) return '₹0';
    if (billingPeriod == BillingPeriod.yearly) {
      return '₹${_inr.format(plan.yearlyPriceInr)} / year';
    }
    return '₹${_inr.format(plan.monthlyPriceInr)} / month';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMonthly = plan.effectiveYearlyMonthlyPriceInr;
    return Semantics(
      container: true,
      label: '${plan.name}, $_priceLabel',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (emphasized)
                  Chip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Plus'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _priceLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: emphasized
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            if (billingPeriod == BillingPeriod.yearly &&
                effectiveMonthly != null)
              Text(
                'About ₹${_inr.format(effectiveMonthly)} per month',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final allowance in plan.allowances) ...[
              _AllowanceRow(allowance: allowance),
              if (allowance != plan.allowances.last)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllowanceRow extends StatelessWidget {
  const _AllowanceRow({required this.allowance});

  final PlanAllowance allowance;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: AppSizes.iconSmall,
          color: context.appColors.success,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(allowance.label),
              const SizedBox(height: AppSpacing.xs),
              Text(
                allowance.detail,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
