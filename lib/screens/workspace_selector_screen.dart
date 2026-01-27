import 'package:drivererpapp/models/company_model.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/drive_provider.dart';
import '../theme/app_theme.dart';
import '../providers/workspace_provider.dart';
import 'dashboard_screen.dart';
import 'onboarding/onboarding_screen.dart';

class WorkspaceSelectorScreen extends StatefulWidget {
  final String rootFolderId;

  const WorkspaceSelectorScreen({
    super.key, 
    required this.rootFolderId,
  });

  @override
  State<WorkspaceSelectorScreen> createState() => _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends State<WorkspaceSelectorScreen> {
  
  @override
  void initState() {
    super.initState();
    // Load companies registry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceProvider>().loadCompanies(widget.rootFolderId);
    });
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<WorkspaceProvider>().loadCompanies(widget.rootFolderId),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<WorkspaceProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final companies = provider.companies;

              return Column(
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
                    child: companies.isEmpty 
                    ? Center(
                        child: Text(
                          'No workspaces found.\nCreate one to get started.',
                          textAlign: TextAlign.center,
                          style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color),
                        ),
                      )
                    : ListView.separated(
                      itemCount: companies.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        return _buildCompanyCard(context, company);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => OnboardingScreen(rootFolderId: widget.rootFolderId)),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text('CREATE NEW WORKSPACE', style: AppTheme.inter(fontWeight: FontWeight.w700)),
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, Company company) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () async {
          debugPrint('WorkspaceSelector: tapped company ${company.name} (${company.folderId})');
          // Construct a drive.File object from the company info to keep compatibility
          final workspaceFile = drive.File()
            ..id = company.folderId
            ..name = company.name;

          // Set global workspace
          debugPrint('WorkspaceSelector: setting workspace in provider');
          Provider.of<WorkspaceProvider>(context, listen: false).setWorkspace(workspaceFile);

          // Note: userAccessSpreadsheetId should ALWAYS be read from the companies registry
          // (user_access sheet). Do NOT create user access spreadsheets here.
          String? userAccessSpreadsheetId;
          final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
          final auth = Provider.of<AuthService>(context, listen: false);
          final userEmail = auth.currentUser?.email;

          debugPrint('WorkspaceSelector: resolving userAccessSpreadsheetId from registry for user=$userEmail');
          if (driveService != null && widget.rootFolderId.isNotEmpty && userEmail != null) {
            try {
              final registryId = await driveService.getFileId(widget.rootFolderId, 'companies');
              debugPrint('WorkspaceSelector: registryId=$registryId');
              if (registryId != null) {
                final resp = await driveService.sheetsApi.spreadsheets.values.get(registryId, 'user_access!A2:C');
                final rows = resp.values ?? [];
                debugPrint('WorkspaceSelector: registry user_access rows=${rows.length}');
                for (var r in rows) {
                  if (r.length >= 3 && r[0] == company.folderId && r[1] == userEmail) {
                    userAccessSpreadsheetId = r[2] as String;
                    debugPrint('WorkspaceSelector: found userAccessSpreadsheetId=$userAccessSpreadsheetId in registry');
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint('Error reading registry user_access: $e');
            }
          } else {
            debugPrint('WorkspaceSelector: driveService or userEmail missing (driveService=$driveService, userEmail=$userEmail)');
          }

          // Cache the per-user user_access spreadsheet id for future sessions
          try {
            debugPrint('WorkspaceSelector: caching userAccessSpreadsheetId=$userAccessSpreadsheetId');
            Provider.of<WorkspaceProvider>(context, listen: false).saveUserAccessSpreadsheetId(userAccessSpreadsheetId);
          } catch (e) {
            debugPrint('Error caching userAccessSpreadsheetId: $e');
          }

          // Boot into workspace and pass spreadsheet id to DashboardScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(userAccessSpreadsheetId: userAccessSpreadsheetId)),
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
                  image: company.logoUrl != null && company.logoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(company.logoUrl!), // In real app, handle auth for Drive images
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: company.logoUrl == null || company.logoUrl!.isEmpty
                  ? Center(
                      child: Text(
                        (company.name.isNotEmpty ? company.name[0] : 'U').toUpperCase(),
                        style: AppTheme.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: AppTheme.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${company.role ?? "Member"}',
                      style: AppTheme.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}
