import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';

class HistoryDialog extends StatefulWidget {
  final String fileId;
  final String fileName;
  final DriveService driveService;

  const HistoryDialog({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.driveService,
  });

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  bool _isLoading = true;
  List<drive.Revision> _revisions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final revisions = await widget.driveService.getFileRevisions(widget.fileId);
      if (mounted) {
        setState(() {
          // Revisions come oldest to newest, standard practice is showing newest first
          _revisions = revisions.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Version History',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, 
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.fileName,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for standard dialog look
        child: _buildBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_revisions.isEmpty) {
      return Center(
        child: Text(
          'No revision history available.',
          style: TextStyle(color: AppTheme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: _revisions.length,
      itemBuilder: (context, index) {
        final rev = _revisions[index];
        final DateTime modTime = rev.modifiedTime ?? DateTime.now();
        final String user = rev.lastModifyingUser?.displayName ?? 'Unknown User';
        final String formattedDate = DateFormat.yMMMd().add_jm().format(modTime);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.backgroundColor,
            child: Text(
              '#${_revisions.length - index}',
              style: const TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
            ),
          ),
          title: Text(
            formattedDate,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Modified by $user',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondaryTextColor),
          ),
          trailing: const Icon(Icons.description_outlined, size: 16, color: Colors.grey),
        );
      },
    );
  }
}
