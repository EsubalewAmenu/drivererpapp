import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/workspace_provider.dart';
import 'dashboard_screen.dart';
import 'onboarding/onboarding_screen.dart';

class WorkspaceSelectorScreen extends StatelessWidget {
  final List<drive.File> workspaces;
  final String rootFolderId;

  const WorkspaceSelectorScreen({
    super.key, 
    required this.workspaces,
    required this.rootFolderId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'SELECT WORKSPACE', 
          style: AppTheme.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0, 
            color: theme.textTheme.titleLarge?.color
          )
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AVAILABLE ENVIRONMENTS',
                style: AppTheme.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: workspaces.isEmpty 
                ? Center(
                    child: Text(
                      'No workspaces found.\nCreate one to get started.',
                      textAlign: TextAlign.center,
                      style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
                    ),
                  )
                : ListView.separated(
                  itemCount: workspaces.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final workspace = workspaces[index];
                    return _buildWorkspaceCard(context, workspace);
                  },
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OnboardingScreen(rootFolderId: rootFolderId)),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('CREATE OR JOIN NEW WORKSPACE', style: AppTheme.inter(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.cardTheme.color,
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(BuildContext context, drive.File workspace) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () {
          // Set global workspace
          Provider.of<WorkspaceProvider>(context, listen: false).setWorkspace(workspace);
          
          // Boot into workspace
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (workspace.name ?? 'U')[0].toUpperCase(),
                    style: AppTheme.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name ?? 'Unnamed Workspace',
                      style: AppTheme.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${workspace.id}',
                      style: AppTheme.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodySmall?.color,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.secondaryTextColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
