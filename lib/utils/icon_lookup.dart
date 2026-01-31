import 'package:flutter/material.dart';

// Centralized icon lookup. Keeps mapping in one place so asset JSONs can
// provide icon names and code doesn't replicate switch statements.
IconData iconFromName(String? name) {
  const iconMap = <String, IconData>{
    'inventory': Icons.inventory_2_rounded,
    'people': Icons.people_alt_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'local_shipping': Icons.local_shipping_rounded,
    'payments': Icons.payments_rounded,
    'badge': Icons.badge_rounded,
    'campaign': Icons.campaign_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'assignment': Icons.assignment_rounded,
    'account_balance': Icons.account_balance_rounded,
    'analytics': Icons.analytics_rounded,
    'support_agent': Icons.support_agent_rounded,
  };
  if (name == null) return Icons.widgets_rounded;
  return iconMap[name] ?? Icons.widgets_rounded;
}

