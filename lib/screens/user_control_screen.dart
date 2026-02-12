import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/workspace_provider.dart';
import '../providers/drive_provider.dart';

class UserControlScreen extends StatefulWidget {
  const UserControlScreen({super.key});

  @override
  State<UserControlScreen> createState() => _UserControlScreenState();
}

class _UserControlScreenState extends State<UserControlScreen> {
  List<Map<String, String>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      final driveProvider = Provider.of<DriveProvider>(context, listen: false);

      final driveService = driveProvider.driveService;
      if (driveService == null) {
        throw Exception('Drive service not available');
      }

      final rootFolderId = workspaceProvider.rootFolderId;
      if (rootFolderId == null || rootFolderId.isEmpty) {
        throw Exception('Root folder not found');
      }

      final currentWorkspaceId = workspaceProvider.currentWorkspace?.id;
      if (currentWorkspaceId == null || currentWorkspaceId.isEmpty) {
        throw Exception('No workspace selected');
      }

      // Get companies registry ID directly
      final companiesRegistryId = await driveService.ensureCompanyRegistry(rootFolderId);

      // Read all rows from user_access sheet in companies registry
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        companiesRegistryId,
        'user_access!A:C', // company_folder_id, email, spreadsheet_id
      );

      final values = response.values ?? [];
      if (values.isEmpty) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
        return;
      }

      // Skip header row and filter by company_folder_id
      final userRows = values.skip(1).where((row) {
        if (row.isEmpty) return false;
        final companyFolderId = row[0].toString();
        return companyFolderId == currentWorkspaceId;
      }).toList();

      // Map to user list
      final users = userRows.map((row) {
        return {
          'email': row.length > 1 ? row[1].toString() : '',
          'spreadsheetId': row.length > 2 ? row[2].toString() : '',
        };
      }).toList();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'USER CONTROL',
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
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement invite user functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite user feature coming soon')),
          );
        },
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          'Invite User',
          style: AppTheme.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                'Failed to load users',
                style: AppTheme.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTheme.inter(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: AppTheme.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite users to collaborate on this workspace',
              style: AppTheme.inter(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user, theme);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, String> user, ThemeData theme) {
    final email = user['email'] ?? '';
    final spreadsheetId = user['spreadsheetId'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: AppTheme.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: AppTheme.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (spreadsheetId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${spreadsheetId.substring(0, spreadsheetId.length > 20 ? 20 : spreadsheetId.length)}...',
                    style: AppTheme.inter(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.textTheme.bodyMedium?.color),
            onSelected: (value) {
              if (value == 'manage') {
                // TODO: Navigate to manage user access
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manage access feature coming soon')),
                );
              } else if (value == 'remove') {
                // TODO: Remove user access
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Remove user feature coming soon')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Manage Access'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Remove User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
