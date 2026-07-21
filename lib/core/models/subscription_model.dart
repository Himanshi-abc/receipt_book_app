enum PlanType { none, trial, singleBook, multiBook }

enum SubscriptionStatus { trial, active, expired, cancelled }

enum BillingCycle { monthly, yearly }

/// One row per user (account-level, not per Business Book).
/// See SRS Section 7 (Subscription) and Section 5 (Monetization rules).
class Subscription {
  final String userId;
  final PlanType planType;
  final SubscriptionStatus status;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final BillingCycle? billingCycle;
  final DateTime? subscriptionExpiryDate;

  /// The single Business Book that remains writable when on Single Book
  /// Plan. Null if on Multi-Book Plan / trial (not needed) or no book chosen yet.
  final String? activeBusinessBookId;

  Subscription({
    required this.userId,
    required this.planType,
    required this.status,
    this.trialStartDate,
    this.trialEndDate,
    this.billingCycle,
    this.subscriptionExpiryDate,
    this.activeBusinessBookId,
  });

  bool get isOnActiveTrial {
    if (planType != PlanType.trial) return false;
    if (trialEndDate == null) return false;
    return DateTime.now().isBefore(trialEndDate!);
  }

  int? get trialDaysLeft {
    if (!isOnActiveTrial || trialEndDate == null) return null;
    return trialEndDate!.difference(DateTime.now()).inDays;
  }

  factory Subscription.fromMap(String userId, Map<String, dynamic> map) {
    return Subscription(
      userId: userId,
      planType: PlanType.values.firstWhere(
        (e) => e.name == map['planType'],
        orElse: () => PlanType.none,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SubscriptionStatus.expired,
      ),
      trialStartDate: _parseDate(map['trialStartDate']),
      trialEndDate: _parseDate(map['trialEndDate']),
      billingCycle: map['billingCycle'] == null
          ? null
          : BillingCycle.values.firstWhere(
              (e) => e.name == map['billingCycle'],
              orElse: () => BillingCycle.monthly,
            ),
      subscriptionExpiryDate: _parseDate(map['subscriptionExpiryDate']),
      activeBusinessBookId: map['activeBusinessBookId'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  Map<String, dynamic> toMap() => {
        'planType': planType.name,
        'status': status.name,
        'trialStartDate': trialStartDate?.toIso8601String(),
        'trialEndDate': trialEndDate?.toIso8601String(),
        'billingCycle': billingCycle?.name,
        'subscriptionExpiryDate': subscriptionExpiryDate?.toIso8601String(),
        'activeBusinessBookId': activeBusinessBookId,
      };

  Subscription copyWith({
    PlanType? planType,
    SubscriptionStatus? status,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
    BillingCycle? billingCycle,
    DateTime? subscriptionExpiryDate,
    String? activeBusinessBookId,
    bool clearActiveBusinessBookId = false,
  }) {
    return Subscription(
      userId: userId,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      billingCycle: billingCycle ?? this.billingCycle,
      subscriptionExpiryDate:
          subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      activeBusinessBookId: clearActiveBusinessBookId
          ? null
          : (activeBusinessBookId ?? this.activeBusinessBookId),
    );
  }

  /// A brand new account has no subscription row at all until they create
  /// their first Business Book (Individual Book never needs one).
  static Subscription none(String userId) => Subscription(
        userId: userId,
        planType: PlanType.none,
        status: SubscriptionStatus.expired,
      );
}
