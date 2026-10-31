import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

/// The WordPress bearer is used only for the native ERP API.
class BackendSession {
  static String? token;
  static String? userId;
  static String email = "";
  static http.Client transport = http.Client();
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  static Map<String, String> mediaHeaders(String url) {
    final uri = Uri.tryParse(url);
    final base = BackendConfig.endpoint('attachments');
    return token != null &&
            uri != null &&
            uri.origin == base.origin &&
            uri.path.startsWith('${base.path}/')
        ? {'Authorization': 'Bearer $token'}
        : {};
  }

  static String mediaUrl(String id) => BackendConfig.endpoint(
    'attachments/${Uri.encodeComponent(id)}',
  ).toString();
  static Future<void> login(String idToken) async {
    final response = await transport.post(
      BackendConfig.endpoint('auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'WordPress sign-in failed (${response.statusCode}). ${_message(response.body)}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    token = data['token'] as String;
    userId = (data['user'] as Map)['id'] as String;
    email = (data['user'] as Map)['email'] as String;
  }

  static Future<http.Response> billing(
    String action,
    Map<String, dynamic> body,
  ) => transport.post(
    BackendConfig.endpoint('billing/$action'),
    headers: headers,
    body: jsonEncode(body),
  );
  static Future<void> logout() async {
    try {
      if (token != null) {
        await transport
            .post(BackendConfig.endpoint('auth/logout'), headers: headers)
            .timeout(const Duration(seconds: 5));
      }
    } finally {
      token = null;
      userId = null;
      email = "";
    }
  }

  static String _message(String body) {
    try {
      return (jsonDecode(body) as Map)['message']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }
}
