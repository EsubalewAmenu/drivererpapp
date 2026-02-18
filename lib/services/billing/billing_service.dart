import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class SubscriptionStatus {
  final String status; // 'active', 'expired', 'canceled', 'grace', 'none', 'unknown'
  final bool hasAccess;
  final DateTime? renewalDate;
  final bool? autoRenewing;
  final String? payerType; // 'self' or 'gift'
  final String? source; // 'google' or 'apple'
  final DateTime? lastVerifiedAt;

  SubscriptionStatus({
    required this.status,
    required this.hasAccess,
    this.renewalDate,
    this.autoRenewing,
    this.payerType,
    this.source,
    this.lastVerifiedAt,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      status: json['status'] ?? 'unknown',
      hasAccess: json['hasAccess'] ?? false,
      renewalDate: _parseDate(json['renewalDate']),
      autoRenewing: json['autoRenewing'],
      payerType: json['payerType'],
      source: json['source'],
      lastVerifiedAt: _parseDate(json['lastVerifiedAt']),
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    if (date is Map && date.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
    }
    return null;
  }

  /// Days until renewal, null if not renewing or expired
  int? get daysUntilRenewal {
    if (renewalDate == null) return null;
    final now = DateTime.now();
    if (renewalDate!.isBefore(now)) return null;
    return renewalDate!.difference(now).inDays;
  }

  /// True if subscription exists but has no active access (expired or canceled)
  bool get isInactive => status != 'active' && status != 'grace';

  /// True if subscription is in grace period
  bool get isInGracePeriod => status == 'grace';
}

class BillingService {
  static const String baseUrl = 'https://us-central1-driveerp-1d5d5.cloudfunctions.net';

  /// Get subscription and entitlement status for a user's module
  /// Returns subscription status with renewal/payer information
  static Future<SubscriptionStatus> getEntitlementStatus({
    required String uid,
    required String companyId,
    required String moduleId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/getEntitlementStatus');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'companyId': companyId,
          'moduleId': moduleId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SubscriptionStatus.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        // No subscription found
        return SubscriptionStatus(
          status: 'none',
          hasAccess: false,
        );
      } else {
        throw Exception('Failed to get entitlement status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking entitlement: $e');
    }
  }

  /// Refresh subscription status with Play Store
  /// Used to verify current status from Google Play
  static Future<SubscriptionStatus> refreshSubscription({
    required String purchaseToken,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/refreshPlaySubscription');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'purchaseToken': purchaseToken,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SubscriptionStatus(
          status: data['status'] ?? 'unknown',
          hasAccess: data['status'] == 'active',
          renewalDate: data['expiryTime'] != null ? DateTime.parse(data['expiryTime']) : null,
          autoRenewing: data['autoRenewing'],
        );
      } else if (response.statusCode == 404) {
        return SubscriptionStatus(
          status: 'none',
          hasAccess: false,
        );
      } else {
        throw Exception('Failed to refresh subscription: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error refreshing subscription: $e');
    }
  }

  /// Record a new subscription purchase
  /// This is called after a successful purchase from the Play Store
  static Future<Map<String, dynamic>> recordPlaySubscription({
    required String uid,
    required String packageName,
    required String subscriptionId,
    required String purchaseToken,
    required String companyId,
    required String moduleId,
    String? payerType,
    String? payerUid,
  }) async {
    try {
      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final idToken = await user.getIdToken();
      
      final url = Uri.parse('$baseUrl/recordPlaySubscription');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'uid': uid,
          'packageName': packageName,
          'subscriptionId': subscriptionId,
          'purchaseToken': purchaseToken,
          'companyId': companyId,
          'moduleId': moduleId,
          'payerType': payerType ?? 'self',
          'payerUid': payerUid ?? uid,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to record subscription: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error recording subscription: $e');
    }
  }

  /// Health check for billing service
  static Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('https://health-e6nnsvcsrq-uc.a.run.app');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
