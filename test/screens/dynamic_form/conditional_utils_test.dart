import 'package:flutter_test/flutter_test.dart';
import 'package:drivererpapp/screens/dynamic_form/conditional_utils.dart';

void main() {
  group('evaluateDependency', () {
    test('null expected falls back to truthy checks', () {
      expect(evaluateDependency(true, null, null), isTrue);
      expect(evaluateDependency(false, null, null), isFalse);
      expect(evaluateDependency('hello', null, null), isTrue);
      expect(evaluateDependency('', null, null), isFalse);
      expect(evaluateDependency(0, null, null), isTrue);
      expect(evaluateDependency(null, null, null), isFalse);
    });

    test('equality and inequality', () {
      expect(evaluateDependency('a', 'a', '=='), isTrue);
      expect(evaluateDependency('a', 'b', '=='), isFalse);
      expect(evaluateDependency('a', 'b', '!='), isTrue);
    });

    test('contains operator is case-insensitive', () {
      expect(evaluateDependency('HelloWorld', 'hell', 'contains'), isTrue);
      expect(evaluateDependency('abc', 'd', 'contains'), isFalse);
    });

    test('in and not_in with list and comma string', () {
      expect(evaluateDependency('x', ['x', 'y'], null), isTrue);
      expect(evaluateDependency('z', ['x', 'y'], 'not_in'), isTrue);
      expect(evaluateDependency('a', 'a,b,c', 'in'), isTrue);
      expect(evaluateDependency('d', 'a,b,c', 'not_in'), isTrue);
    });

    test('regex operator handles invalid regex gracefully', () {
      expect(evaluateDependency('abc', '[', 'regex'), isFalse);
      expect(evaluateDependency('123-45', r'\d{3}-\d{2}', 'regex'), isTrue);
    });
  });
}
