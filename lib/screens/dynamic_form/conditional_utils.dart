bool evaluateDependency(dynamic actual, dynamic expected, String? operator) {
  // If no expected provided, fallback to truthy check
  if (expected == null) {
    if (actual == null) return false;
    if (actual is bool) return actual;
    if (actual is String) return actual.isNotEmpty;
    return true;
  }

  final actualStr = actual?.toString();
  // Handle list expected values
  if (expected is List) {
    final expectedStrs = expected.map((e) => e.toString()).toList();
    if (operator == null || operator == '==' || operator == 'in') {
      return expectedStrs.contains(actualStr);
    }
    if (operator == '!=') return !expectedStrs.contains(actualStr);
    if (operator == 'not_in') return !expectedStrs.contains(actualStr);
  }

  final expectedStr = expected.toString();
  switch (operator) {
    case null:
    case '==':
      return actualStr == expectedStr;
    case '!=':
      return actualStr != expectedStr;
    case 'contains':
      return actualStr != null && actualStr.toLowerCase().contains(expectedStr.toLowerCase());
    case 'in':
      return expectedStr.split(',').map((s) => s.trim()).contains(actualStr);
    case 'not_in':
      return !expectedStr.split(',').map((s) => s.trim()).contains(actualStr);
    case 'regex':
      try {
        return RegExp(expectedStr).hasMatch(actualStr ?? '');
      } catch (_) {
        return false;
      }
    default:
      return actualStr == expectedStr;
  }
}
