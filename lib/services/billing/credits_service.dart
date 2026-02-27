import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class WorkspaceCredits {
  final double balance; // Total credits available
  final List<CreditTransaction> transactionHistory;
  final bool autoTopupEnabled;
  final int? autoTopupAmount; // Credits to auto-topup monthly
  final DateTime? lastAutoTopupDate;

  WorkspaceCredits({
    required this.balance,
    required this.transactionHistory,
    required this.autoTopupEnabled,
    this.autoTopupAmount,
    this.lastAutoTopupDate,
  });

  factory WorkspaceCredits.fromJson(Map<String, dynamic> json) {
    return WorkspaceCredits(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      transactionHistory: ((json['transactionHistory'] as List?) ?? [])
          .map((item) => CreditTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
      autoTopupEnabled: json['autoTopupEnabled'] ?? false,
      autoTopupAmount: json['autoTopupAmount'],
      lastAutoTopupDate: json['lastAutoTopupDate'] != null
          ? DateTime.parse(json['lastAutoTopupDate'] as String)
          : null,
    );
  }
}

class CreditTransaction {
  final double amount; // Amount in USD (negative for deductions)
  final int credits; // Credits added or deducted (negative for deductions)
  final DateTime date;
  final String type; // 'topup', 'subscription', 'auto'
  final String? moduleId;
  final String? moduleName;
  final String? subscriptionId;
  final String? uid;
  final String? userEmail;
  final String? renewalSource; // 'subscription', 'auto', 'manual'
  final String? platform; // 'google_play', 'apple', 'stripe', etc.
  final String? purchaseId; // Transaction/purchase token

  CreditTransaction({
    required this.amount,
    required this.credits,
    required this.date,
    required this.type,
    this.moduleId,
    this.moduleName,
    this.subscriptionId,
    this.uid,
    this.userEmail,
    this.renewalSource,
    this.platform,
    this.purchaseId,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      type: json['type'] ?? 'topup',
      moduleId: json['moduleId'],
      moduleName: json['moduleName'],
      subscriptionId: json['subscriptionId'],
      uid: json['uid'],
      userEmail: json['userEmail'],
      renewalSource: json['renewalSource'],
      platform: json['platform'],
      purchaseId: json['purchaseId'],
    );
  }

  bool get isDeduction => credits < 0;
  bool get isTopup => credits > 0;
}

class CreditsService {
  static const String baseUrl = 'https://us-central1-driveerp-1d5d5.cloudfunctions.net';
  static const double creditPrice = 0.01; // $0.01 per credit

  /// Get current workspace credits and topup history
  static Future<WorkspaceCredits> getWorkspaceCredits({
    required String companyId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$baseUrl/getWorkspaceCredits');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'companyId': companyId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return WorkspaceCredits.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        // No credits record yet
        return WorkspaceCredits(
          balance: 0.0,
          transactionHistory: [],
          autoTopupEnabled: false,
        );
      } else {
        throw Exception('Failed to get credits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching credits: $e');
    }
  }

  /// Topup credits for workspace (manual purchase)
  static Future<WorkspaceCredits> topupCredits({
    required String companyId,
    required int credits,
    String? platform, // 'google_play', 'apple', 'stripe', etc.
    String? purchaseId, // Transaction ID from payment platform
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$baseUrl/topupWorkspaceCredits');
      final body = {
        'companyId': companyId,
        'credits': credits,
      };
      
      if (platform != null) {
        body['platform'] = platform;
      }
      if (purchaseId != null) {
        body['purchaseId'] = purchaseId;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return WorkspaceCredits.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to topup credits: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error topping up credits: $e');
    }
  }

  /// Enable/disable auto-topup
  static Future<WorkspaceCredits> setAutoTopup({
    required String companyId,
    required bool enabled,
    int? amount,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$baseUrl/setAutoTopup');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'companyId': companyId,
          'enabled': enabled,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return WorkspaceCredits.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to set auto-topup: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error setting auto-topup: $e');
    }
  }

  /// Calculate cost in credits for a module subscription
  static int calculateModuleCost({
    required String planType, // 'daily', 'monthly', 'annual'
    double modulePrice = 1.0, // Price in USD, default $1
  }) {
    // Convert USD price to credits (1 credit = $0.01)
    final creditsNeeded = (modulePrice / creditPrice).ceil();
    return creditsNeeded;
  }

  /// Format credits as USD for display
  static String creditsToUsd(int credits) {
    final usd = credits * creditPrice;
    return '\$${usd.toStringAsFixed(2)}';
  }

  /// Format USD to credits for display
  static String usdToCredits(double usd) {
    final credits = (usd / creditPrice).toInt();
    return '$credits credits';
  }
}
