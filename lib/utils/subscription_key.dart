String buildSubscriptionKey({
  required String moduleName,
  String? moduleId,
}) {
  final trimmedId = (moduleId ?? '').trim().toLowerCase();
  if (trimmedId.isNotEmpty && !_looksLikeDriveFolderId(trimmedId)) {
    return _sanitize(trimmedId);
  }

  final trimmedName = moduleName.trim().toLowerCase();
  if (trimmedName.isEmpty) {
    throw ArgumentError('moduleName cannot be empty when moduleId is missing');
  }

  return _sanitize(trimmedName);
}

String _sanitize(String value) {
  return value
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}


bool _looksLikeDriveFolderId(String value) {
  final id = value.trim();
  return RegExp(r'^[a-z0-9_-]{20,}$').hasMatch(id);
}
