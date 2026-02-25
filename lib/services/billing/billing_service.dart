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
  final String? subscriptionId; // 'subscription.monthly' or 'subscription.annual'
  final String? purchaseToken;
  final DateTime? lastVerifiedAt;

  SubscriptionStatus({
    required this.status,
    required this.hasAccess,
    this.renewalDate,
    this.autoRenewing,
    this.payerType,
    this.source,
    this.subscriptionId,
    this.purchaseToken,
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
      subscriptionId: json['subscriptionId'],
      purchaseToken: json['purchaseToken'],
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

  /// Get pricing for a module and whether it is free
  static Future<Map<String, dynamic>> getModulePricing({
    required String moduleName,
    String? moduleId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/getModulePricing');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'moduleName': moduleName,
          'moduleId': moduleId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get module pricing: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching module pricing: $e');
    }
  }

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
    required String uid,
    required String companyId,
    required String moduleId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/refreshPlaySubscription');
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

  /// Disable auto-renew for a subscription
  static Future<SubscriptionStatus> disableAutoRenew({
    required String uid,
    required String companyId,
    required String moduleId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/disablePlayAutoRenew');
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
        final data = jsonDecode(response.body);
        return SubscriptionStatus(
          status: data['status'] ?? 'unknown',
          hasAccess: data['status'] == 'active',
          renewalDate:
              data['expiryTime'] != null ? DateTime.parse(data['expiryTime']) : null,
          autoRenewing: data['autoRenewing'],
        );
      } else {
        throw Exception('Failed to disable auto-renew: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error disabling auto-renew: $e');
    }
  }

  /// Enable auto-renew for a subscription
  static Future<SubscriptionStatus> enableAutoRenew({
    required String uid,
    required String companyId,
    required String moduleId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/enablePlayAutoRenew');
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
        final data = jsonDecode(response.body);
        return SubscriptionStatus(
          status: data['status'] ?? 'unknown',
          hasAccess: data['status'] == 'active',
          renewalDate:
              data['expiryTime'] != null ? DateTime.parse(data['expiryTime']) : null,
          autoRenewing: data['autoRenewing'],
        );
      } else {
        throw Exception('Failed to enable auto-renew: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error enabling auto-renew: $e');
    }
  }

  /// Manually renew a subscription (one-time renewal using credits)
  static Future<SubscriptionStatus> manualRenewSubscription({
    required String uid,
    required String companyId,
    required String moduleId,
    String? moduleName,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/manualRenewSubscription');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'companyId': companyId,
          'moduleId': moduleId,
          'moduleName': moduleName,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SubscriptionStatus(
          status: data['status'] ?? 'unknown',
          hasAccess: data['status'] == 'active',
          renewalDate:
              data['expiryTime'] != null ? DateTime.parse(data['expiryTime']) : null,
          autoRenewing: data['autoRenewing'],
        );
      } else {
        String errorMessage = response.body;
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map<String, dynamic> && parsed['message'] != null) {
            errorMessage = parsed['message'].toString();
          }
        } catch (_) {}
        throw Exception('Failed to manually renew subscription: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      throw Exception('Error manually renewing subscription: $e');
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
    required String moduleName,
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
          'moduleName': moduleName,
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
