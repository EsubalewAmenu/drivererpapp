import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/services/billing/billing_service.dart';

void main() {
  group('SubscriptionStatus', () {
    test('fromJson parses core fields', () {
      final status = SubscriptionStatus.fromJson({
        'status': 'active',
        'hasAccess': true,
        'autoRenewing': true,
        'payerType': 'self',
        'source': 'credits',
        'subscriptionId': 'subscription.monthly',
      });

      expect(status.status, 'active');
      expect(status.hasAccess, isTrue);
      expect(status.autoRenewing, isTrue);
      expect(status.payerType, 'self');
      expect(status.source, 'credits');
      expect(status.subscriptionId, 'subscription.monthly');
    });

    test('fromJson parses ISO dates', () {
      final status = SubscriptionStatus.fromJson({
        'status': 'active',
        'hasAccess': true,
        'renewalDate': '2030-01-02T03:04:05.000Z',
        'lastVerifiedAt': '2030-01-01T01:00:00.000Z',
      });

      expect(status.renewalDate, isNotNull);
      expect(status.lastVerifiedAt, isNotNull);
      expect(status.renewalDate!.year, 2030);
      expect(status.lastVerifiedAt!.day, 1);
    });

    test('fromJson parses firestore-like timestamp map', () {
      final status = SubscriptionStatus.fromJson({
        'status': 'active',
        'hasAccess': true,
        'renewalDate': {'_seconds': 1893456000},
      });

      expect(status.renewalDate, isNotNull);
      expect(status.renewalDate!.year, 2030);
    });

    test('isInactive true for expired/canceled', () {
      final expired = SubscriptionStatus(status: 'expired', hasAccess: false);
      final canceled = SubscriptionStatus(status: 'canceled', hasAccess: false);

      expect(expired.isInactive, isTrue);
      expect(canceled.isInactive, isTrue);
    });

    test('isInactive false for active/grace', () {
      final active = SubscriptionStatus(status: 'active', hasAccess: true);
      final grace = SubscriptionStatus(status: 'grace', hasAccess: true);

      expect(active.isInactive, isFalse);
      expect(grace.isInactive, isFalse);
    });

    test('isInGracePeriod true only for grace status', () {
      final grace = SubscriptionStatus(status: 'grace', hasAccess: true);
      final active = SubscriptionStatus(status: 'active', hasAccess: true);

      expect(grace.isInGracePeriod, isTrue);
      expect(active.isInGracePeriod, isFalse);
    });

    test('daysUntilRenewal returns null for past dates', () {
      final status = SubscriptionStatus(
        status: 'expired',
        hasAccess: false,
        renewalDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(status.daysUntilRenewal, isNull);
    });

    test('daysUntilRenewal returns non-negative for future dates', () {
      final status = SubscriptionStatus(
        status: 'active',
        hasAccess: true,
        renewalDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(status.daysUntilRenewal, isNotNull);
      expect(status.daysUntilRenewal!, greaterThanOrEqualTo(1));
    });
  });
}
