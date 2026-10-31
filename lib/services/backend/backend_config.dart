import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'DRIVEERP_API_URL',
    defaultValue: 'http://localhost:8040/wp-json/driveerp/v2',
  );
  static const String googleClientId = String.fromEnvironment(
    'DRIVEERP_GOOGLE_CLIENT_ID',
    defaultValue:
        '810073225620-v8cdeltgh512iabi5igd8adum1lqo3ki.apps.googleusercontent.com',
  );

  static Uri endpoint(String path) {
    final base = Uri.parse(baseUrl);
    final localProfile = kProfileMode && const ['localhost', '127.0.0.1', '10.0.2.2'].contains(base.host);
    if (base.scheme != 'https' && !((kDebugMode || localProfile) && base.scheme == 'http')) {
      throw StateError(
        'DriveERP requires an HTTPS backend in release builds or for non-local profile backends.',
      );
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path');
  }
}
