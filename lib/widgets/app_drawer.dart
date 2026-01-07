import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../providers/workspace_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/system_scanning_screen.dart';
import '../screens/landing_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.cardTheme.color,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildWorkspaceSwitcher(context),
            const SizedBox(height: 32),
            _buildNavigationLinks(context),
            const Spacer(),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.grid_view_rounded, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            'DRIVE ERP',
            style: AppTheme.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSwitcher(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context).currentWorkspace;
    final workspaceName = workspace?.name ?? 'Select Workspace';
    final initial = workspaceName.isNotEmpty ? workspaceName[0].toUpperCase() : '?';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: () {
            // Navigate to system scanning to refresh workspaces, skipping auto-restore
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SystemScanningScreen(autoRestore: false)),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blueGrey,
                child: Text(initial, style: AppTheme.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspaceName, style: AppTheme.inter(fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                    Text('Switch Workspace', style: AppTheme.inter(fontSize: 10, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz_rounded, color: theme.textTheme.bodyMedium?.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationLinks(BuildContext context) {
    return Column(
      children: [
        _buildNavItem(context, Icons.dashboard_rounded, 'Dashboard', onTap: () {
          Navigator.pop(context); // Close drawer
        }),
        _buildNavItem(context, Icons.settings_rounded, 'Settings', onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, {required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.textTheme.bodyMedium?.color),
      title: Text(
        label,
        style: AppTheme.inter(
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 0,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)), // Rose color
            title: Text(
              'Log Out',
              style: AppTheme.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF43F5E),
              ),
            ),
            onTap: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
