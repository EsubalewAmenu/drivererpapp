import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import '../../services/drive_service.dart';
import '../../theme/app_theme.dart';

class HistoryDialog extends StatefulWidget {
  final String moduleId;
  final String moduleName;
  final DriveService driveService;

  const HistoryDialog({
    super.key,
    required this.moduleId,
    required this.moduleName,
    required this.driveService,
  });

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class RevisionSession {
  final drive.Revision main;
  final List<drive.Revision> subs;
  RevisionSession(this.main, this.subs);
}

class _HistoryDialogState extends State<HistoryDialog> {
  bool _isLoading = true;
  List<drive.Revision> _revisions = [];
  Map<String, List<RevisionSession>> _groupedSessions = {}; // Changed to hold sessions
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      // 1. Find the data spreadsheet first
      final fileId = await widget.driveService.getFileId(widget.moduleId, widget.moduleName);
      
      if (fileId == null) {
        throw Exception('Data spreadsheet not found');
      }

      // 2. Load history
      final revisions = await widget.driveService.getFileRevisions(fileId);
      final sortedRevisions = revisions.reversed.toList(); // Newest first

      // 3. Flatten revisions (No grouping)
      // User requested to see every individual revision without clustering/grouping.
      final sessions = sortedRevisions.map((rev) => RevisionSession(rev, [])).toList();

      // 4. Group Sessions by Day
      final grouped = <String, List<RevisionSession>>{};
      for (var session in sessions) {
        final date = session.main.modifiedTime?.toLocal() ?? DateTime.now();
        final now = DateTime.now();
        
        String key;
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          key = 'Today';
        } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
          key = 'Yesterday';
        } else {
          key = DateFormat.yMMMd().format(date);
        }
        
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(session);
      }

      if (mounted) {
        setState(() {
          _revisions = sortedRevisions;
          _groupedSessions = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load sheet history: $e';
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
                  'Spreadsheet Version History',
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
            '${widget.moduleName} (Includes all tabs)',
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
      return const Center(
        child: Text(
          'No revision history available.',
          style: TextStyle(color: AppTheme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: _groupedSessions.keys.length,
      itemBuilder: (context, index) {
        final key = _groupedSessions.keys.elementAt(index);
        final dateSessions = _groupedSessions[key]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                key.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
            ...dateSessions.map((session) {
              return _buildSessionTile(session);
            }),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildSessionTile(RevisionSession session) {
    final DateTime modTime = session.main.modifiedTime?.toLocal() ?? DateTime.now();
    final String user = session.main.lastModifyingUser?.displayName ?? 'Unknown User';
    final String time = DateFormat.jm().format(modTime);
    final String versionLabel = 'V${_revisions.length - _revisions.indexOf(session.main)}';

    if (session.subs.isEmpty) {
      return ListTile(
        leading: _buildVersionBadge(versionLabel),
        title: Text(time, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('Modified by $user', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondaryTextColor)),
        dense: true,
      );
    }

    return ExpansionTile(
      leading: _buildVersionBadge(versionLabel),
      title: Text(time, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('Modified by $user • ${session.subs.length + 1} versions', 
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.secondaryTextColor)),
      children: session.subs.map((sub) {
        final subTime = DateFormat.jm().format(sub.modifiedTime?.toLocal() ?? DateTime.now());
        final subVersion = 'V${_revisions.length - _revisions.indexOf(sub)}';
        
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          leading: Container(
             width: 8, height: 8, 
             decoration: const BoxDecoration(color: AppTheme.secondaryTextColor, shape: BoxShape.circle)
          ),
          title: Text(subTime, style: GoogleFonts.inter(fontSize: 13)),
          trailing: Text(subVersion, style: GoogleFonts.sourceCodePro(fontSize: 10, color: AppTheme.secondaryTextColor)),
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _buildVersionBadge(String label) {
    return CircleAvatar(
      backgroundColor: AppTheme.backgroundColor,
      radius: 16,
      child: Text(
        label, 
        style: const TextStyle(fontSize: 10, color: AppTheme.secondaryTextColor),
      ),
    );
  }
}
