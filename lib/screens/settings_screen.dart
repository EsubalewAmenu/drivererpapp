import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../providers/workspace_provider.dart';

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
            enabled: false, // Workspace renaming logic pending
            style: AppTheme.inter(color: theme.textTheme.bodyLarge?.color),
            decoration: _inputDecoration('Company Name (Workspace)'),
          ),
          const SizedBox(height: 16),
          // Upload Logo is just a placeholder for now
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.3), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_rounded, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(width: 8),
                Text('Upload Logo (Coming Soon)', style: AppTheme.inter(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
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
