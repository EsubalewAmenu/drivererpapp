import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class UserAccessDashboardTab extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const UserAccessDashboardTab({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<UserAccessDashboardTab> createState() => _UserAccessDashboardTabState();
}

class _UserAccessDashboardTabState extends State<UserAccessDashboardTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Dashboard Editor',
              style: AppTheme.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: AppTheme.inter(
                fontSize: 14,
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get hasChanges => false;
  bool get isSaving => false;

  Future<void> saveChanges() async {
    // Placeholder for future implementation
  }
}
