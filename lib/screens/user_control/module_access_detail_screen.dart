import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'tabs/user_access_permissions_tab.dart';
import 'tabs/user_access_structure_tab.dart';
import 'tabs/user_access_dashboard_tab.dart';
import 'tabs/user_access_settings_tab.dart';

class ModuleAccessDetailScreen extends StatefulWidget {
  final String email;
  final String spreadsheetId;
  final String moduleId;
  final String moduleName;
  final int rowIndex;

  const ModuleAccessDetailScreen({
    super.key,
    required this.email,
    required this.spreadsheetId,
    required this.moduleId,
    required this.moduleName,
    required this.rowIndex,
  });

  @override
  State<ModuleAccessDetailScreen> createState() => _ModuleAccessDetailScreenState();
}

class _ModuleAccessDetailScreenState extends State<ModuleAccessDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.moduleName.toUpperCase(),
          style: AppTheme.inter(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          indicatorColor: theme.primaryColor,
          labelStyle: AppTheme.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: AppTheme.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'PERMISSIONS'),
            Tab(text: 'STRUCTURE'),
            Tab(text: 'DASHBOARD'),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UserAccessPermissionsTab(
            email: widget.email,
            spreadsheetId: widget.spreadsheetId,
            moduleId: widget.moduleId,
            moduleName: widget.moduleName,
            rowIndex: widget.rowIndex,
          ),
          UserAccessStructureTab(
            email: widget.email,
            spreadsheetId: widget.spreadsheetId,
            moduleId: widget.moduleId,
            moduleName: widget.moduleName,
            rowIndex: widget.rowIndex,
          ),
          UserAccessDashboardTab(
            email: widget.email,
            spreadsheetId: widget.spreadsheetId,
            moduleId: widget.moduleId,
            moduleName: widget.moduleName,
            rowIndex: widget.rowIndex,
          ),
          UserAccessSettingsTab(
            email: widget.email,
            spreadsheetId: widget.spreadsheetId,
            moduleId: widget.moduleId,
            moduleName: widget.moduleName,
            rowIndex: widget.rowIndex,
          ),
        ],
      ),
    );
  }
}
