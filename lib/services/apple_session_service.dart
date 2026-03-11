import 'package:shared_preferences/shared_preferences.dart';

class AppleSessionService {
  static const String _appleSignedInKey = 'apple_signed_in';
  static const String _appleUserIdKey = 'apple_user_id';
  static const String _appleEmailKey = 'apple_email';

  static Future<void> saveAppleSession({
    required String userId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appleSignedInKey, true);
    await prefs.setString(_appleUserIdKey, userId);
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_appleEmailKey, email);
    }
  }

  static Future<bool> isAppleSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appleSignedInKey) ?? false;
  }

  static Future<String?> getAppleUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appleUserIdKey);
  }

  static Future<void> clearAppleSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appleSignedInKey);
    await prefs.remove(_appleUserIdKey);
    await prefs.remove(_appleEmailKey);
  }
}
