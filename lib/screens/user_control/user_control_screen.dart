import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../theme/app_theme.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/drive_provider.dart';
import '../../services/drive_service.dart';
import 'user_access_management_screen.dart';

class UserControlScreen extends StatefulWidget {
  const UserControlScreen({super.key});

  @override
  State<UserControlScreen> createState() => _UserControlScreenState();
}

class _UserControlScreenState extends State<UserControlScreen> {
  List<Map<String, String>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  WorkspaceProvider? _workspaceProvider;
  DriveProvider? _driveProvider;

  @override
  void initState() {
    super.initState();
    _workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
    _driveProvider = Provider.of<DriveProvider>(context, listen: false);
    _loadUsers();
  }

  _DriveContext _getDriveContext() {
    final driveService = _driveProvider?.driveService;
    if (driveService == null) {
      throw Exception('Drive service not available');
    }

    final rootFolderId = _workspaceProvider?.rootFolderId;
    if (rootFolderId == null || rootFolderId.isEmpty) {
      throw Exception('Root folder not found');
    }

    final currentWorkspaceId = _workspaceProvider?.currentWorkspace?.id;
    if (currentWorkspaceId == null || currentWorkspaceId.isEmpty) {
      throw Exception('No workspace selected');
    }

    return _DriveContext(
      driveService: driveService,
      rootFolderId: rootFolderId,
      currentWorkspaceId: currentWorkspaceId,
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final driveContext = _getDriveContext();
      final driveService = driveContext.driveService;
      final rootFolderId = driveContext.rootFolderId;
      final currentWorkspaceId = driveContext.currentWorkspaceId;

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
        onPressed: () => _showAddUserDialog(theme),
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          'Add User',
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

    return InkWell(
      onTap: () {
        // Navigate to user access management page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserAccessManagementScreen(
              email: email,
              spreadsheetId: spreadsheetId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => _AddUserDialog(
        theme: theme,
        onUserAdded: () {
          _loadUsers();
        },
        getDriveContext: _getDriveContext,
        workspaceProvider: _workspaceProvider,
      ),
    );
  }
}

class _DriveContext {
  final DriveService driveService;
  final String rootFolderId;
  final String currentWorkspaceId;

  const _DriveContext({
    required this.driveService,
    required this.rootFolderId,
    required this.currentWorkspaceId,
  });
}

class _AddUserDialog extends StatefulWidget {
  final ThemeData theme;
  final VoidCallback onUserAdded;
  final _DriveContext Function() getDriveContext;
  final WorkspaceProvider? workspaceProvider;

  const _AddUserDialog({
    required this.theme,
    required this.onUserAdded,
    required this.getDriveContext,
    required this.workspaceProvider,
  });

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _progressMessage = '';

  // Email validation regex
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _progressMessage = 'Initializing...';
    });

    try {
      final email = _emailController.text.trim();
      final driveContext = widget.getDriveContext();
      final driveService = driveContext.driveService;
      final rootFolderId = driveContext.rootFolderId;
      final currentWorkspaceId = driveContext.currentWorkspaceId;

      // Get current workspace/company info
      final currentCompany = widget.workspaceProvider?.currentCompany;
      if (currentCompany == null) {
        throw Exception('No workspace selected');
      }

      // Step 1: Get or create user_access folder
      setState(() {
        _progressMessage = 'Setting up user folder...';
      });
      final userAccessFolderId = await driveService.getOrCreateSubFolder(
        currentWorkspaceId,
        'user_access',
      );

      // Step 2: Create user spreadsheet
      setState(() {
        _progressMessage = 'Creating user spreadsheet...';
      });
      final spreadsheetId = await driveService.createUserAccessSpreadsheet(
        userAccessFolderId,
        email,
      );

      // Step 3: Grant read access to invited user
      setState(() {
        _progressMessage = 'Granting access permissions...';
      });
      await driveService.driveApi.permissions.create(
        drive.Permission()
          ..type = 'user'
          ..role = 'reader'
          ..emailAddress = email,
        spreadsheetId,
        sendNotificationEmail: false,
        supportsAllDrives: true,
      );

      // Step 4: Populate company_info in the user's spreadsheet
      setState(() {
        _progressMessage = 'Configuring user access...';
      });
      await driveService.populateUserCompanyInfo(
        spreadsheetId,
        currentCompany.id,
        currentCompany.name,
        currentCompany.folderId,
        userAccessFolderId,
        currentCompany.logoUrl ?? '',
      );

      // Step 5: Register user in companies registry
      setState(() {
        _progressMessage = 'Finalizing setup...';
      });
      await driveService.upsertCompanyUserAccess(
        rootFolderId,
        currentWorkspaceId,
        email,
        spreadsheetId,
      );

      if (!mounted) return;

      Navigator.pop(context);
      widget.onUserAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User $email added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _progressMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.person_add,
            color: widget.theme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Add New User',
            style: AppTheme.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the email address of the user you want to invite',
                style: AppTheme.inter(
                  fontSize: 14,
                  color: widget.theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'user@example.com',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: widget.theme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.theme.dividerColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.theme.primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.red,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                enabled: !_isLoading,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _progressMessage,
                          style: AppTheme.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: widget.theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTheme.inter(
              fontWeight: FontWeight.w600,
              color: _isLoading
                  ? widget.theme.textTheme.bodyMedium?.color?.withOpacity(0.3)
                  : widget.theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.theme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: widget.theme.primaryColor.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Add User',
            style: AppTheme.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
