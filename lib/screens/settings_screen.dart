import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _displayNameController = TextEditingController(text: "Alex Chen");
  final TextEditingController _companyNameController = TextEditingController(text: "Acme Corp");
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTheme.inter(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
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
        color: AppTheme.secondaryTextColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primaryColor,
                child: Text('AC', style: AppTheme.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alex Chen', style: AppTheme.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                    Text('Administrator', style: AppTheme.inter(fontSize: 14, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _displayNameController,
            style: AppTheme.inter(color: AppTheme.textColor),
            decoration: _inputDecoration('Display Name'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE CHANGES', style: AppTheme.inter(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          TextField(
            controller: _companyNameController,
            style: AppTheme.inter(color: AppTheme.textColor),
            decoration: _inputDecoration('Company Name'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.3), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_rounded, color: AppTheme.secondaryTextColor),
                const SizedBox(width: 8),
                Text('Upload Logo', style: AppTheme.inter(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.secondaryTextColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Role', 'Owner / Admin'),
          const Divider(color: Colors.white10),
          _buildInfoRow('Session ID', 'sess_8f92k...'),
          const Divider(color: Colors.white10),
          _buildInfoRow('Last Login', 'Today, 09:41 AM'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.inter(color: AppTheme.secondaryTextColor)),
          Text(value, style: AppTheme.sourceCodePro(color: AppTheme.textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.secondaryTextColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.secondaryTextColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      filled: true,
      fillColor: AppTheme.backgroundColor,
    );
  }
}
