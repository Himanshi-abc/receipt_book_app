import '../../l10n/app_localizations.dart';
import '../models/book_model.dart';
import '../models/subscription_model.dart';

enum LockReason { notLocked, noSubscription, expiredNotChosen, lockedByPlan }

class BookAccessResult {
  final bool writable;
  final LockReason reason;
  const BookAccessResult(this.writable, this.reason);
}

/// SRS Section 8:
/// "Is this Business Book writable right now?" check (needed before every
/// create/edit transaction, create/edit invoice, and dashboard load):
/// writable if the account is on an active trial, OR on Multi-Book Plan,
/// OR on Single Book Plan and this book equals is_active_book. Otherwise
/// it's locked - allow view/download only.
/// "Put this as one shared helper function, don't duplicate the check
/// across screens."
///
/// This is that one function. Every screen that needs to gate a write
/// action (transaction create/edit, invoice create/edit, dashboard load)
/// must call BookAccessService.check(...) and nothing else.
class BookAccessService {
  BookAccessService._();

  static BookAccessResult check(Book book, Subscription subscription) {
    // Individual Book is always free and always fully usable, regardless
    // of plan/trial status (SRS Section 5).
    if (book.isIndividual) {
      return const BookAccessResult(true, LockReason.notLocked);
    }

    // Business Book from here on.
    if (subscription.isOnActiveTrial) {
      return const BookAccessResult(true, LockReason.notLocked);
    }

    if (subscription.planType == PlanType.multiBook &&
        subscription.status == SubscriptionStatus.active) {
      return const BookAccessResult(true, LockReason.notLocked);
    }

    if (subscription.planType == PlanType.singleBook &&
        subscription.status == SubscriptionStatus.active) {
      if (subscription.activeBusinessBookId == book.id) {
        return const BookAccessResult(true, LockReason.notLocked);
      }
      return const BookAccessResult(false, LockReason.lockedByPlan);
    }

    if (subscription.planType == PlanType.none) {
      return const BookAccessResult(false, LockReason.noSubscription);
    }

    // Trial ended and no plan chosen, or subscription expired/cancelled.
    return const BookAccessResult(false, LockReason.expiredNotChosen);
  }

  static bool isWritable(Book book, Subscription subscription) =>
      check(book, subscription).writable;

  /// User-facing copy for the lock banner shown on a locked book.
  ///
  /// The gate itself ([check]) stays pure and unit-testable; only this
  /// presentation helper needs the locale.
  static String messageFor(AppLocalizations l10n, LockReason reason) {
    switch (reason) {
      case LockReason.notLocked:
        return '';
      case LockReason.noSubscription:
        return l10n.lockNoSubscription;
      case LockReason.expiredNotChosen:
        return l10n.lockTrialEnded;
      case LockReason.lockedByPlan:
        return l10n.lockedBySingleBookPlan;
    }
  }
}
