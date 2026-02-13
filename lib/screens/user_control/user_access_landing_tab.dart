import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class UserAccessLandingTab extends StatefulWidget {
  final String email;
  final String invitationCode; // spreadsheetId
  final String? userName;

  const UserAccessLandingTab({
    super.key,
    required this.email,
    required this.invitationCode,
    this.userName,
  });

  @override
  State<UserAccessLandingTab> createState() => _UserAccessLandingTabState();
}

class _UserAccessLandingTabState extends State<UserAccessLandingTab> {
  bool _isCodeCopied = false;

  void _copyInvitationCode() {
    Clipboard.setData(ClipboardData(text: widget.invitationCode));
    setState(() {
      _isCodeCopied = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCodeCopied = false;
        });
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invitation code copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = (widget.userName != null && widget.userName!.isNotEmpty)
        ? widget.userName!
        : 'not set';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'User Invitation',
            style: AppTheme.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this information with the user',
            style: AppTheme.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 32),

          // User Email Card
          _buildInfoCard(
            theme: theme,
            title: 'Email Address',
            value: widget.email,
            icon: Icons.email_outlined,
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.email));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Email copied to clipboard'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: theme.primaryColor,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // User Name Card
          _buildInfoCard(
            theme: theme,
            title: 'User Name',
            value: displayName,
            icon: Icons.person_outlined,
            isNotSet: displayName == 'not set',
          ),
          const SizedBox(height: 16),

          // Invitation Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.vpn_key_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Invitation Code',
                      style: AppTheme.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        widget.invitationCode,
                        style: AppTheme.sourceCodePro(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyInvitationCode,
                    icon: Icon(
                      _isCodeCopied ? Icons.check_circle : Icons.content_copy,
                      size: 22,
                    ),
                    label: Text(
                      _isCodeCopied ? 'Copied!' : 'Copy Code',
                      style: AppTheme.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to share',
                        style: AppTheme.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Share the invitation code and email with the user to grant them access to specific modules and features.',
                        style: AppTheme.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    bool isNotSet = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isNotSet ? theme.disabledColor : theme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: AppTheme.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isNotSet
                          ? theme.disabledColor
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.content_copy,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
