import 'package:drivererpapp/models/company_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../providers/drive_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final String rootFolderId;
  const OnboardingScreen({super.key, required this.rootFolderId});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  String? _choice; // 'new' or 'join'
  bool _isCreating = false;
  String _statusMessage = "Initializing...";
  double _progress = 0.0;
  
  // Form Data
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _invitationCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.iconTheme.color),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _getTitleForStep(),
          style: AppTheme.inter(
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.0, 
            fontSize: 16,
            color: theme.textTheme.titleLarge?.color
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(child: _buildStepContent(theme)),
              const SizedBox(height: 24),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitleForStep() {
    if (_currentStep == 0) return 'GET STARTED';
    if (_choice == 'join') return 'JOIN NETWORK';
    switch (_currentStep) {
      case 1: return 'IDENTITY';
      default: return '';
    }
  }

  Widget _buildStepContent(ThemeData theme) {
    if (_isCreating) return _buildProgressStep(theme);
    if (_currentStep == 0) return _buildChoiceStep(theme);
    if (_choice == 'join') return _buildJoinStep(theme);
    
    switch (_currentStep) {
      case 1: return _buildIdentityStep(theme);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildProgressStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 64),
        Text(
          'PROVISIONING WORKSPACE',
          style: AppTheme.inter(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 12,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _statusMessage,
            key: ValueKey<String>(_statusMessage),
            style: AppTheme.sourceCodePro(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: theme.cardTheme.color,
            color: theme.primaryColor,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${(_progress * 100).toInt()}% Complete',
          style: AppTheme.inter(
            color: theme.disabledColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChoiceCard(
          icon: Icons.add_business_rounded,
          title: 'Create New Company',
          subtitle: 'Start a fresh workspace with your own data.',
          onTap: () => setState(() { _choice = 'new'; _currentStep = 1; }),
          theme: theme,
        ),
        const SizedBox(height: 24),
        _buildChoiceCard(
          icon: Icons.group_add_rounded,
          title: 'Join Network',
          subtitle: 'Enter an invite code to join an existing team.',
          onTap: () => setState(() { _choice = 'join'; _currentStep = 1; }),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildChoiceCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, required ThemeData theme}) {
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.primaryColor),
              const SizedBox(height: 16),
              Text(title, style: AppTheme.inter(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: AppTheme.inter(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What is your business called?', style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Business Name',
            labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            filled: true,
            fillColor: theme.cardTheme.color,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter Invitation Code', style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 32),
        TextField(
          controller: _invitationCodeController,
          style: AppTheme.sourceCodePro(color: theme.textTheme.bodyLarge?.color, fontSize: 24, letterSpacing: 4),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'XXXX-XXXX',
            hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            filled: true,
            fillColor: theme.cardTheme.color,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    if (_currentStep == 0 || _isCreating) return const SizedBox.shrink();

    return FilledButton(
      onPressed: _isCreating ? null : () async {
        if (_choice == 'new') {
          if (_currentStep == 1 && _nameController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a business name')),
            );
            return;
          }
          // Finish Onboarding - Create Workspace
          await _createWorkspaceAndModules();
        } else {
          // Join Logic
          if (_invitationCodeController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter an invitation code')),
            );
            return;
          }
          await _joinWorkspace();
        }
      },
      style: FilledButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 60),
      ),
      child: _isCreating 
        ? SizedBox(
            height: 24, 
            width: 24, 
            child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2)
          )
        : Text(
            _currentStep == 1 || _choice == 'join' ? 'LAUNCH WORKSPACE' : 'CONTINUE',
            style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
    );
  }

  Future<void> _createWorkspaceAndModules() async {
    setState(() {
      _isCreating = true;
      _statusMessage = "Creating core workspace folder...";
      _progress = 0.1;
    });

    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) throw Exception("Not authenticated");
      
      // 1. Create Workspace Folder
      final workspaceName = _nameController.text.trim();
      final workspaceFolder = await driveService.createWorkspace(widget.rootFolderId, workspaceName);
      final workspaceId = workspaceFolder.id!;
      
      if (mounted) {
        setState(() {
          _statusMessage = "Ensuring user access folder...";
          _progress = 0.4;
        });
      }

      // Ensure user_access folder exists BEFORE registering company so it can be stored in registry.
      String? userAccessFolderId;
      try {
        userAccessFolderId = await driveService.getOrCreateSubFolder(workspaceId, 'user_access');
      } catch (e) {
        debugPrint('Failed to create user_access folder during onboarding: $e');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Initializing company in registry...";
          _progress = 0.6;
        });
      }

      // 2. Register Company in Registry (now includes user_access folder id)
      final newCompany = Company(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: workspaceName,
        folderId: workspaceId,
        userAccessFolderId: userAccessFolderId,
        role: 'Owner',
        logoUrl: '',
      );

      await Provider.of<WorkspaceProvider>(context, listen: false).registerNewCompany(
        widget.rootFolderId,
        newCompany,
      );

      // Create per-user access spreadsheet under the new company's user_access folder
      String? createdUserSpreadsheetId;
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final userEmail = authService.currentUser?.email;
        if (userEmail != null && userEmail.isNotEmpty) {
          if (mounted) {
            setState(() {
              _statusMessage = "Provisioning per-user spreadsheet...";
              _progress = 0.8;
            });
          }

          createdUserSpreadsheetId = await driveService.createUserAccessSpreadsheet(userAccessFolderId!, userEmail);
          debugPrint('Created per-user spreadsheet for new company: $createdUserSpreadsheetId');
          // Persist in provider for immediate and future use
          try {
            await Provider.of<WorkspaceProvider>(context, listen: false).saveUserAccessSpreadsheetId(createdUserSpreadsheetId);
          } catch (e) {
            debugPrint('Failed to save userAccessSpreadsheetId in provider: $e');
          }
        } else {
          debugPrint('No authenticated user email available to create per-user spreadsheet');
        }
      } catch (e) {
        debugPrint('Failed to create per-user spreadsheet during onboarding: $e');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Finalizing your workspace...";
          _progress = 1.0;
        });
      }

      // Small delay so user can see 100%
      await Future.delayed(const Duration(milliseconds: 500));

      // Set global workspace
      if (mounted) {
        final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
        workspaceProvider.setWorkspace(workspaceFolder);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(userAccessSpreadsheetId: createdUserSpreadsheetId)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating workspace: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _joinWorkspace() async {
    setState(() {
      _isCreating = true;
      _statusMessage = "Reading invitation...";
      _progress = 0.2;
    });

    try {
      final invitationCode = _invitationCodeController.text.trim();
      if (invitationCode.isEmpty) {
        throw Exception('Please enter an invitation code');
      }

      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) throw Exception("Not authenticated");

      if (mounted) {
        setState(() {
          _statusMessage = "Fetching company information...";
          _progress = 0.4;
        });
      }

      // Read company_info sheet from the invitation spreadsheet
      final response = await driveService.sheetsApi.spreadsheets.values.get(
        invitationCode,
        'company_info!A2:F2',
      );

      final values = response.values;
      if (values == null || values.isEmpty || values.first.isEmpty) {
        throw Exception('Invalid invitation code or company information not found');
      }

      final companyData = values.first;
      final companyId = companyData.isNotEmpty ? companyData[0].toString() : '';
      final companyName = companyData.length > 1 ? companyData[1].toString() : '';
      final companyFolderId = companyData.length > 2 ? companyData[2].toString() : '';
      final userAccessFolderId = companyData.length > 3 ? companyData[3].toString() : '';
      final logoUrl = companyData.length > 4 ? companyData[4].toString() : '';
      final role = companyData.length > 5 ? companyData[5].toString() : 'invited';

      if (companyId.isEmpty || companyName.isEmpty || companyFolderId.isEmpty) {
        throw Exception('Incomplete company information in invitation');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Registering to workspace...";
          _progress = 0.6;
        });
      }

      // Register company for the invited user
      final company = Company(
        id: companyId,
        name: companyName,
        folderId: companyFolderId,
        userAccessFolderId: userAccessFolderId.isNotEmpty ? userAccessFolderId : null,
        logoUrl: logoUrl.isNotEmpty ? logoUrl : null,
        role: role,
      );

      await Provider.of<WorkspaceProvider>(context, listen: false).registerNewCompany(
        widget.rootFolderId,
        company,
      );

      if (mounted) {
        setState(() {
          _statusMessage = "Setting up your access...";
          _progress = 0.8;
        });
      }

      // Save the invitation spreadsheet as the user's access spreadsheet
      try {
        await Provider.of<WorkspaceProvider>(context, listen: false).saveUserAccessSpreadsheetId(invitationCode);
      } catch (e) {
        debugPrint('Failed to save userAccessSpreadsheetId: $e');
      }

      if (mounted) {
        setState(() {
          _statusMessage = "Finalizing...";
          _progress = 1.0;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Set workspace and navigate to dashboard
      if (mounted) {
        final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
        // Load the workspace folder
        final workspaceFolder = await driveService.driveApi.files.get(
          companyFolderId,
          supportsAllDrives: true,
        ) as drive.File;
        workspaceProvider.setWorkspace(workspaceFolder);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(userAccessSpreadsheetId: invitationCode)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining workspace: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }
}
