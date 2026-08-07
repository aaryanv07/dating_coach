enum BillingPeriod { monthly, yearly }

class PlanAllowance {
  const PlanAllowance({required this.label, required this.detail});

  final String label;
  final String detail;
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPriceInr,
    required this.yearlyPriceInr,
    required this.allowances,
  });

  final String id;
  final String name;
  final String description;

  /// Preview copy only. A live purchase screen must use localized store data.
  final int monthlyPriceInr;
  final int? yearlyPriceInr;
  final List<PlanAllowance> allowances;

  int? get effectiveYearlyMonthlyPriceInr {
    final annualPrice = yearlyPriceInr;
    return annualPrice == null ? null : (annualPrice / 12).round();
  }
}

abstract final class SubscriptionCatalog {
  static const welcome = SubscriptionPlan(
    id: 'welcome',
    name: '30-day welcome allowance',
    description:
        'A useful introduction with no payment method and no automatic paid renewal.',
    monthlyPriceInr: 0,
    yearlyPriceInr: null,
    allowances: [
      PlanAllowance(label: 'Conversation analyses', detail: '5 for 30 days'),
      PlanAllowance(label: 'Reply generations', detail: '25 for 30 days'),
      PlanAllowance(
        label: 'First-message generations',
        detail: '5 for 30 days',
      ),
      PlanAllowance(label: 'Progress insights', detail: '1 each week'),
    ],
  );

  static const free = SubscriptionPlan(
    id: 'free',
    name: 'Free',
    description:
        'Permanent limited access after the welcome allowance finishes.',
    monthlyPriceInr: 0,
    yearlyPriceInr: null,
    allowances: [
      PlanAllowance(label: 'Conversation analyses', detail: '2 each month'),
      PlanAllowance(label: 'Reply generations', detail: '10 each month'),
      PlanAllowance(label: 'First-message generations', detail: '3 each month'),
      PlanAllowance(label: 'Progress insights', detail: '1 each month'),
    ],
  );

  static const plus = SubscriptionPlan(
    id: 'plus',
    name: 'ConvoCoach Plus',
    description:
        'More coaching across conversations without claiming unlimited AI use.',
    monthlyPriceInr: 999,
    yearlyPriceInr: 8999,
    allowances: [
      PlanAllowance(label: 'Conversation analyses', detail: '12 each month'),
      PlanAllowance(label: 'Reply generations', detail: '80 each month'),
      PlanAllowance(
        label: 'First-message generations',
        detail: '10 each month',
      ),
      PlanAllowance(label: 'Progress insights', detail: '1 each week'),
    ],
  );
}
