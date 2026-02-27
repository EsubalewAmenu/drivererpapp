import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/utils/subscription_key.dart';

void main() {
  group('buildSubscriptionKey', () {
    test('uses non-drive moduleId when provided', () {
      final key = buildSubscriptionKey(moduleName: 'Support Tickets', moduleId: 'support_tickets');
      expect(key, 'support_tickets');
    });

    test('sanitizes moduleId into underscore format', () {
      final key = buildSubscriptionKey(moduleName: 'Support Tickets', moduleId: 'Support Tickets ++');
      expect(key, 'support_tickets');
    });

    test('ignores drive-like id and falls back to moduleName', () {
      final key = buildSubscriptionKey(
        moduleName: 'Support Tickets',
        moduleId: '1fSx2xkL9mQpRstUVWxy_1234567890',
      );
      expect(key, 'support_tickets');
    });

    test('uses moduleName when moduleId is missing', () {
      final key = buildSubscriptionKey(moduleName: 'CRM Pipeline');
      expect(key, 'crm_pipeline');
    });

    test('compresses multiple separators', () {
      final key = buildSubscriptionKey(moduleName: 'Finance---Ops___Module');
      expect(key, 'finance_ops_module');
    });

    test('throws on empty name when id missing', () {
      expect(
        () => buildSubscriptionKey(moduleName: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
