import 'package:drivererpapp/models/company_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  // Form Data
  final TextEditingController _nameController = TextEditingController();
  String? _selectedIndustry;
  final Set<String> _selectedModules = {};

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
      case 2: return 'INDUSTRY FOCUS';
      case 3: return 'INITIAL TOOLKIT';
      default: return '';
    }
  }

  Widget _buildStepContent(ThemeData theme) {
    if (_currentStep == 0) return _buildChoiceStep(theme);
    if (_choice == 'join') return _buildJoinStep(theme);
    
    switch (_currentStep) {
      case 1: return _buildIdentityStep(theme);
      case 2: return _buildIndustryStep(theme);
      case 3: return _buildToolkitStep(theme);
      default: return const SizedBox.shrink();
    }
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

  Widget _buildIndustryStep(ThemeData theme) {
    final industries = ['Retail', 'F&B', 'Logistics', 'Services', 'Manufacturing'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select your industry focus', style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: industries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final industry = industries[index];
              final isSelected = _selectedIndustry == industry;
              return InkWell(
                onTap: () => setState(() => _selectedIndustry = industry),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Text(industry, style: AppTheme.inter(fontSize: 18, fontWeight: FontWeight.w600, color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color)),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: theme.primaryColor),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolkitStep(ThemeData theme) {
    final modules = ['Inventory', 'CRM', 'HR', 'Finance', 'Deals'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose your initial toolkit', style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: modules.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final module = modules[index];
              final isSelected = _selectedModules.contains(module);
              return InkWell(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedModules.remove(module);
                  } else {
                    _selectedModules.add(module);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Text(module, style: AppTheme.inter(fontSize: 18, fontWeight: FontWeight.w600, color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color)),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check_box_rounded, color: theme.primaryColor)
                      else Icon(Icons.check_box_outline_blank_rounded, color: theme.textTheme.bodyMedium?.color),
                    ],
                  ),
                ),
              );
            },
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
    if (_currentStep == 0) return const SizedBox.shrink();

    return FilledButton(
      onPressed: _isCreating ? null : () async {
        if (_choice == 'new') {
          if (_currentStep < 3) {
            if (_currentStep == 1 && _nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a business name')),
              );
              return;
            }
            setState(() => _currentStep++);
          } else {
            // Finish Onboarding - Create Workspace & Modules
            await _createWorkspaceAndModules();
          }
        } else {
          // Join Logic
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
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
            _currentStep == 3 || _choice == 'join' ? 'LAUNCH WORKSPACE' : 'CONTINUE',
            style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
    );
  }

  Future<void> _createWorkspaceAndModules() async {
    setState(() => _isCreating = true);
    try {
      final driveService = Provider.of<DriveProvider>(context, listen: false).driveService;
      if (driveService == null) throw Exception("Not authenticated");
      
      // 1. Create Workspace Folder
      final workspaceName = _nameController.text.trim();
      final workspaceFolder = await driveService.createWorkspace(widget.rootFolderId, workspaceName);
      final workspaceId = workspaceFolder.id!;
      
      // 2. Create Module Folders
      for (final module in _selectedModules) {
        await driveService.createWorkspace(workspaceId, module);
      }
      
      // 3. Register Company in Registry
      final newCompany = Company(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: workspaceName,
        folderId: workspaceId,
        role: 'Owner',
        logoUrl: '',
      );

      await Provider.of<WorkspaceProvider>(context, listen: false).registerNewCompany(
        widget.rootFolderId, 
        newCompany
      );

      // Create per-user access spreadsheet under the new company's user_access folder
      String? createdUserSpreadsheetId;
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final userEmail = authService.currentUser?.email;
        if (userEmail != null && userEmail.isNotEmpty) {
          final userAccessFolderId = await driveService.getOrCreateSubFolder(workspaceId, 'user_access');
          createdUserSpreadsheetId = await driveService.ensureUserAccessSpreadsheet(userAccessFolderId, userEmail);
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
}
