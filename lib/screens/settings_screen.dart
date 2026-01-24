import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/company_model.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../providers/workspace_provider.dart';
import '../providers/drive_provider.dart';
import 'workspace_selector_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadWorkspaceData();
  }

  void _loadUserData() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser != null) {
      _displayNameController.text = auth.currentUser!.displayName ?? '';
    }
  }

  void _loadWorkspaceData() {
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    if (workspace.currentWorkspace != null) {
      _companyNameController.text = workspace.currentWorkspace!.name ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: theme.textTheme.titleLarge?.color)),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PERSONAL PROFILE'),
            const SizedBox(height: 16),
            _buildProfileCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('COMPANY BRANDING'),
            const SizedBox(height: 16),
            _buildCompanyCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('APPEARANCE'),
            const SizedBox(height: 16),
            _buildAppearanceCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('STORAGE'),
            const SizedBox(height: 16),
            _buildStorageCard(),
            const SizedBox(height: 32),
            _buildSectionHeader('SESSION INFO'),
            const SizedBox(height: 16),
            _buildSessionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.bodyMedium?.color, 
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final initials = user?.displayName != null && user!.displayName!.isNotEmpty
        ? user.displayName!.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.primaryColor,
                backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                child: user?.photoUrl == null
                    ? Text(initials, style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'Guest User', style: AppTheme.inter(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                    Text(user?.email ?? 'No Email', style: AppTheme.inter(fontSize: 14, color: theme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _displayNameController,
            enabled: false, // Google Profile is read-only for now
            style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
            decoration: _inputDecoration('Display Name (Google Account)'),
          ),
          const SizedBox(height: 16),
          // Removed Save Button for Profile as it is read-only from Google
        ],
      ),
    );
  }
  
  Widget _buildAppearanceCard() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: theme.primaryColor
                  ),
                  const SizedBox(width: 16),
                  Text('Dark Mode', style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
              Switch(
                value: themeProvider.isDarkMode,
                activeThumbColor: theme.primaryColor,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard() {
    final theme = Theme.of(context);
    final workspaceProvider = Provider.of<WorkspaceProvider>(context);
    final driveProvider = Provider.of<DriveProvider>(context, listen: false);
    final driveService = driveProvider.driveService;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          TextField(
            controller: _companyNameController,
            enabled: !workspaceProvider.isLoading,
            style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
            decoration: _inputDecoration('Company Name (Workspace)'),
          ),
          const SizedBox(height: 24),
          if (workspaceProvider.isLoading)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCompanyName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('SAVE CHANGES', style: AppTheme.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 24),
          // Upload Logo Section
          InkWell(
            onTap: workspaceProvider.isLoading ? null : _pickAndUploadLogo,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3), 
                  style: BorderStyle.solid
                ),
                borderRadius: BorderRadius.circular(12),
                color: theme.primaryColor.withValues(alpha: 0.05),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: theme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'REPLACE COMPANY LOGO', 
                    style: AppTheme.inter(
                      color: theme.primaryColor, 
                      fontWeight: FontWeight.w700, 
                      fontSize: 13,
                      letterSpacing: 0.5
                    )
                  ),
                ],
              ),
            ),
          ),
          if (workspaceProvider.currentWorkspace != null) ...[
            const SizedBox(height: 16),
            Consumer<WorkspaceProvider>(
              builder: (context, wp, _) {
                if (wp.companies.isEmpty || wp.currentWorkspace == null) {
                  return const SizedBox.shrink();
                }

                Company? company;
                try {
                  company = wp.companies.firstWhere((c) => c.folderId == wp.currentWorkspace!.id);
                } catch (_) {
                  company = null;
                }

                if (company == null) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: workspaceProvider.isLoading || driveService == null ? null : () async {
                              final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                                title: const Text('Deactivate Company'),
                                content: const Text('Deactivating the company will hide it for users. This does not delete data. Continue?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DEACTIVATE')),
                                ],
                              ));
                              if (confirm != true) return;
                              try {
                                final workspaceId = workspaceProvider.currentWorkspace?.id;
                                if (workspaceId == null) throw Exception('No workspace');
                                final rootFolderId = workspaceProvider.rootFolderId ?? await driveService.checkRootFolder();
                                if (rootFolderId == null) throw Exception('Root folder id missing');
                                await driveService.setCompanyStatus(rootFolderId, workspaceId, 'deactivated');
                                  // Clear current workspace and navigate back to selector to avoid 404s
                                  workspaceProvider.clearWorkspace();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company deactivated')));
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (_) => WorkspaceSelectorScreen(rootFolderId: rootFolderId)),
                                      (route) => false,
                                    );
                                  }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to deactivate company: $e')));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('DEACTIVATE COMPANY', style: AppTheme.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: workspaceProvider.isLoading || driveService == null ? null : () async {
                              final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                                title: const Text('Terminate Company'),
                                content: const Text('Terminating will delete the company folder and remove registry entries. This is irreversible. Continue?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('TERMINATE')),
                                ],
                              ));
                              if (confirm != true) return;
                              try {
                                final workspaceId = workspaceProvider.currentWorkspace?.id;
                                if (workspaceId == null) throw Exception('No workspace');
                                final rootFolderId = workspaceProvider.rootFolderId ?? await driveService.checkRootFolder();
                                if (rootFolderId == null) throw Exception('Root folder id missing');
                                await driveService.terminateCompany(rootFolderId, workspaceId);
                                // Clear workspace and navigate back to selector to avoid stale state
                                workspaceProvider.clearWorkspace();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company terminated')));
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => WorkspaceSelectorScreen(rootFolderId: rootFolderId)),
                                    (route) => false,
                                  );
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to terminate company: $e')));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('TERMINATE COMPANY', style: AppTheme.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    if (company.logoUrl != null && company.logoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          company.logoUrl!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            color: theme.scaffoldBackgroundColor,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final extension = image.path.split('.').last.toLowerCase();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading new logo...'), duration: Duration(seconds: 2)),
      );

      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      await workspaceProvider.updateCompanyLogo(bytes, extension);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e')),
        );
      }
    }
  }

  Future<void> _saveCompanyName() async {
    final newName = _companyNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name cannot be empty.')));
      return;
    }

    try {
      final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
      await workspaceProvider.updateCompanyName(newName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name updated successfully!')));
        // Unfocus to hide keyboard
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update company name: $e')));
      }
    }
  }

  Widget _buildStorageCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(
                'MANAGE CACHE',
                style: AppTheme.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cached_rounded, color: theme.textTheme.bodyMedium?.color),
            title: Text('Clear Module Blueprints', style: AppTheme.inter(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
            subtitle: Text('Force reload all tools from Drive', style: AppTheme.inter(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _clearCache,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('module_config_') || k.startsWith('module_meta_')).toList();
    
    if (!mounted) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: Text('This will clear the cached blueprints for ${keys.length ~/ 2} modules. They will be re-downloaded next time you open them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR')),
        ],
      ),
    );

    if (confirm == true) {
      for (final key in keys) {
        await prefs.remove(key);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared successfully.')));
      }
    }
  }

  Widget _buildSessionInfo() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Role', 'Owner / Admin'),
          Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildInfoRow('Session ID', 'sess_8f92k...'),
          Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
          _buildInfoRow('Last Login', 'Today, 09:41 AM'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color)),
          Text(value, style: AppTheme.sourceCodePro(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor),
      ),
      filled: true,
      fillColor: theme.scaffoldBackgroundColor,
    );
  }
}
