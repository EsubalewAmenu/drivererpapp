import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class WorkspaceCredits {
  final double balance; // Total credits available
  final List<TopupTransaction> topupHistory;
  final bool autoTopupEnabled;
  final int? autoTopupAmount; // Credits to auto-topup monthly
  final DateTime? lastAutoTopupDate;

  WorkspaceCredits({
    required this.balance,
    required this.topupHistory,
    required this.autoTopupEnabled,
    this.autoTopupAmount,
    this.lastAutoTopupDate,
  });

  factory WorkspaceCredits.fromJson(Map<String, dynamic> json) {
    return WorkspaceCredits(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      topupHistory: ((json['topupHistory'] as List?) ?? [])
          .map((item) => TopupTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
      autoTopupEnabled: json['autoTopupEnabled'] ?? false,
      autoTopupAmount: json['autoTopupAmount'],
      lastAutoTopupDate: json['lastAutoTopupDate'] != null
          ? DateTime.parse(json['lastAutoTopupDate'] as String)
          : null,
    );
  }
}

class TopupTransaction {
  final double amount; // Amount in USD
  final int credits; // Credits purchased
  final DateTime date;
  final String type; // 'manual', 'auto'

  TopupTransaction({
    required this.amount,
    required this.credits,
    required this.date,
    required this.type,
  });

  factory TopupTransaction.fromJson(Map<String, dynamic> json) {
    return TopupTransaction(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      type: json['type'] ?? 'manual',
    );
  }
}

class CreditsService {
  static const String baseUrl = 'https://us-central1-driveerp-1d5d5.cloudfunctions.net';
  static const double creditPrice = 0.01; // $0.01 per credit

  /// Get current workspace credits and topup history
  static Future<WorkspaceCredits> getWorkspaceCredits({
    required String companyId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/getWorkspaceCredits');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'companyId': companyId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return WorkspaceCredits.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        // No credits record yet
        return WorkspaceCredits(
          balance: 0.0,
          topupHistory: [],
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
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('$baseUrl/topupWorkspaceCredits');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'companyId': companyId,
          'credits': credits,
        }),
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
