import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'user_control/tabs/user_access_subscription_tab.dart';

class ModuleSubscriptionScreen extends StatelessWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;

  const ModuleSubscriptionScreen({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${moduleName.toUpperCase()} SUBSCRIPTION',
          style: AppTheme.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
      ),
      body: UserAccessSubscriptionTab(
        email: email,
        spreadsheetId: spreadsheetId,
        moduleId: moduleId,
        moduleName: moduleName,
        rowIndex: 0,
      ),
    );
  }
}
